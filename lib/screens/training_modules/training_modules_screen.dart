import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants/api_constants.dart';
import '../../constants/app_colors.dart';
import '../../models/training_module_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/training_module_provider.dart';
import '../../services/api_service.dart';
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
      // A student has no educator institute id, and gating on it meant the
      // tab returned early and stayed empty while modules were published.
      final instituteId = context.read<AuthProvider>().instituteId;
      _instituteId = instituteId;
      if (instituteId != null) {
        context.read<TrainingModuleProvider>().ensureModules(instituteId);
      } else {
        context.read<TrainingModuleProvider>().ensureModulesForStudent();
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

  void _showCreateDialog({TrainingModule? existing}) {
    final titleCtl = TextEditingController(text: existing?.title ?? '');
    final descCtl = TextEditingController(text: existing?.description ?? '');
    final priceCtl = TextEditingController(text: '${existing?.price ?? 0}');
    final taxCtl = TextEditingController(text: '${existing?.taxPercent ?? 0}');
    final originalPriceCtl = TextEditingController(text: '${existing?.originalPrice ?? ''}');
    bool isPaid = (existing?.price ?? 0) > 0;
    String selectedIcon = existing?.iconName ?? 'school';
    String selectedColor = existing?.color ?? '#7C4DFF';

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
              Text(existing == null ? 'Create Training Module' : 'Edit Training Module',
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
                const SizedBox(height: 18),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Paid course'),
                  subtitle: const Text('Off = free access. On = students pay before content unlocks.', style: TextStyle(fontSize: 12)),
                  value: isPaid,
                  onChanged: (v) => setDialogState(() => isPaid = v),
                  activeColor: _parseColor(selectedColor),
                ),
                if (isPaid) ...[
                  const SizedBox(height: 6),
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: priceCtl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Price (₹)',
                          prefixText: '₹ ',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: taxCtl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Tax %',
                          suffixText: '%',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  Text('Leave tax at 0 if not applicable.',
                      style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: originalPriceCtl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Original price (optional)',
                      prefixText: '₹ ',
                      helperText: 'Shown crossed-out next to the real price. Leave blank to hide.',
                      helperMaxLines: 2,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
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
                final price = isPaid ? (double.tryParse(priceCtl.text.trim()) ?? 0) : 0.0;
                final tax = isPaid ? (double.tryParse(taxCtl.text.trim()) ?? 0) : 0.0;
                final originalPriceText = originalPriceCtl.text.trim();
                final originalPrice = isPaid && originalPriceText.isNotEmpty ? double.tryParse(originalPriceText) : null;
                final clearOriginalPrice = !isPaid || originalPriceText.isEmpty;
                final provider = context.read<TrainingModuleProvider>();
                Navigator.pop(ctx);
                final ok = existing == null
                    ? await provider.createModule(
                        _instituteId!,
                        title: title,
                        description: descCtl.text.trim(),
                        iconName: selectedIcon,
                        color: selectedColor,
                        price: price,
                        taxPercent: tax,
                        originalPrice: originalPrice,
                      )
                    : await provider.updateModule(
                        existing.id,
                        title: title,
                        description: descCtl.text.trim(),
                        iconName: selectedIcon,
                        color: selectedColor,
                        price: price,
                        taxPercent: tax,
                        originalPrice: originalPrice,
                        clearOriginalPrice: clearOriginalPrice,
                      );
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(ok
                      ? 'Module "$title" ${existing == null ? 'created' : 'updated'}'
                      : provider.error ?? 'Failed to save module'),
                  backgroundColor: ok ? AppColors.success : AppColors.error,
                ));
              },
              child: Text(existing == null ? 'Create' : 'Save',
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

  Future<void> _showEnrollments(TrainingModule module) async {
    List<Map<String, dynamic>> enrollments = [];
    String? error;
    try {
      enrollments = List<Map<String, dynamic>>.from(
          (await ApiService.getModuleEnrollments(module.id)).map((e) => Map<String, dynamic>.from(e as Map)));
    } catch (e) {
      error = e.toString();
    }
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => DraggableScrollableSheet(
          initialChildSize: 0.7,
          expand: false,
          builder: (ctx, scrollCtrl) => Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text('Enrollments — ${module.title} (${enrollments.length})',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
                ),
                TextButton.icon(
                  onPressed: () => _exportEnrollmentsCsv(module.id),
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: const Text('Export CSV'),
                ),
              ]),
              const Divider(),
              Expanded(
                child: error != null
                    ? Center(child: Text(error, style: GoogleFonts.inter(color: AppColors.error)))
                    : enrollments.isEmpty
                        ? Center(child: Text('No enrollments yet', style: GoogleFonts.inter(color: AppColors.textSecondary)))
                        : ListView.separated(
                            controller: scrollCtrl,
                            itemCount: enrollments.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, i) => _EnrollmentCard(
                              enrollment: enrollments[i],
                              onMarkPaid: enrollments[i]['status'] == 'paid' ? null : () async {
                                final confirmed = await showDialog<bool>(
                                  context: ctx,
                                  builder: (dCtx) => AlertDialog(
                                    title: const Text('Mark as paid?'),
                                    content: Text(
                                        'Only do this after you\'ve actually collected payment from ${enrollments[i]['name'] ?? 'this person'} directly (UPI/cash).'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Cancel')),
                                      FilledButton(
                                          onPressed: () => Navigator.pop(dCtx, true),
                                          style: FilledButton.styleFrom(backgroundColor: AppColors.success),
                                          child: const Text('Mark Paid')),
                                    ],
                                  ),
                                );
                                if (confirmed != true) return;
                                final updated = await ApiService.markModuleEnrollmentPaid(module.id, enrollments[i]['id'] as int);
                                setSheetState(() => enrollments[i] = updated);
                              },
                              onDelete: () async {
                                final confirmed = await showDialog<bool>(
                                  context: ctx,
                                  builder: (dCtx) => AlertDialog(
                                    title: const Text('Remove this enrollment?'),
                                    content: Text(
                                        'This deletes ${enrollments[i]['name'] ?? 'this entry'} permanently — use this for stuck/test enrollments, not real students.'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Cancel')),
                                      FilledButton(
                                          onPressed: () => Navigator.pop(dCtx, true),
                                          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
                                          child: const Text('Delete')),
                                    ],
                                  ),
                                );
                                if (confirmed != true) return;
                                await ApiService.deleteModuleEnrollment(module.id, enrollments[i]['id'] as int);
                                setSheetState(() => enrollments.removeAt(i));
                              },
                            ),
                          ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Future<void> _exportEnrollmentsCsv(int moduleId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final res = await http.get(
      Uri.parse(ApiConstants.moduleEnrollmentsExport(moduleId)),
      headers: {if (token != null) 'Authorization': 'Bearer $token'},
    );
    if (res.statusCode != 200) return;
    final blob = html.Blob([utf8.encode(res.body)], 'text/csv');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', 'module_${moduleId}_enrollments.csv')
      ..click();
    html.Url.revokeObjectUrl(url);
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
                            colors: [AppColors.primary, AppColors.primaryLight],
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
                    onEdit: () => _showCreateDialog(existing: modules[index]),
                    onEnrollments: () => _showEnrollments(modules[index]),
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
  final VoidCallback onEdit;
  final VoidCallback onEnrollments;

  const _ModuleCard({
    required this.module,
    required this.parseColor,
    required this.parseIcon,
    required this.onTap,
    required this.onDelete,
    required this.onTogglePublish,
    required this.onEdit,
    required this.onEnrollments,
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
                    // Price badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: module.price > 0
                            ? AppColors.accent.withValues(alpha: 0.1)
                            : AppColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        module.price > 0 ? '₹${module.price.toStringAsFixed(0)}' : 'FREE',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: module.price > 0 ? AppColors.accent : AppColors.success,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
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
                      icon: const Icon(Icons.people_outline_rounded, size: 20, color: AppColors.textSecondary),
                      tooltip: 'Enrollments',
                      onPressed: onEnrollments,
                      visualDensity: VisualDensity.compact,
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20, color: AppColors.textSecondary),
                      tooltip: 'Edit',
                      onPressed: onEdit,
                      visualDensity: VisualDensity.compact,
                    ),
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

class _EnrollmentCard extends StatelessWidget {
  final Map<String, dynamic> enrollment;
  final VoidCallback? onMarkPaid;
  final VoidCallback? onDelete;
  const _EnrollmentCard({required this.enrollment, this.onMarkPaid, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final e = enrollment;
    final status = (e['status'] ?? '').toString();
    final statusColor = switch (status) {
      'paid' => AppColors.success,
      'pending' => AppColors.warning,
      _ => AppColors.textSecondary,
    };
    final totalAmount = (e['total_amount'] as num?) ?? 0;
    String? createdAt;
    try {
      final raw = e['created_at'];
      if (raw != null) createdAt = DateFormat('d MMM yyyy, h:mm a').format(DateTime.parse(raw.toString()));
    } catch (_) {}

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text((e['name'] ?? '').toString(),
                style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14.5)),
          ),
          if (status.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
              child: Text(status.toUpperCase(),
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: statusColor, letterSpacing: 0.3)),
            ),
          if (onMarkPaid != null)
            IconButton(
              icon: const Icon(Icons.check_circle_outline_rounded, size: 19, color: AppColors.success),
              tooltip: 'Mark as paid (manual UPI/cash)',
              onPressed: onMarkPaid,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.only(left: 8),
            ),
          if (onDelete != null)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 19, color: AppColors.error),
              tooltip: 'Delete enrollment',
              onPressed: onDelete,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.only(left: 8),
            ),
        ]),
        const SizedBox(height: 10),
        if ((e['phone'] ?? '').toString().isNotEmpty)
          _EnrollmentRow(icon: Icons.phone_rounded, label: (e['phone']).toString()),
        if ((e['email'] ?? '').toString().isNotEmpty)
          _EnrollmentRow(icon: Icons.email_rounded, label: (e['email']).toString()),
        if (totalAmount > 0)
          _EnrollmentRow(icon: Icons.payments_rounded, label: '₹$totalAmount paid'),
        if ((e['receipt_number'] ?? '').toString().isNotEmpty)
          _EnrollmentRow(icon: Icons.receipt_long_rounded, label: 'Receipt ${e['receipt_number']}'),
        if ((e['payment_proof_url'] ?? '').toString().isNotEmpty)
          InkWell(
            onTap: () => html.window.open((e['payment_proof_url'] as String), '_blank'),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(children: [
                const Icon(Icons.image_rounded, size: 14, color: AppColors.accent),
                const SizedBox(width: 6),
                Text('View payment screenshot',
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.accent, fontWeight: FontWeight.w600, decoration: TextDecoration.underline)),
              ]),
            ),
          ),
        if (createdAt != null)
          _EnrollmentRow(icon: Icons.event_available_rounded, label: 'Enrolled $createdAt'),
      ]),
    );
  }
}

class _EnrollmentRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _EnrollmentRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textPrimary))),
      ]),
    );
  }
}
