import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../models/trainer_model.dart';
import '../../services/api_service.dart';

/// Admin test console for the AI Trainer.
///
/// You play the learner; the trainer is looking at a *simulated* computer you
/// control from the sandbox (files, board, wiring, upload). The side panels show
/// what the trainer can only claim in words: which milestones are proven by
/// evidence, what it actually looked at, and how far up the hint ladder it went.
class TrainerAdminScreen extends StatefulWidget {
  /// Start a session as soon as the practice machines load (for demos and screenshots).
  final bool autoStart;
  final String initialScenario;
  const TrainerAdminScreen({super.key, this.autoStart = false, this.initialScenario = 'fresh_start'});

  @override
  State<TrainerAdminScreen> createState() => _TrainerAdminScreenState();
}

class _Bubble {
  final String role; // trainer | learner | system
  final String text;
  const _Bubble(this.role, this.text);
}

// Test shortcuts so a run does not start with typing a project by hand.
const _exampleIni = '''[env:esp32dev]
platform = espressif32
board = esp32dev
framework = arduino
monitor_speed = 115200
lib_deps = knolleary/PubSubClient
''';
const _exampleMain = '''#include <Arduino.h>
#define TEMP_PIN 34
void setup() { Serial.begin(115200); }
void loop() {
  int mv = analogReadMilliVolts(TEMP_PIN);
  float t = (mv - 500) / 10.0;
  Serial.print("Temperature: "); Serial.print(t); Serial.println(" C");
  delay(1000);
}
''';

