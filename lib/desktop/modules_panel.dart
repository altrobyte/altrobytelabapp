// "Your modules": the learner's real training modules (Git, Bluetooth, Intro to Embedded...) with their notes, right in the app.
//
// Light on purpose: only the list of modules is fetched when the page opens. A module's notes are fetched when the learner opens
// that module, and a note's page is written to a temporary file only when it is opened. Nothing is stored in the app.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import '../models/training_module_model.dart';
import '../services/api_service.dart';
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _problem = null);
    try {
      final raw = await ApiService.desktopModules();
      _modules = [for (final m in raw) TrainingModule.fromJson(Map<String, dynamic>.from(m as Map))];
    } catch (e) {
      _problem = modulesProblem(e);
      _modules ??= [];
    }
    if (mounted) setState(() {});
  }

  Future<void> _open(TrainingModule m) async {
    if (_detail.containsKey(m.id) || _loading.contains(m.id)) return;
    setState(() {
      _loading.add(m.id);
      _detailProblem.remove(m.id);
    });
    try {
      _detail[m.id] = TrainingModule.fromJson(await ApiService.desktopModule(m.id));
    } catch (e) {
      _detailProblem[m.id] = modulesProblem(e);
    }
    _loading.remove(m.id);
    if (mounted) setState(() {});
  }

  /// A note opens inside the app, with the tutor beside it.
  Future<void> _note(ContentItem item) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => NoteTutorScreen(contentId: item.id, title: item.title, speak: widget.speak, hush: widget.hush, prepare: widget.prepare)));
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

  Widget _item(ContentItem it) {
    final locked = it.locked;
    final String action = it.type == 'notes' ? 'Read with tutor' : it.type == 'video' ? 'Watch' : it.type == 'resource' ? 'Download' : 'Open on the website';
    VoidCallback? onTap;
    if (!locked) {
      if (it.type == 'notes' && (it.htmlContent ?? '').isNotEmpty) onTap = () => _note(it);
      if (it.type == 'video') onTap = () => _link(it.youtubeUrl);
      if (it.type == 'resource') onTap = () => _link(it.resourceUrl);
    }
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.only(left: 8),
      leading: Icon(locked ? Icons.lock_outline_rounded : _icon(it.type), size: 20, color: locked ? Colors.grey : AppColors.primary),
      title: Text(it.title, style: GoogleFonts.inter(fontSize: 13)),
      trailing: onTap == null
          ? Text(locked ? 'Upgrade on the website' : 'Website', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary))
          : TextButton(onPressed: onTap, child: Text(action)),
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
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (labs.isNotEmpty) ...[
        Padding(padding: const EdgeInsets.fromLTRB(8, 4, 0, 2), child: Text('Hands-on experiments', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12.5))),
        for (final l in labs)
          ListTile(
            dense: true,
            contentPadding: const EdgeInsets.only(left: 8),
            leading: const Icon(Icons.science_rounded, size: 20, color: AppColors.accent),
            title: Text(l.title, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
            trailing: ElevatedButton(onPressed: widget.canStart ? () => widget.onStartLab(l.id) : null, child: const Text('Start')),
          ),
      ],
      for (final t in d.topics) ...[
        Padding(padding: const EdgeInsets.fromLTRB(8, 10, 0, 0), child: Text(t.title, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13))),
        for (final st in t.subtopics) ...[
          if (st.title.isNotEmpty && st.title != t.title)
            Padding(padding: const EdgeInsets.fromLTRB(8, 4, 0, 0), child: Text(st.title, style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.textSecondary))),
          for (final it in st.contentItems) _item(it),
        ],
      ],
      if (d.topics.isEmpty) Padding(padding: const EdgeInsets.all(12), child: Text('This module has no lessons yet.', style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textSecondary))),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final modules = _modules;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text('Your modules', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15))),
        IconButton(tooltip: 'Refresh', onPressed: _load, icon: const Icon(Icons.refresh_rounded, size: 20)),
      ]),
      Text('Your notes, videos and experiments. Each module loads only when you open it.', style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.textSecondary)),
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
                subtitle: m.description.isEmpty ? null : Text(m.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 11.5)),
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
