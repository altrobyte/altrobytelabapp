import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../models/training_module_model.dart';
import '../../providers/training_module_provider.dart';
import '../../services/api_service.dart';
import 'ai_lab_screen.dart';
import 'notes_editor_screen.dart';

/// Admin screen — hierarchical editor for a single training module.
/// Supports add/edit/delete for Topics, Subtopics, and Content Items.
class ModuleDetailScreen extends StatefulWidget {
  final TrainingModule module;
  const ModuleDetailScreen({super.key, required this.module});

  @override
  State<ModuleDetailScreen> createState() => _ModuleDetailScreenState();
}

class _ModuleDetailScreenState extends State<ModuleDetailScreen> {
  final Set<int> _expandedTopics = {};
  final Set<int> _expandedSubtopics = {};
  bool _autoExpanded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<TrainingModuleProvider>();
      await provider.loadModuleDetail(widget.module.id);
      if (!mounted) return;
      _maybeAutoExpand(provider.currentModule);
    });
  }

  @override
  void dispose() {
    context.read<TrainingModuleProvider>().clearCurrent();
    super.dispose();
  }

  void _maybeAutoExpand(TrainingModule? module) {
    if (_autoExpanded || module == null || module.topics.isEmpty) return;
    _autoExpanded = true;
    setState(() => _expandedTopics.add(module.topics.first.id));
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppColors.primary;
    }
  }

  // ── Topic CRUD ─────────────────────────────────────────────────────────

  void _addTopic(Color color) {
    final ctl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Add Topic',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: TextField(
          controller: ctl,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Topic Title',
            hintText: 'e.g., Arrays & Strings',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          style: GoogleFonts.inter(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: GoogleFonts.inter(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              if (ctl.text.trim().isEmpty) return;
              final title = ctl.text.trim();
              final provider = context.read<TrainingModuleProvider>();
              Navigator.pop(ctx);
              final ok = await provider.addTopic(widget.module.id, title);
              if (!mounted) return;
              if (ok) {
                setState(() => _expandedTopics
                    .add(provider.currentModule!.topics.last.id));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(provider.error ?? 'Failed to add topic'),
                    backgroundColor: AppColors.error));
              }
            },
            child: Text('Add',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _editTopic(ModuleTopic topic, Color color) {
    final ctl = TextEditingController(text: topic.title);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Edit Topic',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: TextField(
          controller: ctl,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Topic Title',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          style: GoogleFonts.inter(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: GoogleFonts.inter(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              if (ctl.text.trim().isEmpty) return;
              final title = ctl.text.trim();
              final provider = context.read<TrainingModuleProvider>();
              Navigator.pop(ctx);
              final ok = await provider.updateTopic(topic.id, title);
              if (!ok && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(provider.error ?? 'Failed to update topic'),
                    backgroundColor: AppColors.error));
              }
            },
            child: Text('Save',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteTopic(ModuleTopic topic) async {
    final provider = context.read<TrainingModuleProvider>();
    final ok = await provider.deleteTopic(topic.id);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(provider.error ?? 'Failed to delete topic'),
          backgroundColor: AppColors.error));
    }
  }

  // ── Subtopic CRUD ──────────────────────────────────────────────────────

  void _addSubtopic(ModuleTopic topic, Color color) {
    final ctl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Add Subtopic',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: TextField(
          controller: ctl,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Subtopic Title',
            hintText: 'e.g., Array Basics',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          style: GoogleFonts.inter(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: GoogleFonts.inter(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              if (ctl.text.trim().isEmpty) return;
              final title = ctl.text.trim();
              final provider = context.read<TrainingModuleProvider>();
              Navigator.pop(ctx);
              final ok = await provider.addSubtopic(topic.id, title);
              if (!mounted) return;
              if (ok) {
                final updatedTopic = provider.currentModule!.topics
                    .firstWhere((t) => t.id == topic.id);
                setState(() =>
                    _expandedSubtopics.add(updatedTopic.subtopics.last.id));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(provider.error ?? 'Failed to add subtopic'),
                    backgroundColor: AppColors.error));
              }
            },
            child: Text('Add',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSubtopic(int topicId, int subtopicId) async {
    final provider = context.read<TrainingModuleProvider>();
    final ok = await provider.deleteSubtopic(subtopicId);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(provider.error ?? 'Failed to delete subtopic'),
          backgroundColor: AppColors.error));
    }
  }

  // ── Content CRUD ───────────────────────────────────────────────────────

  void _addContent(int topicId, ModuleSubtopic subtopic) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add Content to "${subtopic.title}"',
                style: GoogleFonts.poppins(
                    fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _ContentTypeCard(
                    icon: Icons.article_rounded,
                    label: 'Notes',
                    subtitle: 'HTML notes page',
                    color: AppColors.primary,
                    onTap: () {
                      Navigator.pop(ctx);
                      _addNotesContent(topicId, subtopic);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ContentTypeCard(
                    icon: Icons.quiz_rounded,
                    label: 'AI Test',
                    subtitle: 'Auto-generate from notes',
                    color: AppColors.accent,
                    onTap: () {
                      Navigator.pop(ctx);
                      _addTestContent(topicId, subtopic);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ContentTypeCard(
                    icon: Icons.play_circle_fill_rounded,
                    label: 'YouTube Video',
                    subtitle: 'Paste URL',
                    color: const Color(0xFFFF0000),
                    onTap: () {
                      Navigator.pop(ctx);
                      _addVideoContent(topicId, subtopic);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ContentTypeCard(
                    icon: Icons.attach_file_rounded,
                    label: 'Resource',
                    subtitle: 'Downloadable file link',
                    color: AppColors.primary,
                    onTap: () {
                      Navigator.pop(ctx);
                      _addResourceContent(topicId, subtopic);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ContentTypeCard(
                    icon: Icons.code_rounded,
                    label: 'Code',
                    subtitle: 'Paste a code snippet',
                    color: const Color(0xFF7C4DFF),
                    onTap: () {
                      Navigator.pop(ctx);
                      _addCodeContent(topicId, subtopic);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ContentTypeCard(
                    icon: FontAwesomeIcons.github.data,
                    label: 'GitHub Project',
                    subtitle: 'Link a repo',
                    color: Colors.black87,
                    onTap: () {
                      Navigator.pop(ctx);
                      _addGithubContent(topicId, subtopic);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _createContent(
      ModuleSubtopic subtopic, ContentItem draft) async {
    final provider = context.read<TrainingModuleProvider>();
    final ok = await provider.addContentItem(subtopic.id, draft);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(provider.error ?? 'Failed to add content'),
          backgroundColor: AppColors.error));
    }
  }

  /// "Module > Topic > Subtopic", so AI-written notes fit where they sit.
  String _notesHint(int topicId, int subtopicId) {
    final module = context.read<TrainingModuleProvider>().currentModule ?? widget.module;
    final parts = <String>[module.title];
    for (final t in module.topics) {
      if (t.id != topicId) continue;
      parts.add(t.title);
      for (final s in t.subtopics) {
        if (s.id == subtopicId) parts.add(s.title);
      }
    }
    return parts.join(' > ');
  }

  void _addNotesContent(int topicId, ModuleSubtopic subtopic) async {
    final result = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(
        builder: (_) => NotesEditorScreen(
          initialTitle: '',
          initialHtml: '',
          contextHint: _notesHint(topicId, subtopic.id),
        ),
      ),
    );
    if (result != null && mounted) {
      final item = ContentItem(
        id: 0,
        subtopicId: subtopic.id,
        type: 'notes',
        title: result['title'] ?? 'Untitled Notes',
        htmlContent: result['html'] ?? '',
        order: subtopic.contentItems.length,
      );
      _createContent(subtopic, item);
    }
  }

  /// Combines the HTML notes already added in this subtopic into plain-text
  /// context for AI test generation — no manual test ID needed, the admin
  /// never has to know or remember one.
  String _notesContextFor(ModuleSubtopic subtopic) {
    final notesText = subtopic.contentItems
        .where((c) => c.type == 'notes' && (c.htmlContent ?? '').isNotEmpty)
        .map((c) => c.htmlContent!.replaceAll(RegExp(r'<[^>]*>'), ' '))
        .join('\n\n');
    // Keep prompt size sane
    return notesText.length > 4000 ? notesText.substring(0, 4000) : notesText;
  }

  void _addTestContent(int topicId, ModuleSubtopic subtopic) {
    final titleCtl = TextEditingController(text: subtopic.title);
    final countCtl = TextEditingController(text: '10');
    final notesContext = _notesContextFor(subtopic);
    bool generating = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Text('Generate Test from Notes',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                notesContext.isEmpty
                    ? 'No notes found in this section yet — add a Notes item first '
                      'so the AI has content to base questions on, or the test will '
                      'be generated from the section title alone.'
                    : 'AI will generate questions based on the notes already added '
                      'in "${subtopic.title}".',
                style: GoogleFonts.inter(
                    fontSize: 12.5,
                    color: notesContext.isEmpty ? Colors.orange.shade800 : AppColors.textSecondary),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: titleCtl,
                decoration: InputDecoration(
                  labelText: 'Test Title',
                  hintText: 'e.g., Arrays Practice Test',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                style: GoogleFonts.inter(fontSize: 14),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: countCtl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Number of Questions',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  prefixIcon: const Icon(Icons.format_list_numbered_rounded),
                ),
                style: GoogleFonts.inter(fontSize: 14),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: generating ? null : () => Navigator.pop(ctx),
              child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: generating
                  ? null
                  : () async {
                      if (titleCtl.text.trim().isEmpty) return;
                      setDialogState(() => generating = true);
                      try {
                        final test = await ApiService.generateTest({
                          'institute_id': widget.module.instituteId,
                          'title': titleCtl.text.trim(),
                          'subject': widget.module.title,
                          'topic': subtopic.title,
                          'difficulty': 'Medium',
                          'exam_type': 'General',
                          'language': 'English',
                          'count': int.tryParse(countCtl.text) ?? 10,
                          'duration_mins': 20,
                          'custom_instructions': notesContext.isEmpty
                              ? ''
                              : 'Base the questions on this study material:\n$notesContext',
                        });
                        final item = ContentItem(
                          id: 0,
                          subtopicId: subtopic.id,
                          type: 'test',
                          title: titleCtl.text.trim(),
                          testId: test['id'] as int,
                          testTitle: titleCtl.text.trim(),
                          order: subtopic.contentItems.length,
                        );
                        await _createContent(subtopic, item);
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (e) {
                        setDialogState(() => generating = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error));
                        }
                      }
                    },
              child: generating
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text('Generate & Add', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  void _addVideoContent(int topicId, ModuleSubtopic subtopic) {
    final titleCtl = TextEditingController();
    final urlCtl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Add YouTube Video',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtl,
              decoration: InputDecoration(
                labelText: 'Video Title',
                hintText: 'e.g., Arrays Explained',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              style: GoogleFonts.inter(fontSize: 14),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlCtl,
              decoration: InputDecoration(
                labelText: 'YouTube URL',
                hintText: 'https://www.youtube.com/watch?v=...',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                prefixIcon:
                    const Icon(Icons.play_circle_rounded, color: Colors.red),
              ),
              style: GoogleFonts.inter(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: GoogleFonts.inter(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              if (titleCtl.text.trim().isEmpty || urlCtl.text.trim().isEmpty) {
                return;
              }
              final item = ContentItem(
                id: 0,
                subtopicId: subtopic.id,
                type: 'video',
                title: titleCtl.text.trim(),
                youtubeUrl: urlCtl.text.trim(),
                order: subtopic.contentItems.length,
              );
              _createContent(subtopic, item);
              Navigator.pop(ctx);
            },
            child: Text('Add',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _addCodeContent(int topicId, ModuleSubtopic subtopic) {
    final titleCtl = TextEditingController();
    final codeCtl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Add Code Snippet',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtl,
                decoration: InputDecoration(
                  labelText: 'Title',
                  hintText: 'e.g., ESP32 BLE Server Example',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                style: GoogleFonts.inter(fontSize: 14),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: codeCtl,
                maxLines: 14,
                minLines: 8,
                decoration: InputDecoration(
                  labelText: 'Code',
                  hintText: 'Paste the full code here...',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                style: GoogleFonts.robotoMono(fontSize: 12.5),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: GoogleFonts.inter(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C4DFF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              if (titleCtl.text.trim().isEmpty || codeCtl.text.trim().isEmpty) {
                return;
              }
              final item = ContentItem(
                id: 0,
                subtopicId: subtopic.id,
                type: 'code',
                title: titleCtl.text.trim(),
                htmlContent: codeCtl.text,
                order: subtopic.contentItems.length,
              );
              _createContent(subtopic, item);
              Navigator.pop(ctx);
            },
            child: Text('Add',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _addGithubContent(int topicId, ModuleSubtopic subtopic) {
    final titleCtl = TextEditingController();
    final urlCtl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Add GitHub Project',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtl,
              decoration: InputDecoration(
                labelText: 'Project Title',
                hintText: 'e.g., ESP32 BLE Demo Project',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              style: GoogleFonts.inter(fontSize: 14),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlCtl,
              decoration: InputDecoration(
                labelText: 'GitHub Repo URL',
                hintText: 'https://github.com/user/repo',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                prefixIcon: const Padding(
                  padding: EdgeInsets.all(12),
                  child: FaIcon(FontAwesomeIcons.github, size: 18),
                ),
              ),
              style: GoogleFonts.inter(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: GoogleFonts.inter(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black87,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              if (titleCtl.text.trim().isEmpty || urlCtl.text.trim().isEmpty) {
                return;
              }
              final item = ContentItem(
                id: 0,
                subtopicId: subtopic.id,
                type: 'github',
                title: titleCtl.text.trim(),
                resourceUrl: urlCtl.text.trim(),
                order: subtopic.contentItems.length,
              );
              _createContent(subtopic, item);
              Navigator.pop(ctx);
            },
            child: Text('Add',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _addResourceContent(int topicId, ModuleSubtopic subtopic) {
    final titleCtl = TextEditingController();
    final urlCtl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Add Downloadable Resource',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtl,
              decoration: InputDecoration(
                labelText: 'Resource Title',
                hintText: 'e.g., Lecture Slides (PDF)',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              style: GoogleFonts.inter(fontSize: 14),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlCtl,
              decoration: InputDecoration(
                labelText: 'File URL',
                hintText: 'https://...',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                prefixIcon:
                    const Icon(Icons.attach_file_rounded, color: AppColors.primary),
              ),
              style: GoogleFonts.inter(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: GoogleFonts.inter(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              if (titleCtl.text.trim().isEmpty || urlCtl.text.trim().isEmpty) {
                return;
              }
              final item = ContentItem(
                id: 0,
                subtopicId: subtopic.id,
                type: 'resource',
                title: titleCtl.text.trim(),
                resourceUrl: urlCtl.text.trim(),
                order: subtopic.contentItems.length,
              );
              _createContent(subtopic, item);
              Navigator.pop(ctx);
            },
            child: Text('Add',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _editNotesContent(int topicId, int subtopicId, ContentItem item) async {
    final result = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(
        builder: (_) => NotesEditorScreen(
          initialTitle: item.title,
          initialHtml: item.htmlContent ?? '',
          contextHint: _notesHint(topicId, subtopicId),
        ),
      ),
    );
    if (result != null && mounted) {
      final updated = item.copyWith(
        title: result['title'],
        htmlContent: result['html'],
      );
      final provider = context.read<TrainingModuleProvider>();
      final ok = await provider.updateContentItem(updated);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(provider.error ?? 'Failed to update notes'),
            backgroundColor: AppColors.error));
      }
    }
  }

  // ── Rename / edit ──────────────────────────────────────────────────────

  /// Small multi-field dialog. Returns the trimmed values, or null on cancel.
  Future<List<String>?> _formDialog(
    String title,
    Color color,
    List<({String label, String value, int lines})> fields,
  ) {
    final ctls = [for (final f in fields) TextEditingController(text: f.value)];
    return showDialog<List<String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              for (var i = 0; i < fields.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                TextField(
                  controller: ctls[i],
                  autofocus: i == 0,
                  minLines: 1,
                  maxLines: fields[i].lines,
                  decoration: InputDecoration(
                    labelText: fields[i].label,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  style: fields[i].lines > 1
                      ? GoogleFonts.robotoMono(fontSize: 12.5)
                      : GoogleFonts.inter(fontSize: 14),
                ),
              ],
            ]),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              if (ctls.first.text.trim().isEmpty) return;
              Navigator.pop(ctx, [for (final c in ctls) c.text.trim()]);
            },
            child: Text('Save', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showError(String? msg, String fallback) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg ?? fallback), backgroundColor: AppColors.error));
  }

  Future<void> _editModuleTitle(TrainingModule module, Color color) async {
    final res = await _formDialog('Rename Module', color,
        [(label: 'Module Title', value: module.title, lines: 1)]);
    if (res == null || !mounted) return;
    final provider = context.read<TrainingModuleProvider>();
    if (!await provider.updateModule(module.id, title: res[0])) {
      _showError(provider.error, 'Failed to rename module');
    }
  }

  Future<void> _editSubtopic(ModuleSubtopic subtopic, Color color) async {
    final res = await _formDialog('Edit Subtopic', color,
        [(label: 'Subtopic Title', value: subtopic.title, lines: 1)]);
    if (res == null || !mounted) return;
    final provider = context.read<TrainingModuleProvider>();
    if (!await provider.updateSubtopic(subtopic.id, res[0])) {
      _showError(provider.error, 'Failed to update subtopic');
    }
  }

  /// Notes open the full editor; every other type gets a small form for the
  /// fields it actually has (title, plus a link or the code text).
  Future<void> _editContent(int topicId, int subtopicId, ContentItem item, Color color) async {
    if (item.type == 'notes') {
      _editNotesContent(topicId, subtopicId, item);
      return;
    }
    final fields = <({String label, String value, int lines})>[
      (label: 'Title', value: item.title, lines: 1),
      if (item.type == 'video') (label: 'YouTube URL', value: item.youtubeUrl ?? '', lines: 1),
      if (item.type == 'resource' || item.type == 'github')
        (label: item.type == 'github' ? 'Repository URL' : 'Resource URL', value: item.resourceUrl ?? '', lines: 1),
      if (item.type == 'code') (label: 'Code', value: item.htmlContent ?? '', lines: 14),
    ];
    final res = await _formDialog('Edit Content', color, fields);
    if (res == null || !mounted) return;
    final updated = item.copyWith(
      title: res[0],
      youtubeUrl: item.type == 'video' ? res[1] : null,
      resourceUrl: (item.type == 'resource' || item.type == 'github') ? res[1] : null,
      htmlContent: item.type == 'code' ? res[1] : null,
    );
    final provider = context.read<TrainingModuleProvider>();
    if (!await provider.updateContentItem(updated)) {
      _showError(provider.error, 'Failed to update content');
    }
  }

  // ── Reorder ────────────────────────────────────────────────────────────
  // onReorderItem already hands us the index the row ends up at.

  int _fixIndex(int oldIndex, int newIndex) => newIndex;

  Future<void> _reorder(Future<bool> Function() run) async {
    final provider = context.read<TrainingModuleProvider>();
    if (!await run()) _showError(provider.error, 'Could not save the new order');
  }

  void _reorderTopics(int o, int n) {
    if (o == _fixIndex(o, n)) return;
    _reorder(() => context.read<TrainingModuleProvider>().reorderTopics(o, _fixIndex(o, n)));
  }

  void _reorderSubtopics(int topicId, int o, int n) {
    if (o == _fixIndex(o, n)) return;
    _reorder(() => context.read<TrainingModuleProvider>().reorderSubtopics(topicId, o, _fixIndex(o, n)));
  }

  void _reorderContent(int subtopicId, int o, int n) {
    if (o == _fixIndex(o, n)) return;
    _reorder(() => context.read<TrainingModuleProvider>().reorderContent(subtopicId, o, _fixIndex(o, n)));
  }

  /// Moves a note (or any item) into another subtopic of this module: pick it from the list, it goes there as the last item.
  Future<void> _moveContent(int fromSubtopicId, ContentItem item) async {
    final provider = context.read<TrainingModuleProvider>();
    final module = provider.currentModule;
    if (module == null) return;
    final target = await showDialog<int>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('Move "${item.title}" to', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
        content: SizedBox(
          width: 460,
          child: ListView(shrinkWrap: true, children: [
            for (final t in module.topics) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
                child: Text(t.title, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13)),
              ),
              for (final st in t.subtopics)
                ListTile(
                  dense: true,
                  enabled: st.id != fromSubtopicId,
                  leading: Icon(st.id == fromSubtopicId ? Icons.check_rounded : Icons.subdirectory_arrow_right_rounded, size: 18),
                  title: Text(st.title.isEmpty ? '(untitled)' : st.title),
                  subtitle: st.id == fromSubtopicId ? const Text('It is here now') : null,
                  onTap: () => Navigator.pop(d, st.id),
                ),
            ],
          ]),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel'))],
      ),
    );
    if (target == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ApiService.moveContent(item.id, target);
      await provider.loadModuleDetail(module.id);
      _expandedSubtopics.add(target);
      if (mounted) setState(() {});
      messenger.showSnackBar(SnackBar(content: Text('Moved "${item.title}"')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not move it: ${e.toString().replaceFirst('Exception: ', '')}'),
          backgroundColor: AppColors.error));
    }
  }

  Future<void> _deleteContent(
      int topicId, int subtopicId, int contentId) async {
    final provider = context.read<TrainingModuleProvider>();
    final ok = await provider.deleteContentItem(subtopicId, contentId);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(provider.error ?? 'Failed to delete content'),
          backgroundColor: AppColors.error));
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TrainingModuleProvider>();
    final module = provider.currentModule ?? widget.module;
    final color = _parseColor(module.color);
    final loading = provider.isLoading && provider.currentModule == null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: color,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(module.title,
                style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 16)),
            Text(
                '${module.topicCount} topics • ${module.totalContentItems} content items',
                style: GoogleFonts.inter(color: Colors.white70, fontSize: 12)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'AI Lab: let learners experiment with an AI assistant',
            icon: Icon(Icons.science_rounded, color: module.aiLabEnabled ? Colors.amberAccent : Colors.white, size: 20),
            onPressed: loading
                ? null
                : () async {
                    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => AiLabScreen(moduleId: module.id, title: module.title)));
                    if (mounted) context.read<TrainingModuleProvider>().loadModuleDetail(module.id);
                  },
          ),
          IconButton(
            tooltip: 'Rename module',
            icon: const Icon(Icons.edit_rounded, color: Colors.white, size: 20),
            onPressed: loading ? null : () => _editModuleTitle(module, color),
          ),
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              module.isPublished ? '● Published' : '● Draft',
              style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      floatingActionButton: loading
          ? null
          : FloatingActionButton.extended(
              backgroundColor: color,
              onPressed: () => _addTopic(color),
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: Text('Add Topic',
                  style: GoogleFonts.inter(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : module.topics.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.topic_rounded,
                          size: 56, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text('No Topics Yet',
                          style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary)),
                      const SizedBox(height: 4),
                      Text('Add your first topic to start building content',
                          style: GoogleFonts.inter(
                              fontSize: 13, color: AppColors.textSecondary)),
                    ],
                  ),
                )
              : ReorderableListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                  buildDefaultDragHandles: false,
                  itemCount: module.topics.length,
                  onReorderItem: _reorderTopics,
                  itemBuilder: (context, index) {
                    final topic = module.topics[index];
                    return _TopicCard(
                      key: ValueKey('topic-${topic.id}'),
                      index: index,
                      topic: topic,
                      color: color,
                      isExpanded: _expandedTopics.contains(topic.id),
                      expandedSubtopics: _expandedSubtopics,
                      onToggle: () => setState(() {
                        if (_expandedTopics.contains(topic.id)) {
                          _expandedTopics.remove(topic.id);
                        } else {
                          _expandedTopics.add(topic.id);
                        }
                      }),
                      onToggleSubtopic: (id) => setState(() {
                        if (_expandedSubtopics.contains(id)) {
                          _expandedSubtopics.remove(id);
                        } else {
                          _expandedSubtopics.add(id);
                        }
                      }),
                      onEdit: () => _editTopic(topic, color),
                      onDelete: () => _deleteTopic(topic),
                      onAddSubtopic: () => _addSubtopic(topic, color),
                      onDeleteSubtopic: (subtopicId) =>
                          _deleteSubtopic(topic.id, subtopicId),
                      onAddContent: (subtopic) =>
                          _addContent(topic.id, subtopic),
                      onEditSubtopic: (subtopic) => _editSubtopic(subtopic, color),
                      onReorderSubtopics: (o, n) => _reorderSubtopics(topic.id, o, n),
                      onReorderContent: _reorderContent,
                      onEditContent: (subtopicId, item) =>
                          _editContent(topic.id, subtopicId, item, color),
                      onDeleteContent: (subtopicId, contentId) =>
                          _deleteContent(topic.id, subtopicId, contentId),
                      onMoveContent: _moveContent,
                    );
                  },
                ),
    );
  }
}

// ── Topic Card ───────────────────────────────────────────────────────────

class _TopicCard extends StatelessWidget {
  final int index;
  final ModuleTopic topic;
  final Color color;
  final bool isExpanded;
  final Set<int> expandedSubtopics;
  final VoidCallback onToggle;
  final ValueChanged<int> onToggleSubtopic;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onAddSubtopic;
  final ValueChanged<int> onDeleteSubtopic;
  final ValueChanged<ModuleSubtopic> onAddContent;
  final ValueChanged<ModuleSubtopic> onEditSubtopic;
  final void Function(int oldIndex, int newIndex) onReorderSubtopics;
  final void Function(int subtopicId, int oldIndex, int newIndex) onReorderContent;
  final Function(int subtopicId, ContentItem item) onEditContent;
  final Function(int subtopicId, int contentId) onDeleteContent;
  final void Function(int subtopicId, ContentItem item) onMoveContent;

  const _TopicCard({
    super.key,
    required this.index,
    required this.topic,
    required this.color,
    required this.isExpanded,
    required this.expandedSubtopics,
    required this.onToggle,
    required this.onToggleSubtopic,
    required this.onEdit,
    required this.onDelete,
    required this.onAddSubtopic,
    required this.onAddContent,
    required this.onEditSubtopic,
    required this.onReorderSubtopics,
    required this.onReorderContent,
    required this.onEditContent,
    required this.onDeleteContent,
    required this.onDeleteSubtopic,
    required this.onMoveContent,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 1,
      child: Column(
        children: [
          // Topic header
          InkWell(
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(14),
              bottom: isExpanded ? Radius.zero : const Radius.circular(14),
            ),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.folder_rounded, color: color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(topic.title,
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: AppColors.textPrimary)),
                        Text(
                            '${topic.subtopics.length} subtopics • ${topic.totalContentItems} items',
                            style: GoogleFonts.inter(
                                fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  ReorderableDragStartListener(
                    index: index,
                    child: const MouseRegion(
                      cursor: SystemMouseCursors.grab,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: _DragGrip(color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_rounded, size: 18),
                    color: AppColors.textSecondary,
                    onPressed: onEdit,
                    visualDensity: VisualDensity.compact,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    color: AppColors.error,
                    onPressed: onDelete,
                    visualDensity: VisualDensity.compact,
                  ),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.expand_more_rounded,
                        color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),

          // Expanded content
          if (isExpanded)
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.03),
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(14)),
              ),
              child: Column(
                children: [
                  const Divider(height: 1),
                  ReorderableListView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    onReorderItem: onReorderSubtopics,
                    children: [
                      for (var i = 0; i < topic.subtopics.length; i++)
                        _SubtopicTile(
                          key: ValueKey('subtopic-${topic.subtopics[i].id}'),
                          index: i,
                          subtopic: topic.subtopics[i],
                          color: color,
                          isExpanded: expandedSubtopics.contains(topic.subtopics[i].id),
                          onToggle: () => onToggleSubtopic(topic.subtopics[i].id),
                          onAddContent: () => onAddContent(topic.subtopics[i]),
                          onEdit: () => onEditSubtopic(topic.subtopics[i]),
                          onReorderContent: (o, n) =>
                              onReorderContent(topic.subtopics[i].id, o, n),
                          onEditContent: (item) =>
                              onEditContent(topic.subtopics[i].id, item),
                          onDeleteContent: (contentId) =>
                              onDeleteContent(topic.subtopics[i].id, contentId),
                          onMoveContent: (item) => onMoveContent(topic.subtopics[i].id, item),
                          onDelete: () => onDeleteSubtopic(topic.subtopics[i].id),
                        ),
                    ],
                  ),
                  // Add subtopic button
                  InkWell(
                    onTap: onAddSubtopic,
                    borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(14)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Icon(Icons.add_circle_outline_rounded,
                              color: color, size: 18),
                          const SizedBox(width: 8),
                          Text('Add Subtopic',
                              style: GoogleFonts.inter(
                                  color: color,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── Subtopic Tile ────────────────────────────────────────────────────────

class _SubtopicTile extends StatelessWidget {
  final int index;
  final ModuleSubtopic subtopic;
  final Color color;
  final bool isExpanded;
  final VoidCallback onToggle;
  final VoidCallback onAddContent;
  final VoidCallback onEdit;
  final void Function(int oldIndex, int newIndex) onReorderContent;
  final ValueChanged<ContentItem> onEditContent;
  final ValueChanged<int> onDeleteContent;
  final ValueChanged<ContentItem> onMoveContent;
  final VoidCallback onDelete;

  const _SubtopicTile({
    super.key,
    required this.index,
    required this.subtopic,
    required this.color,
    required this.isExpanded,
    required this.onToggle,
    required this.onAddContent,
    required this.onEdit,
    required this.onReorderContent,
    required this.onEditContent,
    required this.onDeleteContent,
    required this.onMoveContent,
    required this.onDelete,
  });

  String _contentLabel(ContentItem item) {
    switch (item.type) {
      case 'notes':
        return 'HTML Notes';
      case 'test':
        return 'Test #${item.testId}';
      case 'video':
        return 'YouTube Video';
      case 'resource':
        return 'Resource';
      case 'code':
        return 'Code';
      case 'github':
        return 'GitHub repo';
      default:
        return item.type;
    }
  }

  IconData _contentIcon(String type) {
    switch (type) {
      case 'notes':
        return Icons.article_rounded;
      case 'test':
        return Icons.quiz_rounded;
      case 'video':
        return Icons.play_circle_fill_rounded;
      case 'resource':
        return Icons.attach_file_rounded;
      case 'code':
        return Icons.code_rounded;
      case 'github':
        return FontAwesomeIcons.github.data;
      default:
        return Icons.description_rounded;
    }
  }

  Color _contentColor(String type) {
    switch (type) {
      case 'notes':
        return AppColors.primary;
      case 'test':
        return AppColors.accent;
      case 'video':
        return Colors.red;
      case 'resource':
        return AppColors.primary;
      case 'code':
        return const Color(0xFF7C4DFF);
      case 'github':
        return Colors.black87;
      default:
        return Colors.grey;
    }
  }

  Widget _contentRow(ContentItem item, int idx) {
    return Padding(
      key: ValueKey('content-${item.id}'),
      padding: const EdgeInsets.only(left: 68, right: 16, bottom: 4),
      child: Material(
        color: _contentColor(item.type).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => onEditContent(item),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Icon(_contentIcon(item.type), color: _contentColor(item.type), size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.title,
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary)),
                      Text(_contentLabel(item),
                          style: GoogleFonts.inter(fontSize: 10, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                ReorderableDragStartListener(
                  index: idx,
                  child: const MouseRegion(
                    cursor: SystemMouseCursors.grab,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: _DragGrip(color: Colors.grey),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.drive_file_move_outline, size: 16),
                  color: Colors.grey,
                  tooltip: 'Move to another subtopic',
                  onPressed: () => onMoveContent(item),
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  icon: const Icon(Icons.edit_rounded, size: 15),
                  color: Colors.grey,
                  tooltip: 'Edit',
                  onPressed: () => onEditContent(item),
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 16),
                  color: Colors.grey,
                  tooltip: 'Delete',
                  onPressed: () => onDeleteContent(item.id),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const SizedBox(width: 16),
                Icon(Icons.subdirectory_arrow_right_rounded,
                    color: Colors.grey[400], size: 18),
                const SizedBox(width: 8),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.topic_rounded,
                      color: color.withValues(alpha: 0.7), size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(subtopic.title,
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                              color: AppColors.textPrimary)),
                      Text('${subtopic.contentItems.length} items',
                          style: GoogleFonts.inter(
                              fontSize: 11, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                ReorderableDragStartListener(
                  index: index,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.grab,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: _DragGrip(color: Colors.grey.shade500),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_rounded, size: 16),
                  color: AppColors.textSecondary,
                  onPressed: onEdit,
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 16),
                  color: AppColors.error.withValues(alpha: 0.7),
                  onPressed: onDelete,
                  visualDensity: VisualDensity.compact,
                ),
                AnimatedRotation(
                  turns: isExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(Icons.expand_more_rounded,
                      color: Colors.grey[400], size: 20),
                ),
              ],
            ),
          ),
        ),

        // Content items
        if (isExpanded) ...[
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            onReorderItem: onReorderContent,
            children: [
              for (var idx = 0; idx < subtopic.contentItems.length; idx++)
                _contentRow(subtopic.contentItems[idx], idx),
            ],
          ),
          // Add content button
          Padding(
            padding:
                const EdgeInsets.only(left: 68, right: 16, bottom: 8, top: 2),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onAddContent,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(
                      color: color.withValues(alpha: 0.3),
                      style: BorderStyle.solid),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, color: color, size: 16),
                    const SizedBox(width: 6),
                    Text('Add Content',
                        style: GoogleFonts.inter(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Content Type Card (for bottom sheet) ─────────────────────────────────

class _ContentTypeCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ContentTypeCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(label,
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppColors.textPrimary)),
            Text(subtitle,
                style: GoogleFonts.inter(
                    fontSize: 11, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}


/// Six-dot drag handle, drawn with widgets rather than an icon glyph. The icon
/// font is a per-build subset that browsers cache; a handle that depends on a
/// glyph added in a later build renders blank for anyone holding the old font.
class _DragGrip extends StatelessWidget {
  final Color color;
  const _DragGrip({required this.color});

  @override
  Widget build(BuildContext context) {
    Widget dot() => Container(
          width: 3.5,
          height: 3.5,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        );
    Widget column() => Column(
          mainAxisSize: MainAxisSize.min,
          children: [dot(), const SizedBox(height: 3), dot(), const SizedBox(height: 3), dot()],
        );
    return Tooltip(
      message: 'Drag to reorder',
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [column(), const SizedBox(width: 3), column()],
        ),
      ),
    );
  }
}
