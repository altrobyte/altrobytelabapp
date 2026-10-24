// "Your modules": the learner's real training modules (Git, Bluetooth, Intro to Embedded...) with their notes, right in the app.
//
// Light on purpose: only the list of modules is fetched when the page opens. A module's notes are fetched when the learner opens
// that module, and a note's page is written to a temporary file only when it is opened. Nothing is stored in the app.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import '../models/training_module_model.dart';
import '../services/api_service.dart';
import 'class_screen.dart';
import 'local_tools.dart';
import 'module_cache.dart';
import 'note_tutor_screen.dart';
import 'visual_page.dart';

class ModulesPanel extends StatefulWidget {
  /// Starts an AI Lab experiment of a module.
  final void Function(int labId) onStartLab;
  final bool canStart;

  /// The tutor's voice, through the helper on this computer.
  final void Function(String text)? speak;
  final void Function()? hush;
  final void Function(List<String> texts)? prepare;
  const ModulesPanel({super.key, required this.onStartLab, required this.canStart, this.speak, this.hush, this.prepare});

  @override
  State<ModulesPanel> createState() => _ModulesPanelState();
}

/// What to say when the list of modules could not be read.
String modulesProblem(Object e) {
  final t = '$e'.toLowerCase();
  if (t.contains('401') || t.contains('unauthor') || t.contains('sign in')) return 'Please sign in again to see your modules.';
  if (t.contains('socket') || t.contains('connection') || t.contains('timeout') || t.contains('failed host')) {
    return 'Could not reach Altrobyte. Check your internet and try again.';
  }
  return 'Could not load your modules right now. Try again in a moment.';
}

class _ModulesPanelState extends State<ModulesPanel> {
  List<TrainingModule>? _modules;
  String? _problem;
  final Map<int, TrainingModule> _detail = {};
  final Map<int, String> _detailProblem = {};
  final Set<int> _loading = {};
  // Progress, the website's own record: what is done in each module, out of how many items.
  final Map<int, Set<int>> _done = {};
  final Map<int, int> _total = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  ModuleCache? _cache;

