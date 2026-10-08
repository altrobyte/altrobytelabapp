import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_colors.dart';
import '../models/trainer_model.dart';
import '../providers/auth_provider.dart';
import 'dart:io' show Directory, Platform;
import 'chat_text.dart';
import 'connectors.dart';
import 'desktop_main.dart' show desktopNavKey;
import 'live_client.dart';
import 'mqtt_probe.dart';

/// The trainer on the learner's own computer: chat on the left, and on the right
/// everything the learner controls or should be able to see — what the trainer
/// may look at, the project folder, the serial monitor, and a plain log of what
/// the trainer actually asked of this machine.
class DesktopTrainerScreen extends StatefulWidget {
  const DesktopTrainerScreen({super.key});

  @override
  State<DesktopTrainerScreen> createState() => _DesktopTrainerScreenState();
}

class _Bubble {
  final String role; // trainer | learner | system
  final String text;
  final String? interactive; // a card the learner can use right in the chat
  const _Bubble(this.role, this.text, {this.interactive});
}

const _connectorInfo = {
  connectorSystem: ('Installed tools and USB', 'Whether VS Code / PlatformIO are installed, and which USB board is plugged in.'),
  connectorWorkspace: ('Your project files', 'Read-only access to the project folder you choose below. Nothing outside it.'),
  connectorToolchain: ('Build and upload', 'Compile your project and flash your board. It asks you every single time.'),
  connectorSerial: ('Serial monitor', 'What your board prints. This app owns the port while it is on.'),
  connectorMqtt: ('MQTT check', 'Listens on your topic to confirm your data arrives. Needs the broker set up below.'),
};

class _DesktopTrainerScreenState extends State<DesktopTrainerScreen> {
  late final LocalMachine _machine;
  late final LiveTrainerClient _client;
  final List<_Bubble> _chat = [];
  final _input = TextEditingController();
  final _scroll = ScrollController();
  TrainerState? _state;
  String _activity = '';
  String _monitorStatus = '';
  bool _busy = false;
  bool _started = false;
  bool _ready = false;
  final List<StreamSubscription<void>> _subs = [];

  final _mqttHost = TextEditingController();
  final _mqttPort = TextEditingController(text: '8883');
  final _mqttUser = TextEditingController();
  final _mqttPass = TextEditingController();
  bool _mqttTls = true;

