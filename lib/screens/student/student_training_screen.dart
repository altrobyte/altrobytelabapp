import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants/app_colors.dart';
import '../../models/training_module_model.dart';
import '../../providers/training_module_provider.dart';
import 'student_module_detail_screen.dart';

/// Student view — lists all published training modules with progress bars.
class StudentTrainingScreen extends StatefulWidget {
  const StudentTrainingScreen({super.key});

  @override
  State<StudentTrainingScreen> createState() => _StudentTrainingScreenState();
}

class _StudentTrainingScreenState extends State<StudentTrainingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadModules());
  }

  Future<void> _loadModules() async {
    final prefs = await SharedPreferences.getInstance();
    final instituteId = prefs.getInt('student_institute_id');
    if (!mounted) return;
    if (instituteId == null || instituteId == 0) return; // standalone student
    final provider = context.read<TrainingModuleProvider>();
    await provider.ensureModulesAsStudent(instituteId);
    if (!mounted) return;
    for (final m in provider.modules) {
      await provider.loadProgress(m.id);
    }
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
      default:
        return Icons.school_rounded;
    }
  }

  double _getProgress(TrainingModuleProvider provider, TrainingModule module) {
    final total = module.totalContentItems;
    if (total == 0) return 0;
    final completed = provider.getProgress(module.id)?.completedCount ?? 0;
    return completed / total;
  }

  void _openModule(TrainingModule module) async {
    final provider = context.read<TrainingModuleProvider>();
    final completedIds =
        provider.getProgress(module.id)?.completedItemIds ?? <int>{};
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StudentModuleDetailScreen(
          module: module,
          completedIds: completedIds,
        ),
      ),
    );
    // Reload progress after returning
    if (mounted) provider.loadProgress(module.id);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TrainingModuleProvider>();
    final modules = provider.modules;
    final loading = provider.isLoading && !provider.modulesLoaded;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.sidebar,
        elevation: 0,
        title: Text('Training Modules',
            style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            onPressed: _loadModules,
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : modules.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.school_rounded,
                          size: 56, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text('No Training Modules Available',
                          style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary)),
                      const SizedBox(height: 4),
                      Text('New modules will be added here soon.',
                          style: GoogleFonts.inter(
                              fontSize: 13, color: AppColors.textSecondary)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadModules,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final crossAxisCount = constraints.maxWidth >= 1100
                          ? 3
                          : constraints.maxWidth >= 700
                              ? 2
                              : 1;
                      return CustomScrollView(
                        slivers: [
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                            sliver: SliverToBoxAdapter(
                              child: Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [AppColors.primary, AppColors.primaryLight],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary
                                          .withValues(alpha: 0.3),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: const Icon(Icons.school_rounded,
                                          color: Colors.white, size: 26),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text('Your Learning Path',
                                              style: GoogleFonts.poppins(
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold)),
                                          Text(
                                              '${modules.length} modules available',
                                              style: GoogleFonts.inter(
                                                  color: Colors.white70,
                                                  fontSize: 13)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.all(16),
                            sliver: SliverGrid(
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                mainAxisExtent: 210,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final module = modules[index];
                                  return _ModuleCard(
                                    module: module,
                                    progress: _getProgress(provider, module),
                                    completedCount: provider
                                            .getProgress(module.id)
                                            ?.completedCount ??
                                        0,
                                    color: _parseColor(module.color),
                                    icon: _parseIcon(module.iconName),
                                    onTap: () => _openModule(module),
                                  );
                                },
                                childCount: modules.length,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  final TrainingModule module;
  final double progress;
  final int completedCount;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _ModuleCard({
    required this.module,
    required this.progress,
    required this.completedCount,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (progress * 100).toInt();
    final isFree = module.price <= 0;
    final hasStarted = completedCount > 0;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 1,
      shadowColor: color.withValues(alpha: 0.15),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border(left: BorderSide(color: color, width: 4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(icon, color: color, size: 21),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(module.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                  ),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: progress >= 1.0
                          ? AppColors.success.withValues(alpha: 0.12)
                          : color.withValues(alpha: 0.08),
                    ),
                    child: Center(
                      child: Text(
                        '$pct%',
                        style: GoogleFonts.poppins(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: progress >= 1.0 ? AppColors.success : color,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Price badge
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: isFree
                        ? AppColors.success.withValues(alpha: 0.12)
                        : AppColors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: isFree
                      ? Text('FREE',
                          style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.success))
                      : Row(mainAxisSize: MainAxisSize.min, children: [
                          if (module.originalPrice != null && module.originalPrice! > module.price) ...[
                            Text('₹${module.originalPrice!.toStringAsFixed(0)}',
                                style: GoogleFonts.inter(
                                    fontSize: 10.5, color: AppColors.textSecondary, decoration: TextDecoration.lineThrough)),
                            const SizedBox(width: 4),
                          ],
                          Text('₹${module.price.toStringAsFixed(0)}',
                              style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.accent)),
                        ]),
                ),
                const Spacer(),
                Text('${module.topicCount} topics',
                    style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.textSecondary)),
              ]),
              const SizedBox(height: 10),
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: color.withValues(alpha: 0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    progress >= 1.0 ? AppColors.success : color,
                  ),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$completedCount / ${module.totalContentItems} completed',
                style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.textSecondary),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 36,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: color,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                  ),
                  onPressed: onTap,
                  child: Text(
                    progress >= 1.0 ? 'Review' : hasStarted ? 'Continue' : (isFree ? 'Start' : 'Unlock'),
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