  /// The account the cache belongs to: the id inside the sign-in token (the token itself changes at every sign-in).
  static String accountOf(String token) {
    try {
      final part = token.split('.')[1];
      final body = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(part)))) as Map;
      return '${body['sub'] ?? body['student_id'] ?? body['user_id'] ?? body['id'] ?? token}';
    } catch (_) {
      return token;
    }
  }

  List<TrainingModule> _parseList(List raw) => [for (final m in raw) TrainingModule.fromJson(Map<String, dynamic>.from(m as Map))];

  void _applyProgress(Map p, int id) {
    _done[id] = {for (final x in (p['completed_item_ids'] as List? ?? const [])) (x as num).toInt()};
    _total[id] = (p['total_items'] as num?)?.toInt() ?? 0;
  }

  /// What this computer kept from last time shows at once; the fresh copy follows from the internet.
  Future<void> _load() async {
    setState(() => _problem = null);
    _cache ??= ModuleCache(accountOf(await ApiService.learnerToken() ?? ''));
    final c = _cache!;
    if (_modules == null) {
      final kept = c.read('modules');
      if (kept is List) {
        try {
          _modules = _parseList(kept);
          for (final m in _modules!) {
            final p = c.read('progress-${m.id}');
            if (p is Map) _applyProgress(p, m.id);
            final d = c.read('module-${m.id}');
            if (d is Map) _detail[m.id] = TrainingModule.fromJson(Map<String, dynamic>.from(d));
          }
          if (mounted) setState(() {});
        } catch (_) {}
      }
    }
    try {
      final raw = await ApiService.desktopModules();
      _modules = _parseList(raw);
      c.write('modules', raw);
      _loadProgress();
      _prefetch();
    } catch (e) {
      if (_modules == null || _modules!.isEmpty) _problem = modulesProblem(e);   // with a kept copy on screen, stay quiet
      _modules ??= [];
    }
    if (mounted) setState(() {});
  }

  /// Every open module's lessons fetched in the background, one at a time, so opening one never waits.
  Future<void> _prefetch() async {
    for (final m in List<TrainingModule>.of(_modules ?? const [])) {
      if (m.locked || !mounted) continue;
      try {
        final raw = await ApiService.desktopModule(m.id);
        _detail[m.id] = TrainingModule.fromJson(raw);
        _detailProblem.remove(m.id);
        _cache?.write('module-${m.id}', raw);
        if (mounted) setState(() {});
      } catch (_) {}
    }
  }

  Future<void> _loadProgress() async {
    await Future.wait([
      for (final m in _modules ?? const <TrainingModule>[])
        if (!m.locked)
          ApiService.desktopProgress(m.id).then((p) {
            _applyProgress(p, m.id);
            _cache?.write('progress-${m.id}', {'completed_item_ids': _done[m.id]!.toList(), 'total_items': _total[m.id]});
          }).catchError((_) {}),
    ]);
    if (mounted) setState(() {});
  }

  /// Opening an item counts it as done, as on the website; the bar moves at once.
  void _mark(int moduleId, ContentItem it) {
    if (_done.putIfAbsent(moduleId, () => {}).add(it.id)) {
      setState(() {});
      _cache?.write('progress-$moduleId', {'completed_item_ids': _done[moduleId]!.toList(), 'total_items': _total[moduleId] ?? 0});
      ApiService.desktopComplete(it.id).catchError((_) {});
    }
  }

  bool _isDone(int moduleId, ContentItem it) => _done[moduleId]?.contains(it.id) ?? false;

  Future<void> _open(TrainingModule m) async {
    if (_detail.containsKey(m.id) || _loading.contains(m.id)) return;
    setState(() {
      _loading.add(m.id);
      _detailProblem.remove(m.id);
    });
    try {
      final raw = await ApiService.desktopModule(m.id);
      _detail[m.id] = TrainingModule.fromJson(raw);
      _cache?.write('module-${m.id}', raw);
    } catch (e) {
      _detailProblem[m.id] = modulesProblem(e);
    }
    _loading.remove(m.id);
    if (mounted) setState(() {});
  }

  /// A note opens as the live class (the board and Altron's voice) when it has its class version; otherwise the
  /// reading tutor. Only one of them talks.
  Future<void> _note(ContentItem item) async {
    bool live = false;
    try {
      live = await ApiService.hasClassVersion(item.id);
    } catch (_) {}
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => live
            ? ClassScreen(noteId: item.id, title: item.title)
            : NoteTutorScreen(contentId: item.id, title: item.title, speak: widget.speak, hush: widget.hush, prepare: widget.prepare)));
  }

  Future<void> _link(String? url) async {
    final ok = url != null && await openExternal(url);
    if (!ok && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open that link.')));
  }

  IconData _icon(String type) => switch (type) {
        'notes' => Icons.menu_book_rounded,
        'video' => Icons.play_circle_outline_rounded,
        'resource' => Icons.download_rounded,
        'test' => Icons.quiz_outlined,
        _ => Icons.article_outlined,
      };

  Widget _item(int moduleId, ContentItem it) {
    final locked = it.locked;
    final String action = it.type == 'notes' ? 'Read with tutor' : it.type == 'video' ? 'Watch' : it.type == 'resource' ? 'Download' : 'Open on the website';
    VoidCallback? onTap;
    if (!locked) {
      if (it.type == 'notes' && (it.htmlContent ?? '').isNotEmpty) onTap = () => _note(it);
      if (it.type == 'video') onTap = () => _link(it.youtubeUrl);
      if (it.type == 'resource') onTap = () => _link(it.resourceUrl);
    }
    final open = onTap;
    if (open != null) {
      onTap = () {
        _mark(moduleId, it);
        open();
      };
    }
    final done = _isDone(moduleId, it);
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.only(left: 8),
      leading: Icon(locked ? Icons.lock_outline_rounded : (done ? Icons.check_circle_rounded : _icon(it.type)), size: 20,
          color: locked ? Colors.grey : (done ? AppColors.success : AppColors.primary)),
      title: Text(it.title, style: GoogleFonts.inter(fontSize: 13)),
      trailing: onTap == null
          ? Text(locked ? 'Upgrade on the website' : 'Website', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary))
          : TextButton(onPressed: onTap, child: Text(action)),
    );
  }

  /// The code item: shown to read and type, with a copy button. The learner types it into their own project.
  Future<void> _code(ContentItem it) async {
    final code = it.htmlContent ?? '';
    await showDialog<void>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(it.title, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
        content: SizedBox(
          width: 640,
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(10)),
              child: SelectableText(code, style: GoogleFonts.robotoMono(fontSize: 12.5, color: const Color(0xFFE2E8F0), height: 1.5)),
            ),
          ),
        ),
        actions: [
          Text('Type it into your project yourself; copying is for checking.', style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.textSecondary)),
          TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: code));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Code copied')));
              },
              child: const Text('Copy')),
          FilledButton(onPressed: () => Navigator.pop(d), child: const Text('Close')),
        ],
      ),
    );
  }

  /// The GitHub project, one tap: downloaded into Documents\Altrobyte\projects and opened in VS Code.
  Future<void> _openProject(ContentItem it) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(SnackBar(content: Text('Getting "${it.title}" ready in VS Code…'), duration: const Duration(seconds: 20)));
    try {
      final folder = await fetchGithubProject(it.resourceUrl ?? '');
      final ok = await openFolderInVsCode(folder);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(
          content: Text(ok ? 'Opened in VS Code: $folder' : 'Downloaded to $folder, but VS Code did not open. Install it from the "Your computer" card.')));
    } catch (e) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(content: Text(e is String ? e : 'Could not get the project ready. Try again.')));
    }
  }

  /// The GitHub project's other ways: open it on GitHub, or copy the clone command.
  Future<void> _github(ContentItem it) async {
    final url = it.resourceUrl ?? '';
    await showDialog<void>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(it.title, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Open the project to read it, or clone it into your workspace from the terminal in VS Code:', style: GoogleFonts.inter(fontSize: 13)),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(8)),
            child: SelectableText('git clone $url', style: GoogleFonts.robotoMono(fontSize: 12.5, color: const Color(0xFFE2E8F0))),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: 'git clone $url'));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Clone command copied')));
              },
              child: const Text('Copy clone command')),
          FilledButton(
              onPressed: () {
                Navigator.pop(d);
                _link(url);
              },
              child: const Text('Open on GitHub')),
        ],
      ),
    );
  }

  Widget _step(String n, String label, Color color) => Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(99)),
        child: Text('$n  $label', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      );

  Widget _action(IconData icon, String title, String action, VoidCallback? onTap, {bool locked = false, bool primary = false, bool done = false}) => ListTile(
        dense: true,
        contentPadding: const EdgeInsets.only(left: 4),
        leading: Icon(locked ? Icons.lock_outline_rounded : (done ? Icons.check_circle_rounded : icon), size: 20,
            color: locked ? Colors.grey : (done ? AppColors.success : (primary ? AppColors.accent : AppColors.primary))),
        title: Text(title, style: GoogleFonts.inter(fontSize: 13, fontWeight: primary ? FontWeight.w600 : FontWeight.w400)),
        trailing: locked
            ? Text('Self-paced', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary))
            : onTap == null
                ? null
                : primary
                    ? ElevatedButton(onPressed: onTap, child: Text(action))
                    : TextButton(onPressed: onTap, child: Text(action)),
      );

  /// One subtopic as a lesson. Items the lesson does not know (a video, a resource) stay below, as before.
  Widget _lesson(int moduleId, String title, List<ContentItem> items, List<AiLabInfo> labs) {
    final notes = items.where((i) => i.type == 'notes').toList();
    final codes = items.where((i) => i.type == 'code').toList();
    final gits = items.where((i) => i.type == 'github').toList();
    final tests = items.where((i) => i.type == 'test').toList();
    final others = items.where((i) => !const {'notes', 'code', 'github', 'test'}.contains(i.type)).toList();
    final noteIds = notes.map((n) => n.id).toSet();
    final myLabs = labs.where((l) => l.contentId != null && noteIds.contains(l.contentId)).toList();
    final hasBuild = myLabs.isNotEmpty || codes.isNotEmpty || gits.isNotEmpty;
    VoidCallback doing(ContentItem it, VoidCallback go) => () {
          _mark(moduleId, it);
          go();
        };
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(10, 8, 6, 6),
      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.black.withValues(alpha: 0.06))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 4),
        Wrap(children: [
          if (notes.isNotEmpty) _step('1', 'Learn', AppColors.primary),
          if (hasBuild) _step('2', 'Build & prove', AppColors.accent),
          if (tests.isNotEmpty) _step('3', 'Test', const Color(0xFF2E7D32)),
        ]),
        for (final n in notes)
          _action(Icons.record_voice_over_rounded, n.title, 'Learn with Altron',
              (n.htmlContent ?? '').isNotEmpty ? doing(n, () => _note(n)) : null, locked: n.locked, done: _isDone(moduleId, n)),
        for (final l in myLabs)
          _action(Icons.science_rounded, 'Experiment: ${l.title}', 'Start', widget.canStart ? () => widget.onStartLab(l.id) : null, primary: true),
        for (final c in codes) _action(Icons.code_rounded, c.title, 'See code', doing(c, () => _code(c)), locked: c.locked, done: _isDone(moduleId, c)),
        for (final g in gits)
          ListTile(
            dense: true,
            contentPadding: const EdgeInsets.only(left: 4),
            leading: Icon(g.locked ? Icons.lock_outline_rounded : (_isDone(moduleId, g) ? Icons.check_circle_rounded : Icons.hub_rounded), size: 20,
                color: g.locked ? Colors.grey : (_isDone(moduleId, g) ? AppColors.success : AppColors.accent)),
            title: Text(g.title, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
            trailing: g.locked
                ? Text('Self-paced', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary))
                : Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(tooltip: 'More: GitHub, clone command', onPressed: () => _github(g), icon: const Icon(Icons.more_horiz_rounded, size: 18)),
                    ElevatedButton.icon(onPressed: doing(g, () => _openProject(g)), icon: const Icon(Icons.open_in_new_rounded, size: 16), label: const Text('Open in VS Code')),
                  ]),
          ),
        for (final t in tests)
          _action(Icons.quiz_outlined, t.title, 'Take the test', t.testId == null ? null : doing(t, () => _link('https://altrobytelab.com/test/${t.testId}')),
              locked: t.locked, done: _isDone(moduleId, t)),
        for (final o in others) _item(moduleId, o),
      ]),
    );
  }

  Widget _moduleBody(TrainingModule m) {
    if (_loading.contains(m.id)) {
      return const Padding(padding: EdgeInsets.all(14), child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
    }
    final problem = _detailProblem[m.id];
    if (problem != null) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Expanded(child: Text(problem, style: GoogleFonts.inter(color: AppColors.warning, fontSize: 12.5))),
          TextButton(onPressed: () => _open(m), child: const Text('Retry')),
        ]),
      );
    }
    final d = _detail[m.id];
    if (d == null) return const SizedBox.shrink();
    final labs = m.aiLabs.isNotEmpty ? m.aiLabs : d.aiLabs;
    final noteIds = {for (final t in d.topics) for (final st in t.subtopics) for (final it in st.contentItems) if (it.type == 'notes') it.id};
    final loose = labs.where((l) => l.contentId == null || !noteIds.contains(l.contentId)).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (loose.isNotEmpty) ...[
        Padding(padding: const EdgeInsets.fromLTRB(8, 4, 0, 2), child: Text('Hands-on experiments', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12.5))),
        for (final l in loose)
          ListTile(
            dense: true,
            contentPadding: const EdgeInsets.only(left: 8),
            leading: const Icon(Icons.science_rounded, size: 20, color: AppColors.accent),
            title: Text(l.title, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              ElevatedButton(onPressed: widget.canStart ? () => widget.onStartLab(l.id) : null, child: const Text('Start')),
            ]),
          ),
      ],
      for (final t in d.topics) ...[
        Padding(padding: const EdgeInsets.fromLTRB(8, 12, 0, 0), child: Text(t.title, style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13.5))),
        for (final st in t.subtopics)
          if (st.contentItems.isNotEmpty) _lesson(m.id, st.title.isNotEmpty ? st.title : t.title, st.contentItems, labs),
      ],
      if (d.topics.isEmpty) Padding(padding: const EdgeInsets.all(12), child: Text('This module has no lessons yet.', style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textSecondary))),
    ]);
  }

  /// "4 of 12 done" with a bar, under each module's name; the description when there is nothing to show yet.
  Widget? _progressLine(TrainingModule m) {
    final total = _total[m.id] ?? 0;
    final done = (_done[m.id]?.length ?? 0).clamp(0, total);
    if (m.locked || total == 0) {
      return m.description.isEmpty ? null : Text(m.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 11.5));
    }
    final finished = done >= total;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(value: done / total, minHeight: 6, backgroundColor: const Color(0xFFE8EDF3),
                color: finished ? AppColors.success : AppColors.accent),
          ),
        ),
        const SizedBox(width: 10),
        Text(finished ? 'Completed' : '$done of $total done',
            style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: finished ? AppColors.success : AppColors.textSecondary)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final modules = _modules;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text('Your modules', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15))),
        IconButton(tooltip: 'Refresh', onPressed: _load, icon: const Icon(Icons.refresh_rounded, size: 20)),
      ]),
      Text('Learn with Altron, build the project, take the test. Your progress is saved as you go.', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
      const SizedBox(height: 8),
      if (modules == null)
        Text('Loading your modules…', style: GoogleFonts.inter(color: AppColors.textSecondary))
      else if (_problem != null)
        Row(children: [
          Expanded(child: Text(_problem!, style: GoogleFonts.inter(color: AppColors.warning, fontSize: 12.5))),
          TextButton(onPressed: _load, child: const Text('Retry')),
        ])
      else if (modules.isEmpty)
        Text('No modules yet. Enrol in one on altrobytelab.com and it will appear here.', style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12.5))
      else
        for (final m in modules)
          Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 8),
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.black.withValues(alpha: 0.08))),
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                onExpansionChanged: (open) {
                  if (open && !m.locked) _open(m);
                },
                leading: Icon(m.locked ? Icons.lock_outline_rounded : Icons.menu_book_rounded, color: m.locked ? Colors.grey : AppColors.primary),
                title: Text(m.title, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13.5)),
                subtitle: _progressLine(m),
                childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
                children: [
                  if (m.locked)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text('This module is not unlocked for your account yet. Get it on altrobytelab.com and it opens here.', style: GoogleFonts.inter(fontSize: 12.5)),
                    )
                  else
                    _moduleBody(m),
                ],
              ),
            ),
          ),
    ]);
  }
}