  @override
  void initState() {
    super.initState();
    _machine = LocalMachine(
      runner: RealProcessRunner(),
      monitor: SerialMonitor(() => PioSerialSource(pioPythonCandidates().first)),
      mqttProbe: realMqttProbe,
      approve: _askLearner,
    );
    _client = LiveTrainerClient(RealTrainerApi(), _machine)
      ..onActivity = ((s) => mounted ? setState(() => _activity = s) : null)
      ..onState = ((s) => mounted ? setState(() => _state = s) : null);
    _subs.add(_machine.logChanges.stream.listen((_) => mounted ? setState(() {}) : null));
    _subs.add(_machine.monitor.changes.listen((_) => mounted ? setState(() {}) : null));
    _loadSettings();
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _machine.monitor.stop();
    _client.end();
    for (final c in [_input, _scroll, _mqttHost, _mqttPort, _mqttUser, _mqttPass]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── settings, remembered between runs ──────────────────────────────────────

  Future<void> _loadSettings() async {
    final p = await SharedPreferences.getInstance();
    _machine.projectDir = p.getString('desk_project') ?? _makeStarterFolder();
    if (p.getString('desk_project') == null && _machine.projectDir != null) await p.setString('desk_project', _machine.projectDir!);
    final saved = p.getStringList('desk_grants');
    _machine.grants
      ..clear()
      ..addAll(saved ?? [connectorSystem, connectorWorkspace, connectorToolchain, connectorSerial]);
    _mqttHost.text = p.getString('desk_mqtt_host') ?? '';
    _mqttPort.text = p.getString('desk_mqtt_port') ?? '8883';
    _mqttUser.text = p.getString('desk_mqtt_user') ?? '';
    _mqttPass.text = p.getString('desk_mqtt_pass') ?? '';
    _mqttTls = p.getBool('desk_mqtt_tls') ?? true;
    _applyMqtt();
    if (mounted) setState(() => _ready = true);
  }

  /// A ready folder under Documents, so a learner never has to find or pick one to begin.
  String? _makeStarterFolder() {
    try {
      final home = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'];
      if (home == null) return null;
      final dir = Directory('$home${Platform.pathSeparator}Documents${Platform.pathSeparator}Altrobyte${Platform.pathSeparator}esp32-temperature');
      dir.createSync(recursive: true);
      return dir.path;
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveSettings() async {
    final p = await SharedPreferences.getInstance();
    if (_machine.projectDir != null) await p.setString('desk_project', _machine.projectDir!);
    await p.setStringList('desk_grants', _machine.grants.toList());
    await p.setString('desk_mqtt_host', _mqttHost.text.trim());
    await p.setString('desk_mqtt_port', _mqttPort.text.trim());
    await p.setString('desk_mqtt_user', _mqttUser.text.trim());
    await p.setString('desk_mqtt_pass', _mqttPass.text);
    await p.setBool('desk_mqtt_tls', _mqttTls);
  }

  void _applyMqtt() {
    _machine.mqtt
      ..host = _mqttHost.text.trim()
      ..port = int.tryParse(_mqttPort.text.trim()) ?? 8883
      ..tls = _mqttTls
      ..username = _mqttUser.text.trim()
      ..password = _mqttPass.text;
  }

  // ── the learner stays in control ───────────────────────────────────────────

  Future<bool> _askLearner(String title, String detail) async {
    final ctx = desktopNavKey.currentContext;
    if (ctx == null) return false;
    final ok = await showDialog<bool>(
      context: ctx,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        title: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: SelectableText(detail, style: GoogleFonts.robotoMono(fontSize: 12.5, height: 1.5)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Not now')),
          ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text('Allow')),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _toggle(String connector, bool on) async {
    setState(() => on ? _machine.grants.add(connector) : _machine.grants.remove(connector));
    if (connector == connectorSerial && !on) await _machine.monitor.stop();
    await _saveSettings();
    try {
      await _client.setGrants();
    } catch (_) {}
  }

  Future<void> _pickFolder() async {
    final dir = await FilePicker.getDirectoryPath(dialogTitle: 'Choose your PlatformIO project folder');
    if (dir == null) return;
    setState(() => _machine.projectDir = dir);
    await _saveSettings();
  }

  // ── conversation ───────────────────────────────────────────────────────────

  void _scrollDown() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(_scroll.position.maxScrollExtent + 200, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
        }
      });

  void _apply(TrainerTurn t) {
    _state = t.state;
    for (final m in t.messages) {
      _chat.add(_Bubble('trainer', m));
    }
    for (final u in t.ui) {
      if (u['type'] == 'pin_map') _chat.add(const _Bubble('ui', '', interactive: 'pin_map'));
    }
    if (t.finished) _chat.add(const _Bubble('system', 'Mission complete: every milestone is proven.'));
    _scrollDown();
  }

  Future<void> _start() async {
    if (_busy) return;
    _applyMqtt();
    await _saveSettings();
    setState(() {
      _busy = true;
      _started = true;
      _chat.clear();
    });
    try {
      final t = await _client.start();
      if (!mounted) return;
      setState(() {
        _apply(t);
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _started = false;
        _chat.add(_Bubble('system', 'Could not start: $e'));
      });
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _busy || !_started) return;
    _applyMqtt();
    setState(() {
      _chat.add(_Bubble('learner', text));
      _input.clear();
      _busy = true;
    });
    _scrollDown();
    try {
      final t = await _client.say(text);
      if (!mounted) return;
      setState(() {
        _apply(t);
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _chat.add(_Bubble('system', 'Error: $e'));
      });
    }
  }

  // ── widgets ────────────────────────────────────────────────────────────────

  Widget _card(String title, Widget child, {Widget? trailing}) => Card(
        elevation: 0,
        color: AppColors.cardBg,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.black.withValues(alpha: 0.06))),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14))),
              if (trailing != null) trailing,
            ]),
            const SizedBox(height: 10),
            child,
          ]),
        ),
      );

  Widget _bubble(_Bubble b) {
    if (b.interactive == 'pin_map') {
      return Align(alignment: Alignment.centerLeft, child: _PinMapCard(enabled: !_busy, onSend: (t) { _input.text = t; _send(); }));
    }
    final trainer = b.role == 'trainer', system = b.role == 'system';
    return Align(
      alignment: trainer || system ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 560),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: system ? Colors.grey.shade200 : (trainer ? Colors.white : AppColors.primary),
          borderRadius: BorderRadius.circular(14),
          border: trainer ? Border.all(color: Colors.black.withValues(alpha: 0.08)) : null,
        ),
        child: system
            ? SelectableText(b.text,
                style: GoogleFonts.inter(fontSize: 13.5, height: 1.45, fontStyle: FontStyle.italic, color: AppColors.textSecondary))
            : ChatText(b.text, color: trainer ? AppColors.textPrimary : Colors.white),
      ),
    );
  }

  Widget _chatPanel() {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFFF1F3F7), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.black.withValues(alpha: 0.06))),
      child: Column(children: [
        Expanded(
          child: !_started
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.smart_toy_rounded, size: 46, color: AppColors.primary),
                      const SizedBox(height: 12),
                      Text('Your hands-on lab instructor', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Text(
                          'Choose on the right what the trainer may look at, and pick your project folder. It teaches; you do the work.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(color: AppColors.textSecondary, height: 1.5)),
                      const SizedBox(height: 18),
                      ElevatedButton.icon(
                        onPressed: _ready && !_busy ? _start : null,
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('Start the session'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14)),
                      ),
                    ]),
                  ),
                )
              : ListView(controller: _scroll, padding: const EdgeInsets.all(14), children: [
                  for (final b in _chat) _bubble(b),
                  if (_busy)
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(children: [
                        const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(_activity.isEmpty ? 'The trainer is thinking…' : 'The trainer is $_activity…',
                              style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textSecondary)),
                        ),
                      ]),
                    ),
                ]),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _input,
                enabled: _started,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(hintText: _started ? 'Reply to the trainer…' : 'Start the session first', isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(onPressed: _busy || !_started ? null : _send, icon: const Icon(Icons.send_rounded, size: 20)),
          ]),
        ),
      ]),
    );
  }

  Widget _connectorsCard() => _card(
        'What the trainer may look at',
        Column(children: [
          for (final c in allConnectors)
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(_connectorInfo[c]!.$1, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
              subtitle: Text(_connectorInfo[c]!.$2, style: GoogleFonts.inter(fontSize: 11.5)),
              value: _machine.grants.contains(c),
              onChanged: (v) => _toggle(c, v),
            ),
        ]),
      );

  Widget _folderCard() => _card(
        'Your project folder',
        Row(children: [
          Expanded(
            child: Text(_machine.projectDir ?? 'Not chosen yet',
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.robotoMono(fontSize: 12, color: _machine.projectDir == null ? AppColors.warning : AppColors.textPrimary)),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(onPressed: _pickFolder, icon: const Icon(Icons.folder_open_rounded, size: 18), label: const Text('Choose')),
        ]),
      );

  Widget _progressCard() {
    final st = _state;
    if (st == null || st.progress.isEmpty) return const SizedBox.shrink();
    return _card(
      'Your progress',
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final m in st.progress)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.5),
            child: Row(children: [
              Icon(m.done ? Icons.check_circle_rounded : (m.status == 'blocked' ? Icons.lock_outline_rounded : Icons.radio_button_unchecked_rounded),
                  size: 18, color: m.done ? AppColors.success : Colors.grey.shade500),
              const SizedBox(width: 8),
              Expanded(child: Text(m.title, style: GoogleFonts.inter(fontSize: 12.5, fontWeight: m.done ? FontWeight.w600 : FontWeight.w400))),
            ]),
          ),
      ]),
      trailing: Text('${st.doneCount}/${st.progress.length}', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
    );
  }

  Widget _monitorCard() {
    final lines = _machine.monitor.tail(14);
    final running = _machine.monitor.running;
    return _card(
      'Serial monitor',
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          if (running)
            OutlinedButton.icon(onPressed: () async { await _machine.monitor.stop(); }, icon: const Icon(Icons.stop_rounded, size: 18), label: const Text('Stop'))
          else
            ElevatedButton.icon(
              onPressed: !_machine.grants.contains(connectorSerial) ? null : () async {
                final s = await _machine.startMonitor();
                if (mounted) setState(() => _monitorStatus = s);
              },
              icon: const Icon(Icons.play_arrow_rounded, size: 18),
              label: const Text('Start'),
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(running ? 'Monitoring ${_machine.monitor.port} at ${_machine.monitor.baud} baud' : _monitorStatus,
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
          ),
        ]),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 70),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(8)),
          child: SelectableText(lines.isEmpty ? '(nothing yet)' : lines.join('\n'),
              style: GoogleFonts.robotoMono(fontSize: 11, color: const Color(0xFFD4D4D4), height: 1.4)),
        ),
      ]),
    );
  }

  Widget _logCard() => _card(
        'What the trainer did on your computer',
        _machine.log.isEmpty
            ? Text('Nothing yet. Every request is listed here, including the ones refused or declined.',
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary))
            : ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: ListView(shrinkWrap: true, children: [
                  for (final l in _machine.log.reversed)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(l,
                          style: GoogleFonts.robotoMono(fontSize: 11, height: 1.35,
                              color: l.contains('REFUSED') || l.contains('DECLINED') ? AppColors.warning : AppColors.textPrimary)),
                    ),
                ]),
              ),
      );

  Widget _advancedCard() => Card(
        elevation: 0,
        color: AppColors.cardBg,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.black.withValues(alpha: 0.06))),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            title: Text('Advanced: cloud check settings', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
            subtitle: Text('Only if your trainer asks you to', style: GoogleFonts.inter(fontSize: 11.5)),
            childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            children: [_mqttCard()],
          ),
        ),
      );

  Widget _mqttCard() => _card(
        'MQTT broker (for the cloud check)',
        Column(children: [
          Row(children: [
            Expanded(flex: 3, child: _field(_mqttHost, 'Host', hint: 'broker.example.com')),
            const SizedBox(width: 8),
            Expanded(child: _field(_mqttPort, 'Port')),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _field(_mqttUser, 'Username')),
            const SizedBox(width: 8),
            Expanded(child: _field(_mqttPass, 'Password', obscure: true)),
          ]),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text('Use TLS', style: GoogleFonts.inter(fontSize: 12.5)),
            value: _mqttTls,
            onChanged: (v) => setState(() => _mqttTls = v),
          ),
          Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () async { _applyMqtt(); await _saveSettings(); }, child: const Text('Save'))),
        ]),
      );

  Widget _field(TextEditingController c, String label, {String? hint, bool obscure = false}) => TextField(
        controller: c,
        obscureText: obscure,
        decoration: InputDecoration(labelText: label, hintText: hint, isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
      );

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Text('Altrobyte AI Trainer', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 17)),
        bottom: _state == null || _state!.progress.isEmpty
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(4),
                child: LinearProgressIndicator(value: _state!.doneCount / _state!.progress.length, minHeight: 4, backgroundColor: Colors.white24, color: AppColors.accent),
              ),
        actions: [
          if (_started)
            TextButton.icon(
              onPressed: _busy ? null : () async {
                await _client.end();
                await _machine.monitor.stop();
                if (mounted) setState(() { _started = false; _chat.clear(); _state = null; });
              },
              icon: const Icon(Icons.restart_alt_rounded, color: Colors.white, size: 18),
              label: const Text('New session', style: TextStyle(color: Colors.white)),
            ),
          Center(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text(auth.instituteName ?? '', style: GoogleFonts.inter(fontSize: 12.5)))),
          TextButton(onPressed: () => context.read<AuthProvider>().logout(), child: const Text('Sign out', style: TextStyle(color: Colors.white))),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(flex: 5, child: _chatPanel()),
          const SizedBox(width: 14),
          Expanded(
            flex: 4,
            child: ListView(children: [_progressCard(), _folderCard(), _monitorCard(), _connectorsCard(), _logCard(), _advancedCard()]),
          ),
        ]),
      ),
    );
  }
}


