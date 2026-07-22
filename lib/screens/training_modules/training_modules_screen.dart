import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../models/training_module_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/training_module_provider.dart';
import 'module_detail_screen.dart';

class TrainingModulesScreen extends StatefulWidget {
  const TrainingModulesScreen({super.key});

  @override
  State<TrainingModulesScreen> createState() => _TrainingModulesScreenState();
}

class _TrainingModulesScreenState extends State<TrainingModulesScreen> {
  int? _instituteId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final instituteId = context.read<AuthProvider>().instituteId;
      if (instituteId == null) return;
      _instituteId = instituteId;
      context.read<TrainingModuleProvider>().ensureModules(instituteId);
    });
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppColors.primary;
    }
  }

  IconData _parseIcon(String name) {
    switch (name) {
      case 'code':
        return Icons.code_rounded;
      case 'computer':
        return Icons.computer_rounded;
      case 'storage':
        return Icons.storage_rounded;
      case 'science':
        return Icons.science_rounded;
      case 'calculate':
        return Icons.calculate_rounded;
      case 'engineering':
        return Icons.engineering_rounded;
      case 'memory':
        return Icons.memory_rounded;
      case 'cloud':
        return Icons.cloud_rounded;
      case 'security':
        return Icons.security_rounded;
      case 'network':
        return Icons.lan_rounded;
      default:
        return Icons.school_rounded;
    }
  }

  void _showCreateDialog() {
    final titleCtl = TextEditingController();
    final descCtl = TextEditingController();
    String selectedIcon = 'school';
    String selectedColor = '#7C4DFF';

    final colors = [
      '#7C4DFF',
      '#00BFA5',
      '#FF6B35',
      '#E91E63',
      '#3F51B5',
      '#009688',
      '#FF5722',
      '#673AB7',
    ];
    final icons = [
      'school',
      'code',
      'computer',
      'storage',
      'science',
      'calculate',
      'engineering',
      'memory',
      'cloud',
      'security',
      'network',
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _parseColor(selectedColor).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_parseIcon(selectedIcon),
                    color: _parseColor(selectedColor), size: 22),
              ),
              const SizedBox(width: 12),
              Text('Create Training Module',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600, fontSize: 18)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleCtl,
                  decoration: InputDecoration(
                    labelText: 'Module Title',
                    hintText: 'e.g., Data Structures & Algorithms',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    prefixIcon: const Icon(Icons.title_rounded),
                  ),
                  style: GoogleFonts.inter(fontSize: 14),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: descCtl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Description',
                    hintText: 'Brief description of this module...',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  style: GoogleFonts.inter(fontSize: 14),
                ),
                const SizedBox(height: 18),
                Text('Icon',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: icons.map((icon) {
                    final active = icon == selectedIcon;
                    return GestureDetector(
                      onTap: () => setDialogState(() => selectedIcon = icon),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: active
                              ? _parseColor(selectedColor)
                                  .withValues(alpha: 0.2)
                              : Colors.grey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: active
                              ? Border.all(
                                  color: _parseColor(selectedColor), width: 2)
                              : null,
                        ),
                        child: Icon(_parseIcon(icon),
                            color: active
                                ? _parseColor(selectedColor)
                                : Colors.grey,
                            size: 20),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),
                Text('Color',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: colors.map((c) {
                    final active = c == selectedColor;
                    return GestureDetector(
                      onTap: () => setDialogState(() => selectedColor = c),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _parseColor(c),
                          shape: BoxShape.circle,
                          border: active
                              ? Border.all(color: Colors.white, width: 3)
                              : null,
                          boxShadow: active
                              ? [
                                  BoxShadow(
                                    color:
                                        _parseColor(c).withValues(alpha: 0.5),
                                    blurRadius: 8,
                                  )
                                ]
                              : null,
                        ),
                        child: active
                            ? const Icon(Icons.check_rounded,
                                color: Colors.white, size: 18)
                            : null,
                      ),
                    );
                  }).toList(),
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
                backgroundColor: _parseColor(selectedColor),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                if (titleCtl.text.trim().isEmpty || _instituteId == null) {
                  return;
                }
                final title = titleCtl.text.trim();
                final provider = context.read<TrainingModuleProvider>();
                Navigator.pop(ctx);
                final ok = await provider.createModule(
                  _instituteId!,
                  title: title,
                  description: descCtl.text.trim(),
                  iconName: selectedIcon,
                  color: selectedColor,
                );
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(ok
                      ? 'Module "$title" created'
                      : provider.error ?? 'Failed to create module'),
                  backgroundColor: ok ? AppColors.success : AppColors.error,
                ));
              },
              child: Text('Create',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteModule(TrainingModule module) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Delete Module?',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text(
            'Are you sure you want to delete "${module.title}"? This action cannot be undone.',
            style: GoogleFonts.inter(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: GoogleFonts.inter(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final provider = context.read<TrainingModuleProvider>();
              Navigator.pop(ctx);
              final ok = await provider.deleteModule(module.id);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(ok
                    ? '"${module.title}" deleted'
                    : provider.error ?? 'Failed to delete module'),
                backgroundColor: AppColors.error,
              ));
            },
            child: Text('Delete',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _togglePublish(TrainingModule module) async {
    final provider = context.read<TrainingModuleProvider>();
    final ok = await provider.togglePublish(module.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(!ok
          ? (provider.error ?? 'Failed to update module')
          : module.isPublished
              ? '"${module.title}" unpublished'
              : '"${module.title}" published'),
      backgroundColor: !ok
          ? AppColors.error
          : module.isPublished
              ? Colors.orange
              : AppColors.success,
    ));
  }

  void _openModuleDetail(TrainingModule module) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ModuleDetailScreen(module: module),
      ),
    );
    if (mounted && _instituteId != null) {
      context.read<TrainingModuleProvider>().refreshModules(_instituteId!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TrainingModuleProvider>();
    final modules = provider.modules;
    final loading = provider.isLoading && !provider.modulesLoaded;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF7C4DFF), Color(0xFF9C27B0)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.school_rounded,
                            color: Colors.white, size: 26),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Training Modules',
                                style: GoogleFonts.poppins(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary)),
                            Text(
                                '${modules.length} modules • ${modules.where((m) => m.isPublished).length} published',
                                style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 12),
                        ),
                        onPressed: _showCreateDialog,
                        icon: const Icon(Icons.add_rounded, size: 20),
                        label: Text('New Module',
                            style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600, fontSize: 13)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Loading
          if (loading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),

          // Empty state
          if (!loading && modules.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.school_rounded,
                          color: AppColors.primary, size: 40),
                    ),
                    const SizedBox(height: 16),
                    Text('No Training Modules Yet',
                        style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 8),
                    Text(
                        'Create your first module to organize notes,\ntests, and videos for your students.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                            fontSize: 14, color: AppColors.textSecondary)),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 14),
                      ),
                      onPressed: _showCreateDialog,
                      icon: const Icon(Icons.add_rounded),
                      label: Text('Create First Module',
                          style:
                              GoogleFonts.inter(fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            ),

          // Module cards
          if (!loading && modules.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _ModuleCard(
                    module: modules[index],
                    parseColor: _parseColor,
                    parseIcon: _parseIcon,
                    onTap: () => _openModuleDetail(modules[index]),
                    onDelete: () => _deleteModule(modules[index]),
                    onTogglePublish: () => _togglePublish(modules[index]),
                  ),
                  childCount: modules.length,
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  final TrainingModule module;
  final Color Function(String) parseColor;
  final IconData Function(String) parseIcon;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onTogglePublish;

  const _ModuleCard({
    required this.module,
    required this.parseColor,
    required this.parseIcon,
    required this.onTap,
    required this.onDelete,
    required this.onTogglePublish,
  });

  @override
  Widget build(BuildContext context) {
    final color = parseColor(module.color);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        elevation: 1,
        shadowColor: color.withValues(alpha: 0.15),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border(
                left: BorderSide(color: color, width: 4),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(parseIcon(module.iconName),
                          color: color, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(module.title,
                              style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary)),
                          if (module.description.isNotEmpty)
                            Text(module.description,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    // Publish badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: module.isPublished
                            ? AppColors.success.withValues(alpha: 0.1)
                            : Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        module.isPublished ? 'Published' : 'Draft',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: module.isPublished
                              ? AppColors.success
                              : Colors.orange,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Stats row
                Row(
                  children: [
                    _StatChip(Icons.topic_rounded,
                        '${module.topicCount} Topics', color),
                    const SizedBox(width: 12),
                    _StatChip(Icons.subtitles_rounded,
                        '${module.subtopicCount} Subtopics', color),
                    const SizedBox(width: 12),
                    _StatChip(Icons.library_books_rounded,
                        '${module.totalContentItems} Items', color),
                    const Spacer(),
                    // Actions
                    IconButton(
                      icon: Icon(
                        module.isPublished
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        size: 20,
                        color: AppColors.textSecondary,
                      ),
                      tooltip: module.isPublished ? 'Unpublish' : 'Publish',
                      onPressed: onTogglePublish,
                      visualDensity: VisualDensity.compact,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded,
                          size: 20, color: AppColors.error),
                      tooltip: 'Delete',
                      onPressed: onDelete,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _StatChip(this.icon, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color.withValues(alpha: 0.7)),
        const SizedBox(width: 4),
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }
}
