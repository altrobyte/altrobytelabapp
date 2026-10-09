import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import 'chat_text.dart';
import 'desktop_main.dart' show desktopNavKey;
import 'app_version.dart';
import 'helper_client.dart' show versionAtLeast;
import 'helper_controller.dart';
import 'local_tools.dart' show openFolderInVsCode;
import 'lesson_screen.dart';
import 'modules_panel.dart';
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
  List<Map<String, dynamic>> _courses = [];
  bool _coursesFailed = false;
  String? _newVersion; // a newer installer exists
  int _shown = 0;

  @override
  void initState() {
    super.initState();
    c.askLearner = _askLearner;
    c.addListener(_onChange);
    _fillMqtt();
    _loadCourses();
    _checkUpdate();
    c.checkSetup();
  }

  @override
  void dispose() {
    c.removeListener(_onChange);
    for (final x in [_input, _scroll, _mqttHost, _mqttPort, _mqttUser, _mqttPass]) {
      x.dispose();
    }
    super.dispose();
  }

  bool _wasStarted = false;

  void _onChange() {
    if (_wasStarted && !c.started) _loadCourses(); // back on the learning path: show the progress just made
    _wasStarted = c.started;
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

  /// Quietly asks whether a newer app is published. Any failure just means no banner.
  Future<void> _checkUpdate() async {
    try {
      final r = await http.get(Uri.parse(latestReleaseUrl)).timeout(const Duration(seconds: 8));
      if (r.statusCode != 200) return;
      final v = '${(jsonDecode(r.body) as Map)['version']}';
      if (!versionAtLeast(appVersion, v)) {
        _newVersion = v;
        if (mounted) setState(() {});
      }
    } catch (_) {}
  }

  /// The ready-made courses, with where this learner is in each. Light: a few lines of text.
  Future<void> _loadCourses() async {
    try {
      _courses = await ApiService.trainerCourses();
      _coursesFailed = false;
    } catch (_) {
      _courses = [];
      _coursesFailed = true;
    }
    if (mounted) setState(() {});
  }

  /// Opens a course's interactive page (or the note of an experiment) inside the app.
  Future<void> _openLesson(String courseId, {int? labId}) async {
    final title = labId != null
        ? 'The note for this experiment'
        : '${_courses.firstWhere((k) => k['id'] == courseId, orElse: () => const {'title': 'Lesson'})['title']}';
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => LessonScreen(title: title, load: () => labId != null ? ApiService.trainerLabNote(labId) : ApiService.trainerLesson(courseId))));
  }

  Future<void> _start({int? labId, String? course}) async {
    if (course != null) {
      c.hasLesson = _courses.any((k) => k['id'] == course && k['lesson'] == true);
    }
    final auth = context.read<AuthProvider>();
    final token = auth.token ?? auth.jwtToken;
    if (token == null) return;
    await c.signIn(token);
    await c.start(labId: labId, course: course);
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
    if (b.interactive == 'lesson') {
      final id = '${b.props?['course'] ?? ''}';
      final labId = (b.props?['lab'] as num?)?.toInt();
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.accent, width: 1.5)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.auto_stories_rounded, color: AppColors.accent),
            const SizedBox(width: 10),
            Flexible(child: Text(labId != null ? 'The note for this experiment: read and play with it first' : 'Interactive lesson: play with it, then tell your trainer what you saw', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13))),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: () => _openLesson(id, labId: labId),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white),
              child: Text(labId != null ? 'Open note' : 'Open lesson'),
            ),
          ]),
        ),
      );
    }
    if (b.interactive == 'replies') {
      // Suggested answers belong to the question just asked: they go away once anything else is said.
      if (!identical(b, c.chat.last) || c.busy) return const SizedBox.shrink();
      final options = [for (final o in (b.props?['options'] as List? ?? const [])) '$o'];
      return Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            for (final o in options)
              ActionChip(
                label: Text(o, style: GoogleFonts.inter(fontSize: 13)),
                backgroundColor: Colors.white,
                side: BorderSide(color: AppColors.primary.withValues(alpha: 0.45)),
                onPressed: () => _send(o),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('or type your own below', style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.textSecondary)),
            ),
          ]),
        ),
      );
    }
    if (b.interactive == 'quiz') {
      return Align(alignment: Alignment.centerLeft, child: _QuizCard(props: b.props ?? const {}, enabled: !c.busy, onAnswer: c.answerQuiz));
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

  Widget _stepBanner() {
    final st = c.state!;
    final left = st.progress.where((m) => !m.done).length;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.08), borderRadius: const BorderRadius.vertical(top: Radius.circular(14))),
      child: Row(children: [
        const Icon(Icons.flag_rounded, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text('Now: ${currentStepTitle(st)}', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
        ),
        Text('$left step${left == 1 ? '' : 's'} left', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
      ]),
    );
  }

  /// What a learner sees before a lesson: the ready-made course first, then the experiments of their modules.
  /// Nothing here is downloaded until it is chosen; each lesson loads by itself when it starts.
  Widget _courseHome() {
    Map<String, dynamic>? next;
    for (final k in _courses) {
      final p = k['progress'] as Map?;
      if (p == null || p['finished'] != true) {
        next = k;
        break;
      }
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_newVersion != null)
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              const Icon(Icons.system_update_alt_rounded, color: AppColors.accent),
              const SizedBox(width: 10),
              Expanded(child: Text('A new version of the app is ready ($_newVersion). Install it over this one: your progress stays.', style: GoogleFonts.inter(fontSize: 12.5))),
              TextButton(onPressed: () => openExternal(downloadPageUrl), child: const Text('Get it')),
            ]),
          ),
        Row(children: [
          const Icon(Icons.school_rounded, size: 30, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(child: Text('Your learning path', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600))),
        ]),
        const SizedBox(height: 6),
        Text('Start at the top. Your trainer talks with you, asks small questions and never does the work for you. Nothing to install by hand: this app helps you with every step.',
            style: GoogleFonts.inter(color: AppColors.textSecondary, height: 1.5, fontSize: 13)),
        const SizedBox(height: 16),
        if (_courses.isEmpty && _coursesFailed)
          Row(children: [
            Expanded(child: Text('Could not load your courses. Check your internet and try again.', style: GoogleFonts.inter(color: AppColors.warning))),
            TextButton(onPressed: () => setState(() {
                  _coursesFailed = false;
                  _loadCourses();
                }), child: const Text('Retry')),
          ])
        else if (_courses.isEmpty)
          Text('Loading your courses…', style: GoogleFonts.inter(color: AppColors.textSecondary))
        else
          for (var i = 0; i < _courses.length; i++) _courseTile(_courses[i], i + 1, identical(_courses[i], next)),
        const SizedBox(height: 20),
        ModulesPanel(
          onStartLab: (id) => _start(labId: id),
          canStart: c.ready && !c.busy,
          // A voice problem must never disturb reading: failures are swallowed.
          speak: (text) => c.client.post('/say', {'text': text}).then((_) {}, onError: (_) {}),
          hush: () => c.client.post('/say/stop').then((_) {}, onError: (_) {}),
        ),
        const SizedBox(height: 14),
        _howItFits(),
      ]),
    );
  }

  /// Who does what, in four lines, for someone who has never seen any of it.
  Widget _howItFits() => Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(bottom: 8),
          title: Text('How the pieces fit together', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
          children: [
            for (final line in const [
              ('🏠', 'This app is your home: courses, notes, computer check, and your trainer.'),
              ('✏️', 'VS Code is where you type your code. The trainer opens it for you at the right line; the </> button opens your project folder.'),
              ('🔌', 'The Altrobyte extension in VS Code is optional: it shows the same trainer next to your code.'),
              ('🔗', 'Both use one helper on this computer, so your progress, permissions and board are the same in both. Nothing leaves your computer without you seeing it in the log.'),
            ])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(line.$1, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(line.$2, style: GoogleFonts.inter(fontSize: 12.5, height: 1.4, color: AppColors.textSecondary))),
                ]),
              ),
          ],
        ),
      );

  Widget _courseTile(Map<String, dynamic> k, int number, bool isNext) {
    final p = k['progress'] as Map?;
    final done = (p?['done'] as num?)?.toInt() ?? 0;
    final total = (p?['total'] as num?)?.toInt() ?? (k['steps'] as num?)?.toInt() ?? 0;
    final finished = p?['finished'] == true;
    final label = finished ? 'Do it again' : (done > 0 ? 'Continue' : (isNext ? 'Start here' : 'Start'));
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isNext ? AppColors.accent : Colors.black.withValues(alpha: 0.08), width: isNext ? 2 : 1),
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 15,
          backgroundColor: finished ? AppColors.success : AppColors.primary,
          child: finished ? const Icon(Icons.check_rounded, size: 18, color: Colors.white) : Text('$number', style: const TextStyle(color: Colors.white, fontSize: 13)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${k['title']}', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13.5)),
            const SizedBox(height: 2),
            Text('${k['blurb']}', style: GoogleFonts.inter(fontSize: 12, height: 1.4, color: AppColors.textSecondary)),
            if (done > 0 && total > 0 && !finished) ...[
              const SizedBox(height: 6),
              LinearProgressIndicator(value: (done / total).clamp(0.0, 1.0), minHeight: 4),
            ],
          ]),
        ),
        const SizedBox(width: 10),
        if (k['lesson'] == true) ...[
          IconButton(tooltip: 'Open the interactive lesson', onPressed: () => _openLesson('${k['id']}'), icon: const Icon(Icons.auto_stories_rounded, color: AppColors.accent)),
        ],
        ElevatedButton(
          onPressed: c.ready && !c.busy ? () => _start(course: '${k['id']}') : null,
          style: isNext ? ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white) : null,
          child: Text(label),
        ),
      ]),
    );
  }

  /// "Is this computer ready?": each tool in plain words, with what is missing, why it matters, and a button or steps.
  Widget _setupCard() {
    final r = c.setupReport;
    final items = [for (final i in (r?['items'] as List? ?? const [])) Map<String, dynamic>.from(i as Map)];
    final ready = r?['ready'] == true;
    return _card(
      'Is my computer ready?',
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (r == null)
          Text('Checking your computer…', style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textSecondary))
        else if ((r['error'] ?? '').toString().isNotEmpty)
          Text('${r['error']}', style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.warning))
        else ...[
          Text(ready ? 'Everything is ready. You can do the experiments.' : 'A few things are missing. The app can do most of them for you.',
              style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: ready ? AppColors.success : AppColors.textPrimary)),
          const SizedBox(height: 6),
          for (final i in items) _setupItem(i),
        ],
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: c.settingUp && c.setupProgress.isNotEmpty ? null : c.checkSetup,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Check again'),
          ),
        ),
      ]),
    );
  }

  Widget _setupItem(Map<String, dynamic> i) {
    final id = '${i['id']}';
    final state = '${i['state']}';
    final prog = c.setupProgress[id] ?? (i['progress'] as Map?)?.cast<String, dynamic>();
    final how = [for (final h in (i['how'] as List? ?? const [])) '$h'];
    final ok = state == 'ok', working = state == 'working' || c.setupProgress.containsKey(id);
    final icon = ok ? Icons.check_circle_rounded : (working ? Icons.downloading_rounded : Icons.error_outline_rounded);
    final color = ok ? AppColors.success : (working ? AppColors.primary : AppColors.warning);
    final canInstall = i['can_install'] == true && !working;
    final pct = (prog?['percent'] as num?)?.toDouble();
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.fromLTRB(26, 0, 0, 8),
        initiallyExpanded: !ok,
        dense: true,
        leading: Icon(icon, color: color, size: 20),
        title: Text('${i['label']}', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
        subtitle: Text(
          working ? '${prog?['line'] ?? 'Working…'}' : ('${i['detail'] ?? ''}'.isEmpty ? (ok ? 'Ready' : 'Not ready') : '${i['detail']}'),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(fontSize: 11.5, color: color),
        ),
        children: [
          Align(alignment: Alignment.centerLeft, child: Text('${i['why']}', style: GoogleFonts.inter(fontSize: 12, height: 1.4, color: AppColors.textSecondary))),
          if (working) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(value: pct == null ? null : (pct / 100).clamp(0.0, 1.0)),
          ],
          if (!ok && !working)
            for (var n = 0; n < how.length; n++)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Align(alignment: Alignment.centerLeft, child: Text('${n + 1}. ${how[n]}', style: GoogleFonts.inter(fontSize: 12, height: 1.4))),
              ),
          if (canInstall)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: ElevatedButton(
                  onPressed: () async {
                    final err = await c.installSetup(id);
                    if (err != null && mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                  },
                  child: Text(const {'esp32_support': 'Download now', 'editor': 'Install VS Code', 'project': 'Create my project', 'voice': 'Get the natural voice'}[id] ?? 'Do it for me'),
                ),
              ),
            ),
          if (!ok && !working && '${i['url']}'.isNotEmpty)
            Align(alignment: Alignment.centerLeft, child: SelectableText('${i['url']}', style: GoogleFonts.robotoMono(fontSize: 11, color: AppColors.primary))),
        ],
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
        if (c.started && currentStepTitle(c.state) != null) _stepBanner(),
        Expanded(
          child: !c.started
              ? _courseHome()
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
          if (c.projectDir != null) ...[
            const SizedBox(width: 6),
            Tooltip(
              message: 'Open this folder in VS Code to write your code',
              child: IconButton.outlined(
                onPressed: () async {
                  final ok = await openFolderInVsCode(c.projectDir!);
                  if (!ok && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open VS Code. Install it from the "Is my computer ready?" card.')));
                },
                icon: const Icon(Icons.code_rounded, size: 18),
              ),
            ),
          ],
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
                child: ListView(children: [_progressCard(), _setupCard(), _folderCard(), _monitorCard(), _connectorsCard(), _logCard(), _advancedCard()]),
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


/// A multiple-choice question from the trainer. The card only shows the question and the options; whether the choice is
/// right is decided by the lesson itself, never here.
class _QuizCard extends StatefulWidget {
  const _QuizCard({required this.props, required this.enabled, required this.onAnswer});
  final Map<String, dynamic> props;
  final bool enabled;
  final Future<void> Function(String milestone, int choice, String text) onAnswer;

  @override
  State<_QuizCard> createState() => _QuizCardState();
}

class _QuizCardState extends State<_QuizCard> {
  int? _picked;

  @override
  Widget build(BuildContext context) {
    final options = [for (final o in (widget.props['options'] as List? ?? const [])) '$o'];
    return Container(
      constraints: const BoxConstraints(maxWidth: 460),
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.primary.withValues(alpha: 0.35), width: 1.5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.quiz_rounded, size: 18, color: AppColors.primary),
          const SizedBox(width: 6),
          Text('Quick question', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.primary)),
        ]),
        const SizedBox(height: 6),
        Text('${widget.props['question'] ?? ''}', style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.w600, height: 1.4)),
        const SizedBox(height: 8),
        for (var i = 0; i < options.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  backgroundColor: _picked == i ? AppColors.primary.withValues(alpha: 0.1) : null,
                ),
                onPressed: !widget.enabled || _picked != null
                    ? null
                    : () {
                        setState(() => _picked = i);
                        widget.onAnswer('${widget.props['milestone']}', i, options[i]);
                      },
                child: Text(options[i], style: GoogleFonts.inter(fontSize: 13)),
              ),
            ),
          ),
      ]),
    );
  }
}
