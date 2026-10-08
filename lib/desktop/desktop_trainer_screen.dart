import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import 'chat_text.dart';
import 'desktop_main.dart' show desktopNavKey;
import 'helper_controller.dart';
import 'visual_page.dart';

/// The trainer on the learner's own computer: chat on the left, and on the right everything the learner controls or
/// should be able to see: progress, the project folder, the serial monitor, what the trainer may look at, and a plain log
/// of what it actually asked of this computer. All of it comes from the helper, so the VS Code extension shows the same.
class DesktopTrainerScreen extends StatefulWidget {
  final HelperController controller;
  final VoidCallback onReconnect;
  const DesktopTrainerScreen({super.key, required this.controller, required this.onReconnect});

  @override
  State<DesktopTrainerScreen> createState() => _DesktopTrainerScreenState();
}

const _connectorInfo = {
  'system': ('Installed tools and USB', 'Whether VS Code / PlatformIO are installed, and which USB board is plugged in.'),
  'workspace': ('Your project files', 'Reads files inside your project folder. With your OK each time, it can add a starter file there.'),
  'toolchain': ('Build and upload', 'Compile your project and flash your board. It asks you every single time.'),
  'serial': ('Serial monitor', 'What your board prints. The helper owns the port while this is on.'),
  'mqtt': ('MQTT check', 'Listens on your topic to confirm your data arrives. Needs the broker set up below.'),
};

class _DesktopTrainerScreenState extends State<DesktopTrainerScreen> {
  HelperController get c => widget.controller;
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _mqttHost = TextEditingController();
  final _mqttPort = TextEditingController(text: '8883');
  final _mqttUser = TextEditingController();
  final _mqttPass = TextEditingController();
  bool _mqttTls = true;
  List<Map<String, dynamic>> _labs = [];
  int _shown = 0;

  @override
  void initState() {
    super.initState();
    c.askLearner = _askLearner;
    c.addListener(_onChange);
    _fillMqtt();
    _loadLabs();
  }

  @override
  void dispose() {
    c.removeListener(_onChange);
    for (final x in [_input, _scroll, _mqttHost, _mqttPort, _mqttUser, _mqttPass]) {
      x.dispose();
    }
    super.dispose();
  }

  void _onChange() {
    if (c.chat.length != _shown) {
      _shown = c.chat.length;
      _scrollDown();
    }
  }

  void _fillMqtt() {
    final m = c.mqtt;
    _mqttHost.text = '${m['host'] ?? ''}';
    _mqttPort.text = '${m['port'] ?? 8883}';
    _mqttUser.text = '${m['username'] ?? ''}';
    _mqttTls = m['tls'] != false;
  }

