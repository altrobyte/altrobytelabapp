import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../constants/app_colors.dart';
import '../../models/training_module_model.dart';
import '../../providers/training_module_provider.dart';
import '../training_modules/module_purchase_section.dart';
import 'code_viewer_screen.dart';
import 'student_notes_viewer_screen.dart';
import 'ai_lab_visuals_screen.dart';

/// Student module detail — expandable tree of Topics → Subtopics → Content
/// with completion tracking.
class StudentModuleDetailScreen extends StatefulWidget {
  final TrainingModule module;
  final Set<int> completedIds;

  const StudentModuleDetailScreen({
    super.key,
    required this.module,
    required this.completedIds,
  });

  @override
  State<StudentModuleDetailScreen> createState() =>
      _StudentModuleDetailScreenState();
}

class _StudentModuleDetailScreenState extends State<StudentModuleDetailScreen> {
  final Set<int> _expandedTopics = {};
  final Set<int> _expandedSubtopics = {};
  bool _autoExpanded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<TrainingModuleProvider>();
      await Future.wait([
        provider.loadModuleDetailAsStudent(widget.module.id),
        provider.loadProgress(widget.module.id),
      ]);
      if (!mounted) return;
      _maybeAutoExpand(provider.currentModule);
    });
  }

  void _maybeAutoExpand(TrainingModule? module) {
    if (_autoExpanded || module == null || module.topics.isEmpty) return;
    _autoExpanded = true;
    final firstTopic = module.topics.first;
    setState(() {
      _expandedTopics.add(firstTopic.id);
      if (firstTopic.subtopics.isNotEmpty) {
        _expandedSubtopics.add(firstTopic.subtopics.first.id);
      }
    });
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppColors.primary;
    }
  }

  static const _tierNames = {'999': 'Plus', '4999': 'Pro', '9999': 'Elite'};

  void _showLockedSheet(ContentItem item) {
    final tier = _tierNames[item.upgradeRequired] ?? 'a paid';
    final what = switch (item.type) {
      'video' => 'Videos',
      'resource' => 'Downloadable resources',
      'github' => 'This GitHub project',
      _ => 'This content',
    };
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.lock_rounded, size: 40, color: AppColors.accent),
          const SizedBox(height: 14),
          Text(item.title,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('$what are included from the $tier plan onwards.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13.5, height: 1.5,
                  color: AppColors.textSecondary)),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                context.push('/pricing');
              },
              child: Text('See plans',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
            ),
          ),
        ]),
      ),
    );
  }

  void _openContent(TrainingModuleProvider provider, ContentItem item) async {
    // The server already stripped the URL and body, so there is nothing to
    // open — offer the plan that would unlock it instead.
    if (item.locked) {
      _showLockedSheet(item);
      return;
    }
    switch (item.type) {
      case 'notes':
        // The next open note of the module, in course order: the lesson moves on to it by itself when it ends.
        final notes = [
          for (final t in (provider.currentModule ?? widget.module).topics)
            for (final st in t.subtopics)
              for (final it in st.contentItems)
                if (it.type == 'notes') it
        ];
        final i = notes.indexWhere((n) => n.id == item.id);
        ContentItem? next;
        for (final n in i < 0 ? const <ContentItem>[] : notes.skip(i + 1)) {
          if (!n.locked && (n.htmlContent ?? '').isNotEmpty) {
            next = n;
            break;
          }
        }
        final r = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StudentNotesViewerScreen(
              contentId: item.id,
              title: item.title,
              htmlContent: item.htmlContent ?? '',
              moduleColor: widget.module.color,
              nextTitle: next?.title,
            ),
          ),
        );
        // Auto-mark as completed after viewing
        provider.markComplete(widget.module.id, item.id);
        if (r == 'next' && next != null && mounted) _openContent(provider, next);
        break;

      case 'test':
        if (item.testId != null) {
          context.push('/test/${item.testId}');
          provider.markComplete(widget.module.id, item.id);
        }
        break;

      case 'video':
        if (item.youtubeUrl != null && item.youtubeUrl!.isNotEmpty) {
          final uri = Uri.parse(item.youtubeUrl!);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
          provider.markComplete(widget.module.id, item.id);
        }
        break;

      case 'resource':
        if (item.resourceUrl != null && item.resourceUrl!.isNotEmpty) {
          final uri = Uri.parse(item.resourceUrl!);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
          provider.markComplete(widget.module.id, item.id);
        }
        break;

      case 'code':
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CodeViewerScreen(
              title: item.title,
              code: item.htmlContent ?? '',
              moduleColor: widget.module.color,
            ),
          ),
        );
        provider.markComplete(widget.module.id, item.id);
        break;

      case 'github':
        if (item.resourceUrl != null && item.resourceUrl!.isNotEmpty) {
          final uri = Uri.parse(item.resourceUrl!);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
          provider.markComplete(widget.module.id, item.id);
        }
        break;
    }
  }

  String? _extractYoutubeId(String? url) {
    if (url == null || url.isEmpty) return null;
    try {
      final uri = Uri.parse(url);
      if (uri.host.contains('youtu.be')) return uri.pathSegments.first;
      if (uri.host.contains('youtube.com')) {
        return uri.queryParameters['v'];
      }
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TrainingModuleProvider>();
    final module = provider.currentModule ?? widget.module;
    final completed =
        provider.getProgress(widget.module.id)?.completedItemIds ??
            widget.completedIds;
    final color = _parseColor(module.color);
    final total = module.totalContentItems;
    final progress = total == 0 ? 0.0 : completed.length / total;
    final pct = (progress * 100).toInt();
    final loading = provider.isLoading && provider.currentModule == null;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // Hero header
          SliverAppBar(
            backgroundColor: color,
            expandedHeight: 160,
            pinned: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      color,
                      color.withValues(alpha: 0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(20, 80, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(module.title,
                        style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    // Progress
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progress,
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.2),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                  Colors.white),
                              minHeight: 6,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text('$pct%',
                              style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${completed.length} / ${module.totalContentItems} completed',
                      style: GoogleFonts.inter(
                          color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Loading state
          if (loading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),

          // Cross-link back to the workshop this course is bundled with
          if (!loading && module.linkedSession != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => context.push('/live-sessions/${module.linkedSession!.id}'),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(children: [
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                          child: Icon(Icons.event_available_rounded, color: color, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Bundled with a workshop', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13)),
                            const SizedBox(height: 2),
                            Text('"${module.linkedSession!.title}" — tap to view',
                                style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.textSecondary)),
                          ]),
                        ),
                        Icon(Icons.arrow_forward_ios_rounded, size: 13, color: Colors.grey[400]),
                      ]),
                    ),
                  ),
                ),
              ),
            ),

          // Paywall — course is locked until payment is confirmed
          if (!loading && module.locked)
            SliverFillRemaining(
              hasScrollBody: false,
              child: ModulePurchaseSection(
                module: module,
                onUnlocked: () =>
                    context.read<TrainingModuleProvider>().loadModuleDetailAsStudent(widget.module.id),
              ),
            ),

          // AI Lab: shown only when the teacher switched it on for this module
          if (!loading && !module.locked && module.aiLabEnabled)
            SliverToBoxAdapter(child: _AiLabCard(module: module)),

          // Content tree
          if (!loading && !module.locked)
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final topic = module.topics[index];
                  final isExpanded = _expandedTopics.contains(topic.id);

                  return Card(
                    margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 1,
                    child: Column(
                      children: [
                        // Topic header
                        InkWell(
                          borderRadius: BorderRadius.vertical(
                            top: const Radius.circular(14),
                            bottom: isExpanded
                                ? Radius.zero
                                : const Radius.circular(14),
                          ),
                          onTap: () => setState(() {
                            if (isExpanded) {
                              _expandedTopics.remove(topic.id);
                            } else {
                              _expandedTopics.add(topic.id);
                            }
                          }),
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
                                  child: Icon(Icons.folder_rounded,
                                      color: color, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(topic.title,
                                          style: GoogleFonts.poppins(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                              color: AppColors.textPrimary)),
                                      Text(
                                        '${topic.subtopics.length} subtopics • ${topic.totalContentItems} items',
                                        style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                AnimatedRotation(
                                  turns: isExpanded ? 0.5 : 0,
                                  duration: const Duration(milliseconds: 200),
                                  child: Icon(Icons.expand_more_rounded,
                                      color: Colors.grey[400]),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Subtopics
                        if (isExpanded) ...[
                          const Divider(height: 1),
                          ...topic.subtopics.map((subtopic) {
                            final subExpanded =
                                _expandedSubtopics.contains(subtopic.id);
                            return Column(
                              children: [
                                InkWell(
                                  onTap: () => setState(() {
                                    if (subExpanded) {
                                      _expandedSubtopics.remove(subtopic.id);
                                    } else {
                                      _expandedSubtopics.add(subtopic.id);
                                    }
                                  }),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 10),
                                    child: Row(
                                      children: [
                                        const SizedBox(width: 16),
                                        Icon(
                                            Icons
                                                .subdirectory_arrow_right_rounded,
                                            color: Colors.grey[400],
                                            size: 16),
                                        const SizedBox(width: 8),
                                        Container(
                                          width: 28,
                                          height: 28,
                                          decoration: BoxDecoration(
                                            color:
                                                color.withValues(alpha: 0.08),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Icon(Icons.topic_rounded,
                                              color:
                                                  color.withValues(alpha: 0.7),
                                              size: 14),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(subtopic.title,
                                              style: GoogleFonts.inter(
                                                  fontWeight: FontWeight.w500,
                                                  fontSize: 13,
                                                  color:
                                                      AppColors.textPrimary)),
                                        ),
                                        // Subtopic completion
                                        _SubtopicProgress(
                                          items: subtopic.contentItems,
                                          completed: completed,
                                          color: color,
                                        ),
                                        AnimatedRotation(
                                          turns: subExpanded ? 0.5 : 0,
                                          duration:
                                              const Duration(milliseconds: 200),
                                          child: Icon(Icons.expand_more_rounded,
                                              color: Colors.grey[400],
                                              size: 20),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                // Content items
                                if (subExpanded)
                                  ...subtopic.contentItems.map((item) {
                                    final done = completed.contains(item.id);
                                    return _ContentTile(
                                      item: item,
                                      done: done,
                                      color: color,
                                      youtubeId:
                                          _extractYoutubeId(item.youtubeUrl),
                                      onTap: () => _openContent(provider, item),
                                    );
                                  }),
                              ],
                            );
                          }),
                        ],
                      ],
                    ),
                  );
                },
                childCount: module.topics.length,
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }
}

class _SubtopicProgress extends StatelessWidget {
  final List<ContentItem> items;
  final Set<int> completed;
  final Color color;

  const _SubtopicProgress({
    required this.items,
    required this.completed,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final done = items.where((i) => completed.contains(i.id)).length;
    final total = items.length;
    if (total == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: done == total
            ? AppColors.success.withValues(alpha: 0.1)
            : color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$done/$total',
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: done == total ? AppColors.success : color,
        ),
      ),
    );
  }
}

class _ContentTile extends StatelessWidget {
  final ContentItem item;
  final bool done;
  final Color color;
  final String? youtubeId;
  final VoidCallback onTap;

  const _ContentTile({
    required this.item,
    required this.done,
    required this.color,
    this.youtubeId,
    required this.onTap,
  });

  IconData get _icon {
    if (item.locked) return Icons.lock_rounded;
    switch (item.type) {
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

  Color get _typeColor {
    if (item.locked) return Colors.grey;
    switch (item.type) {
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

  String get _typeLabel {
    if (item.locked) {
      final tier = _StudentModuleDetailScreenState._tierNames[item.upgradeRequired];
      return tier != null ? '$tier plan' : 'Locked';
    }
    switch (item.type) {
      case 'notes':
        return 'Notes';
      case 'test':
        return 'Test';
      case 'video':
        return 'Video';
      case 'resource':
        return 'Resource';
      case 'code':
        return 'Code';
      case 'github':
        return 'GitHub Project';
      default:
        return 'Content';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 56, right: 16, bottom: 6),
      child: Material(
        color: done
            ? AppColors.success.withValues(alpha: 0.05)
            : _typeColor.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                // Completion indicator
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: done
                        ? AppColors.success
                        : Colors.grey.withValues(alpha: 0.2),
                  ),
                  child: done
                      ? const Icon(Icons.check_rounded,
                          color: Colors.white, size: 16)
                      : null,
                ),
                const SizedBox(width: 10),
                // Type icon
                Icon(_icon, color: _typeColor, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.title,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: done
                                ? AppColors.textSecondary
                                : AppColors.textPrimary,
                            decoration:
                                done ? TextDecoration.lineThrough : null,
                          )),
                      Text(_typeLabel,
                          style: GoogleFonts.inter(
                              fontSize: 11, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                // Thumbnail for videos
                if (item.type == 'video' && youtubeId != null)
                  Container(
                    width: 48,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(Icons.play_arrow_rounded,
                        color: Colors.white, size: 18),
                  ),
                if (item.type != 'video')
                  Icon(Icons.arrow_forward_ios_rounded,
                      color: Colors.grey[400], size: 14),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


/// "Start experimenting with Altrobyte AI Lab assistant": the experiments of this module (each made from one of its notes).
/// Starting one opens the editor on the learner's own computer, where the assistant runs it.
class _AiLabCard extends StatelessWidget {
  final TrainingModule module;
  const _AiLabCard({required this.module});

  Future<void> _openInVsCode(BuildContext context, AiLabInfo lab) async {
    final uri = Uri.parse('vscode://altrobytelab.altrobyte-trainer/lab?lab=${lab.id}&module=${module.id}');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication).catchError((_) => false);
    if (!ok && context.mounted) {
      context.push('/connect-vscode'); // VS Code or the extension is not there yet: show how to set it up
    }
  }

  @override
  Widget build(BuildContext context) {
    final labs = module.aiLabs;
    if (labs.isEmpty) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      elevation: 0,
      color: const Color(0xFF14213D),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.science_rounded, color: Colors.amberAccent),
            const SizedBox(width: 10),
            Expanded(
              child: Text('Start experimenting with Altrobyte AI Lab assistant',
                  style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
            ),
          ]),
          const SizedBox(height: 8),
          Text(
              'Do the experiment on your own computer and board. The assistant has read the notes: it shows you the wiring, '
              'tells you exactly where to write code, and checks every step for real.',
              style: GoogleFonts.inter(color: Colors.white70, height: 1.5, fontSize: 13)),
          const SizedBox(height: 12),
          for (final lab in labs)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
              // The title, then the ways in; on a phone the buttons go onto the next line instead of squeezing the title.
              child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 4, runSpacing: 4, children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 180, maxWidth: 360),
                  child: Text(lab.title, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13.5)),
                ),
                TextButton.icon(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AiLabVisualsScreen(moduleId: module.id, labId: lab.id, title: lab.title))),
                  icon: const Icon(Icons.image_rounded, color: Colors.white70, size: 18),
                  label: const Text('Pictures', style: TextStyle(color: Colors.white70)),
                ),
                const SizedBox(width: 4),
                ElevatedButton.icon(
                  onPressed: () => _openInVsCode(context, lab),
                  icon: const Icon(Icons.play_arrow_rounded, size: 20),
                  label: const Text('Start in VS Code'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.amberAccent, foregroundColor: Colors.black87),
                ),
              ]),
            ),
          Wrap(spacing: 4, children: [
            // The desktop app runs the same experiment with nothing to set up: it is under this module there.
            TextButton.icon(
              onPressed: () => context.push('/download'),
              icon: const Icon(Icons.desktop_windows_rounded, color: Colors.white70, size: 18),
              label: const Text('No VS Code? Use the Altrobyte app', style: TextStyle(color: Colors.white70)),
            ),
            TextButton.icon(
              onPressed: () => context.push('/connect-vscode'),
              icon: const Icon(Icons.extension_rounded, color: Colors.white70, size: 18),
              label: const Text('First time? Connect VS Code', style: TextStyle(color: Colors.white70)),
            ),
          ]),
        ]),
      ),
    );
  }
}