class _TrainerAdminScreenState extends State<TrainerAdminScreen> {
  static const _mission = 'esp32_temp_to_cloud';
  List<TrainerScenario> _scenarios = [];
  late String _scenario = widget.initialScenario;
  String? _sessionId;
  TrainerState? _state;
  final List<_Bubble> _chat = [];
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _editor = TextEditingController();
  String _openFile = 'src/main.cpp';
  String _terminal = '';
  bool _loadingScenarios = true;
  bool _busy = false; // a model turn is running
  bool _acting = false; // a sandbox action is running
  int _tab = 0; // narrow layout: 0 chat, 1 evidence
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadScenarios();
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    _editor.dispose();
    super.dispose();
  }

  Future<void> _loadScenarios() async {
    try {
      final j = await ApiService.getTrainerMissions();
      final m = (j['missions'] as List).firstWhere((x) => x['id'] == _mission, orElse: () => (j['missions'] as List).first);
      if (!mounted) return;
      setState(() {
        _scenarios = [for (final s in m['scenarios'] as List) TrainerScenario.fromJson(Map<String, dynamic>.from(s))];
        _loadingScenarios = false;
      });
      if (widget.autoStart) _start();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingScenarios = false;
        _loadError = e.toString();
      });
    }
  }

  TrainerScenario? get _picked {
    for (final s in _scenarios) {
      if (s.name == _scenario) return s;
    }
    return null;
  }

  void _toast(String msg, {bool error = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: error ? AppColors.error : AppColors.success));
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent + 200,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  void _apply(TrainerTurn turn) {
    _state = turn.state;
    for (final m in turn.messages) {
      _chat.add(_Bubble('trainer', m));
    }
    for (final u in turn.ui) {
      _chat.add(_Bubble('system', 'The trainer opened an interactive: ${u['type']}'));
    }
    if (turn.finished) _chat.add(const _Bubble('system', 'Mission complete: every milestone is proven.'));
    _scrollDown();
  }

  Future<void> _start() async {
    if (_busy) return;
    final old = _sessionId;
    setState(() {
      _busy = true;
      _chat.clear();
      _state = null;
      _terminal = '';
    });
    if (old != null) {
      ApiService.endTrainerSession(old).catchError((_) => <String, dynamic>{});
    }
    try {
      final turn = TrainerTurn.fromJson(await ApiService.startTrainerSession(_mission, _scenario));
      if (!mounted) return;
      setState(() {
        _sessionId = turn.sessionId;
        _apply(turn);
        _busy = false;
        _syncEditor();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _sessionId = null;
      });
      _toast(e.toString());
    }
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _input.text).trim();
    final id = _sessionId;
    if (text.isEmpty || id == null || _busy) return;
    setState(() {
      _chat.add(_Bubble('learner', text));
      _input.clear();
      _busy = true;
    });
    _scrollDown();
    try {
      final turn = TrainerTurn.fromJson(await ApiService.sendTrainerMessage(id, text));
      if (!mounted) return;
      setState(() {
        _apply(turn);
        _busy = false;
        _syncEditor();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _chat.add(_Bubble('system', 'Error: $e'));
      });
    }
  }

  Future<void> _act(Map<String, dynamic> body) async {
    final id = _sessionId;
    if (id == null || _acting) return;
    setState(() => _acting = true);
    try {
      final j = await ApiService.trainerSimAction(id, body);
      if (!mounted) return;
      setState(() {
        _state = TrainerState.fromJson(Map<String, dynamic>.from(j['state']));
        if ((j['output'] as String?)?.isNotEmpty == true) _terminal = j['output'];
        _acting = false;
        if (body['action'] == 'write_file') _toast('Saved ${body['path']}', error: false);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _acting = false);
      _toast(e.toString());
    }
  }

  void _syncEditor() {
    final files = _state?.sim.files ?? {};
    if (!files.containsKey(_openFile) && files.isNotEmpty) _openFile = files.keys.first;
    _editor.text = files[_openFile] ?? '';
  }

  // ── chat ──────────────────────────────────────────────────────────────────

  Widget _bubble(_Bubble b) {
    final trainer = b.role == 'trainer';
    final system = b.role == 'system';
    final color = system ? Colors.grey.shade200 : (trainer ? Colors.white : AppColors.primary);
    final fg = system ? AppColors.textSecondary : (trainer ? AppColors.textPrimary : Colors.white);
    return Align(
      alignment: trainer || system ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
          border: trainer ? Border.all(color: Colors.black.withValues(alpha: 0.08)) : null,
        ),
        child: SelectableText(b.text,
            style: GoogleFonts.inter(fontSize: 13.5, height: 1.45, color: fg, fontStyle: system ? FontStyle.italic : null)),
      ),
    );
  }

  Widget _chatPanel() {
    final suggestion = _picked?.opening ?? '';
    return Column(children: [
      Expanded(
        child: _sessionId == null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Choose a practice machine above and press Start.\nThen talk to the trainer as if you were the learner.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(color: AppColors.textSecondary, height: 1.5)),
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
                      Text('The trainer is looking…', style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textSecondary)),
                    ]),
                  ),
              ]),
      ),
      if (_sessionId != null && suggestion.isNotEmpty && _chat.where((b) => b.role == 'learner').isEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
          child: Align(
            alignment: Alignment.centerLeft,
            child: ActionChip(
              avatar: const Icon(Icons.bolt_rounded, size: 16),
              label: Text('Say: "$suggestion"', style: GoogleFonts.inter(fontSize: 12)),
              onPressed: _busy ? null : () => _send(suggestion),
            ),
          ),
        ),
      Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _input,
              enabled: _sessionId != null,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(
                hintText: _sessionId == null ? 'Start a session first' : 'Reply as the learner…',
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: _busy || _sessionId == null ? null : () => _send(),
            icon: const Icon(Icons.send_rounded, size: 20),
          ),
        ]),
      ),
    ]);
  }

  // ── evidence side ────────────────────────────────────────────────────────

  Widget _card(String title, Widget child, {String? trailing}) => Card(
        elevation: 0,
        color: AppColors.cardBg,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.black.withValues(alpha: 0.06))),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
              const Spacer(),
              if (trailing != null) Text(trailing, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
            ]),
            const SizedBox(height: 10),
            child,
          ]),
        ),
      );

  Widget _progressCard(TrainerState st) {
    final rows = <Widget>[];
    for (final stage in st.stages) {
      rows.add(Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 4),
        child: Text(stage['title']!.toUpperCase(),
            style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.6)),
      ));
      for (final m in st.progress.where((m) => m.stage == stage['id'])) {
        final icon = m.done
            ? const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 19)
            : m.status == 'blocked'
                ? Icon(Icons.lock_outline_rounded, color: Colors.grey.shade400, size: 19)
                : Icon(Icons.radio_button_unchecked_rounded, color: Colors.grey.shade500, size: 19);
        final sub = m.done
            ? '${m.kind == 'learner_confirmed' ? 'learner confirmed' : 'verified'}${m.evidence.isEmpty ? '' : ': ${m.evidence}'}'
            : m.status == 'blocked'
                ? 'needs: ${m.waitingFor.join(', ')}'
                : (m.physical ? 'physical: the trainer must ask you' : 'not yet verified');
        rows.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            icon,
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(m.title, style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600)),
                Text(sub,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
              ]),
            ),
            if (m.failedChecks > 0)
              Tooltip(
                message: 'checked ${m.failedChecks}x without success',
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                  child: Text('${m.failedChecks}×', style: GoogleFonts.inter(fontSize: 10.5, color: AppColors.warning, fontWeight: FontWeight.w700)),
                ),
              ),
          ]),
        ));
      }
    }
    final hints = st.hints.isEmpty ? 'none yet' : st.hints.entries.map((e) => '${e.key}: level ${e.value}').join('   ');
    rows.add(const Divider(height: 20));
    rows.add(Text('Learner level: ${st.level}\nHints given: $hints',
        style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.textSecondary, height: 1.5)));
    return _card('Progress (decided by evidence)', Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows),
        trailing: '${st.doneCount}/${st.progress.length}');
  }

  Widget _activityCard(TrainerState st) {
    final items = st.activity.reversed.toList();
    Color colorOf(TrainerActivity a) => a.kind == 'withheld'
        ? AppColors.error
        : a.kind == 'milestone_done'
            ? AppColors.success
            : (!a.ok || a.kind == 'verification_failed')
                ? AppColors.warning
                : AppColors.textPrimary;
    return _card(
      'What the trainer did',
      items.isEmpty
          ? Text('Nothing yet.', style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textSecondary))
          : ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: ListView(shrinkWrap: true, children: [
                for (final a in items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.5),
                    child: Text('${a.t.toStringAsFixed(0).padLeft(3)}s  ${a.label}${a.detail.isEmpty ? '' : '\n        ${a.detail}'}',
                        style: GoogleFonts.robotoMono(fontSize: 11, color: colorOf(a), height: 1.35)),
                  ),
              ]),
            ),
      trailing: 'newest first',
    );
  }

  Widget _sandboxCard(TrainerState st) {
    final sim = st.sim;
    final files = sim.files.keys.toList()..sort();
    final canEdit = _sessionId != null;
    return _card(
      'Learner sandbox (you are the learner)',
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Physical set-up', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text('Board plugged in', style: GoogleFonts.inter(fontSize: 12.5)),
          value: sim.boardConnected,
          onChanged: _acting ? null : (v) => _act({'action': 'configure', 'board_connected': v}),
        ),
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text('USB driver installed', style: GoogleFonts.inter(fontSize: 12.5)),
          value: sim.driverOk,
          onChanged: _acting ? null : (v) => _act({'action': 'configure', 'driver_ok': v}),
        ),
        Row(children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: sim.wiring,
              isDense: true,
              decoration: InputDecoration(labelText: 'Sensor wiring', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
              items: const [
                DropdownMenuItem(value: 'ok', child: Text('Correct')),
                DropdownMenuItem(value: 'floating', child: Text('Output not connected (floating)')),
                DropdownMenuItem(value: 'to_gnd', child: Text('Output shorted to GND')),
                DropdownMenuItem(value: 'to_vcc', child: Text('Output on 3.3 V')),
              ],
              onChanged: _acting ? null : (v) => _act({'action': 'configure', 'wiring': v}),
            ),
          ),
          const SizedBox(width: 10),
          sim.touching
              ? OutlinedButton.icon(
                  onPressed: _acting ? null : () => _act({'action': 'release'}),
                  icon: const Icon(Icons.back_hand_outlined, size: 18),
                  label: const Text('Let go'))
              : ElevatedButton.icon(
                  onPressed: _acting ? null : () => _act({'action': 'touch'}),
                  icon: const Icon(Icons.back_hand_rounded, size: 18),
                  label: const Text('Hold sensor')),
        ]),
        const Divider(height: 24),
        Row(children: [
          Text('Files', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
          const Spacer(),
          TextButton(
            onPressed: !canEdit || _acting
                ? null
                : () async {
                    await _act({'action': 'write_file', 'path': 'platformio.ini', 'text': _exampleIni});
                    await _act({'action': 'write_file', 'path': 'src/main.cpp', 'text': _exampleMain});
                    if (mounted) setState(_syncEditor);
                  },
            child: const Text('Paste a working example (test shortcut)'),
          ),
        ]),
        if (files.isEmpty)
          Text('No files yet. Create platformio.ini and src/main.cpp, or use the shortcut above.',
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary))
        else
          Wrap(spacing: 6, children: [
            for (final f in files)
              ChoiceChip(
                label: Text(f, style: GoogleFonts.robotoMono(fontSize: 11)),
                selected: f == _openFile,
                onSelected: (_) => setState(() {
                  _openFile = f;
                  _editor.text = sim.files[f] ?? '';
                }),
              ),
          ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: TextFormField(
              key: ValueKey('path-$_openFile'),
              initialValue: _openFile,
              onChanged: (v) => _openFile = v.trim(),
              decoration: InputDecoration(
                  labelText: 'File path', isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
              style: GoogleFonts.robotoMono(fontSize: 12),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: !canEdit || _acting || _openFile.isEmpty
                ? null
                : () => _act({'action': 'write_file', 'path': _openFile, 'text': _editor.text}),
            child: const Text('Save file'),
          ),
        ]),
        const SizedBox(height: 8),
        TextField(
          controller: _editor,
          enabled: canEdit,
          minLines: 8,
          maxLines: 16,
          style: GoogleFonts.robotoMono(fontSize: 12, height: 1.4),
          decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), isDense: true),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          OutlinedButton.icon(
              onPressed: !canEdit || _acting ? null : () => _act({'action': 'build'}),
              icon: const Icon(Icons.build_rounded, size: 17),
              label: const Text('Build')),
          ElevatedButton.icon(
              onPressed: !canEdit || _acting ? null : () => _act({'action': 'upload'}),
              icon: const Icon(Icons.upload_rounded, size: 17),
              label: const Text('Upload to board')),
          OutlinedButton.icon(
              onPressed: !canEdit || _acting ? null : () => _act({'action': 'wait', 'seconds': 5}),
              icon: const Icon(Icons.timer_outlined, size: 17),
              label: const Text('Wait 5 s')),
        ]),
        if (_terminal.isNotEmpty) ...[
          const SizedBox(height: 10),
          _mono('Terminal', _terminal),
        ],
        const SizedBox(height: 10),
        _mono('Serial monitor', sim.serial.isEmpty ? '(nothing yet)' : sim.serial.reversed.take(14).toList().reversed.join('\n')),
      ]),
    );
  }

  Widget _mono(String title, String text) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(8)),
          child: SelectableText(text, style: GoogleFonts.robotoMono(fontSize: 11, color: const Color(0xFFD4D4D4), height: 1.4)),
        ),
      ]);

  Widget _sidePanel() {
    final st = _state;
    if (st == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Progress, evidence and the learner sandbox appear once a session starts.',
              textAlign: TextAlign.center, style: GoogleFonts.inter(color: AppColors.textSecondary)),
        ),
      );
    }
    return ListView(padding: const EdgeInsets.all(12), children: [_progressCard(st), _activityCard(st), _sandboxCard(st)]);
  }

  // ── header ────────────────────────────────────────────────────────────────

  Widget _header() {
    final picked = _picked;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('AI Trainer — test console',
            style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        const SizedBox(height: 4),
        Text('You play the learner. The trainer looks at a simulated computer, so nothing here touches real hardware.',
            style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textSecondary)),
        const SizedBox(height: 12),
        if (_loadingScenarios)
          const LinearProgressIndicator()
        else if (_loadError != null)
          Text(_loadError!, style: GoogleFonts.inter(color: AppColors.error))
        else
          Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            SizedBox(
              width: 340,
              child: DropdownButtonFormField<String>(
                initialValue: _scenarios.any((s) => s.name == _scenario) ? _scenario : null,
                isExpanded: true,
                decoration: InputDecoration(
                    labelText: 'Practice machine', isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                items: [for (final s in _scenarios) DropdownMenuItem(value: s.name, child: Text(s.label, overflow: TextOverflow.ellipsis))],
                onChanged: _busy ? null : (v) => setState(() => _scenario = v ?? _scenario),
              ),
            ),
            ElevatedButton.icon(
              onPressed: _busy ? null : _start,
              icon: Icon(_sessionId == null ? Icons.play_arrow_rounded : Icons.restart_alt_rounded, size: 20),
              label: Text(_sessionId == null ? 'Start session' : 'Restart'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white),
            ),
            if (picked != null && picked.description.isNotEmpty)
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Text(picked.description, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
              ),
          ]),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= 1000;
      final chat = Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF1F3F7),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        ),
        child: _chatPanel(),
      );
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _header(),
        if (!wide)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('Chat'), icon: Icon(Icons.chat_bubble_outline_rounded, size: 18)),
                ButtonSegment(value: 1, label: Text('Evidence & sandbox'), icon: Icon(Icons.fact_check_outlined, size: 18)),
              ],
              selected: {_tab},
              onSelectionChanged: (v) => setState(() => _tab = v.first),
            ),
          ),
        Expanded(
          child: wide
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Expanded(flex: 5, child: chat),
                    const SizedBox(width: 14),
                    Expanded(flex: 5, child: _sidePanel()),
                  ]),
                )
              : Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: _tab == 0 ? chat : _sidePanel(),
                ),
        ),
      ]);
    });
  }
}