/// The pin_map interactive: the learner states which pin each wire goes to, in a form instead of free text.
class _PinMapCard extends StatefulWidget {
  const _PinMapCard({required this.enabled, required this.onSend});
  final bool enabled;
  final void Function(String text) onSend;

  @override
  State<_PinMapCard> createState() => _PinMapCardState();
}

class _PinMapCardState extends State<_PinMapCard> {
  final _vcc = TextEditingController(text: '3V3');
  final _gnd = TextEditingController(text: 'GND');
  final _sig = TextEditingController();
  bool _sent = false;

  @override
  void dispose() {
    _vcc.dispose();
    _gnd.dispose();
    _sig.dispose();
    super.dispose();
  }

  Widget _row(String label, TextEditingController c, String hint) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          SizedBox(width: 70, child: Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600))),
          Expanded(
            child: TextField(
              controller: c,
              enabled: !_sent,
              decoration: InputDecoration(hintText: hint, isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
            ),
          ),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 360),
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.black.withValues(alpha: 0.1))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Which ESP32 pin is each sensor wire on?', style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        _row('VCC', _vcc, '3V3'),
        _row('GND', _gnd, 'GND'),
        _row('Signal', _sig, 'e.g. GPIO34'),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton(
            onPressed: !widget.enabled || _sent
                ? null
                : () {
                    if (_sig.text.trim().isEmpty) return;
                    setState(() => _sent = true);
                    widget.onSend('Wiring: VCC to ${_vcc.text.trim()}, GND to ${_gnd.text.trim()}, signal to ${_sig.text.trim()}');
                  },
            child: Text(_sent ? 'Sent' : 'Send to trainer'),
          ),
        ),
      ]),
    );
  }
}