  void _scrollDown() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(_scroll.position.maxScrollExtent + 200, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
        }
      });

  // ── the learner stays in control ───────────────────────────────────────────

  Future<bool> _askLearner(Approval a) async {
    final ctx = desktopNavKey.currentContext;
    if (ctx == null) return false;
    final ok = await showDialog<bool>(
      context: ctx,
      barrierDismissible: false,
      builder: (d) => AlertDialog(
        title: Text(a.title, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: SelectableText(a.detail, style: GoogleFonts.robotoMono(fontSize: 12.5, height: 1.5)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Not now')),
          ElevatedButton(onPressed: () => Navigator.pop(d, true), child: const Text('Allow')),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _pickFolder() async {
    final dir = await FilePicker.getDirectoryPath(dialogTitle: 'Choose your PlatformIO project folder');
    if (dir != null) await c.setProjectDir(dir);
  }

  /// The experiments the learner's teachers switched on (modules with an AI Lab).
  Future<void> _loadLabs() async {
    try {
      final modules = await ApiService.getTrainingModulesForStudent();
      _labs = [for (final m in modules) if (m is Map && m['ai_lab_enabled'] == true) Map<String, dynamic>.from(m)];
    } catch (_) {
      _labs = [];
    }
    if (mounted) setState(() {});
  }

  Future<void> _start({int? moduleId}) async {
    final auth = context.read<AuthProvider>();
    final token = auth.token ?? auth.jwtToken;
    if (token == null) return;
    await c.signIn(token);
    await c.start(moduleId: moduleId);
  }

  Future<void> _send([String? text]) async {
    final t = (text ?? _input.text).trim();
    if (t.isEmpty) return;
    _input.clear();
    await c.send(t);
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

  Widget _bubble(ChatBubble b) {
    if (b.interactive == 'picture') {
      final title = '${b.props?['title'] ?? 'Picture'}';
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.black.withValues(alpha: 0.1))),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.image_rounded, color: AppColors.primary),
            const SizedBox(width: 10),
            Flexible(child: Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w600))),
            const SizedBox(width: 10),
            OutlinedButton(onPressed: () => openPicture(b.props ?? {}), child: const Text('Open picture')),
          ]),
        ),
      );
    }
    if (b.interactive == 'pin_map') {
      return Align(alignment: Alignment.centerLeft, child: _PinMapCard(enabled: !c.busy, onSend: _send));
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
            ? SelectableText(b.text, style: GoogleFonts.inter(fontSize: 13.5, height: 1.45, fontStyle: FontStyle.italic, color: AppColors.textSecondary))
            : ChatText(b.text, color: trainer ? AppColors.textPrimary : Colors.white),
      ),
    );
  }

  Widget _chatPanel() {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFFF1F3F7), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.black.withValues(alpha: 0.06))),
      child: Column(children: [
        if (c.lost)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.18), borderRadius: const BorderRadius.vertical(top: Radius.circular(14))),
            child: Row(children: [
              const Icon(Icons.link_off_rounded, size: 18),
              const SizedBox(width: 8),
              const Expanded(child: Text('Lost contact with the helper (it was restarted or ended).')),
              TextButton(onPressed: widget.onReconnect, child: const Text('Reconnect')),
            ]),
          ),
        Expanded(
          child: !c.started
              ? Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(28),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.smart_toy_rounded, size: 46, color: AppColors.primary),
                      const SizedBox(height: 12),
                      Text('Your hands-on lab instructor', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Text('Choose on the right what the trainer may look at. It teaches; you do the work.',
                          textAlign: TextAlign.center, style: GoogleFonts.inter(color: AppColors.textSecondary, height: 1.5)),
                      if (_labs.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text('Experiments from your modules', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
                        const SizedBox(height: 8),
                        Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
                          for (final m in _labs)
                            ActionChip(
                              avatar: const Icon(Icons.science_rounded, size: 18),
                              label: Text('${m['title']}'),
                              onPressed: c.ready && !c.busy ? () => _start(moduleId: (m['id'] as num).toInt()) : null,
                            ),
                        ]),
                      ],
                      const SizedBox(height: 18),
                      ElevatedButton.icon(
                        onPressed: c.ready && !c.busy ? () => _start() : null,
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('Start the session'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14)),
                      ),
                    ]),
                  ),
                )
              : ListView(controller: _scroll, padding: const EdgeInsets.all(14), children: [
                  for (final b in c.chat) _bubble(b),
                  if (c.busy)
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(children: [
                        const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(c.activity.isEmpty ? 'The trainer is thinking…' : 'The trainer is ${c.activity}…',
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
                enabled: c.started,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(hintText: c.started ? 'Reply to the trainer…' : 'Start the session first', isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(onPressed: c.busy || !c.started ? null : _send, icon: const Icon(Icons.send_rounded, size: 20)),
          ]),
        ),
      ]),
    );
  }

  Widget _connectorsCard() => _card(
        'What the trainer may look at',
        Column(children: [
          for (final id in allConnectors)
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(_connectorInfo[id]!.$1, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
              subtitle: Text(_connectorInfo[id]!.$2, style: GoogleFonts.inter(fontSize: 11.5)),
              value: c.grants.contains(id),
              onChanged: (v) => c.setGrant(id, v),
            ),
        ]),
      );

  Widget _folderCard() => _card(
        'Your project folder',
        Row(children: [
          Expanded(
            child: Text(c.projectDir ?? 'Not chosen yet',
                overflow: TextOverflow.ellipsis, style: GoogleFonts.robotoMono(fontSize: 12, color: c.projectDir == null ? AppColors.warning : AppColors.textPrimary)),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(onPressed: _pickFolder, icon: const Icon(Icons.folder_open_rounded, size: 18), label: const Text('Choose')),
        ]),
      );

  Widget _progressCard() {
    final st = c.state;
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
    return _card(
      'Serial monitor',
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          if (c.monitorRunning)
            OutlinedButton.icon(onPressed: c.stopMonitor, icon: const Icon(Icons.stop_rounded, size: 18), label: const Text('Stop'))
          else
            ElevatedButton.icon(
              onPressed: !c.grants.contains('serial') ? null : c.startMonitor,
              icon: const Icon(Icons.play_arrow_rounded, size: 18),
              label: const Text('Start'),
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(c.monitorRunning ? 'Monitoring ${c.monitorPort} at ${c.monitorBaud} baud' : c.monitorStatus,
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
          ),
        ]),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 70),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(8)),
          child: SelectableText(c.monitorLines.isEmpty ? '(nothing yet)' : c.monitorLines.join('\n'),
              style: GoogleFonts.robotoMono(fontSize: 11, color: const Color(0xFFD4D4D4), height: 1.4)),
        ),
      ]),
    );
  }

  Widget _logCard() => _card(
        'What the trainer did on your computer',
        c.auditLines.isEmpty
            ? Text('Nothing yet. Every request is listed here, including the ones refused or declined.',
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary))
            : ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: ListView(shrinkWrap: true, children: [
                  for (final l in c.auditLines)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(l,
                          style: GoogleFonts.robotoMono(fontSize: 11, height: 1.35, color: l.contains('REFUSED') || l.contains('DECLINED') ? AppColors.warning : AppColors.textPrimary)),
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
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () async {
                await c.saveMqtt(host: _mqttHost.text.trim(), port: int.tryParse(_mqttPort.text.trim()) ?? 8883, tls: _mqttTls, username: _mqttUser.text.trim(), password: _mqttPass.text);
                _mqttPass.clear();
              },
              child: const Text('Save'),
            ),
          ),
        ]),
      );

  Widget _field(TextEditingController x, String label, {String? hint, bool obscure = false}) => TextField(
        controller: x,
        obscureText: obscure,
        decoration: InputDecoration(labelText: label, hintText: hint, isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
      );

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final st = c.state;
        return Scaffold(
          appBar: AppBar(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            title: Text('Altrobyte AI Trainer', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 17)),
            bottom: st == null || st.progress.isEmpty
                ? null
                : PreferredSize(
                    preferredSize: const Size.fromHeight(4),
                    child: LinearProgressIndicator(value: st.doneCount / st.progress.length, minHeight: 4, backgroundColor: Colors.white24, color: AppColors.accent),
                  ),
            actions: [
              if (c.started)
                TextButton.icon(
                  onPressed: c.busy ? null : c.newSession,
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
      },
    );
  }
}

/// The pin_map interactive: the learner states which pin each wire goes to, in a form instead of free text.
class _PinMapCard extends StatefulWidget {
  const _PinMapCard({required this.enabled, required this.onSend});
  final bool enabled;
  final Future<void> Function([String? text]) onSend;

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

  Widget _row(String label, TextEditingController x, String hint) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          SizedBox(width: 70, child: Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600))),
          Expanded(child: TextField(controller: x, enabled: !_sent, decoration: InputDecoration(hintText: hint, isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))))),
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
        Text('Which pin is each sensor wire on?', style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        _row('VCC', _vcc, '3V3 or 5V'),
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
