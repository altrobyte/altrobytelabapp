import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../models/experiment_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import 'experiment_edit_screen.dart';

/// Admin screen: list, create, publish/unpublish, delete experiments.
class ExperimentsScreen extends StatefulWidget {
  const ExperimentsScreen({super.key});

  @override
  State<ExperimentsScreen> createState() => _ExperimentsScreenState();
}

class _ExperimentsScreenState extends State<ExperimentsScreen> {
  int? _instituteId;
  List<Experiment> _experiments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final instituteId = context.read<AuthProvider>().instituteId;
    if (instituteId == null) return;
    _instituteId = instituteId;
    setState(() => _loading = true);
    try {
      final raw = await ApiService.getExperimentsAdmin(instituteId);
      setState(() {
        _experiments = raw.map((e) => Experiment.fromJson(e)).toList();
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppColors.primary;
    }
  }

  IconData _toolIcon(String toolType) {
    switch (toolType) {
      case 'mqtt':
        return Icons.developer_board_rounded;
      case 'websocket':
        return Icons.swap_horiz_rounded;
      case 'ble':
        return Icons.bluetooth_rounded;
      default:
        return Icons.science_rounded;
    }
  }

  void _showCreateDialog() {
    final titleCtl = TextEditingController();
    final objectiveCtl = TextEditingController();
    String toolType = 'mqtt';
    String verificationType = 'manual';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('New Experiment',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 18)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleCtl,
                  decoration: InputDecoration(
                    labelText: 'Title',
                    hintText: 'e.g., Publish sensor data over MQTT',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  style: GoogleFonts.inter(fontSize: 14),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: objectiveCtl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Objective',
                    hintText: 'What will the student learn/do?',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  style: GoogleFonts.inter(fontSize: 14),
                ),
                const SizedBox(height: 18),
                Text('Tool',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ('mqtt', 'MQTT'),
                    ('websocket', 'WebSocket'),
                    ('ble', 'Bluetooth (BLE)'),
                  ].map((t) {
                    final active = toolType == t.$1;
                    return ChoiceChip(
                      label: Text(t.$2, style: GoogleFonts.inter(fontSize: 12)),
                      selected: active,
                      onSelected: (_) => setDialogState(() => toolType = t.$1),
                      selectedColor: AppColors.primary.withValues(alpha: 0.2),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),
                Text('Result verification',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ('manual', 'Manual (student submits)'),
                    ('auto', 'Auto (rule match)'),
                  ].map((t) {
                    final active = verificationType == t.$1;
                    return ChoiceChip(
                      label: Text(t.$2, style: GoogleFonts.inter(fontSize: 12)),
                      selected: active,
                      onSelected: (_) => setDialogState(() => verificationType = t.$1),
                      selectedColor: AppColors.primary.withValues(alpha: 0.2),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                if (titleCtl.text.trim().isEmpty || _instituteId == null) return;
                Navigator.pop(ctx);
                try {
                  await ApiService.createExperiment(_instituteId!, {
                    'title': titleCtl.text.trim(),
                    'objective': objectiveCtl.text.trim(),
                    'tool_type': toolType,
                    'verification_type': verificationType,
                  });
                  if (mounted) _load();
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Failed: $e'), backgroundColor: AppColors.error));
                }
              },
              child: Text('Create', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openEdit(Experiment exp) async {
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => ExperimentEditScreen(experiment: exp)));
    if (mounted) _load();
  }

  Future<void> _delete(Experiment exp) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Delete Experiment?', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text('Delete "${exp.title}"? This cannot be undone.',
            style: GoogleFonts.inter(fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ApiService.deleteExperiment(exp.id);
      if (mounted) _load();
    }
  }

  Future<void> _togglePublish(Experiment exp) async {
    await ApiService.updateExperiment(exp.id, {'is_published': !exp.isPublished});
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [AppColors.success, AppColors.primary]),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.science_rounded, color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Experiments',
                            style: GoogleFonts.poppins(
                                fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        Text(
                            '${_experiments.length} experiments • ${_experiments.where((e) => e.isPublished).length} published',
                            style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    ),
                    onPressed: _showCreateDialog,
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: Text('New Experiment',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                ],
              ),
            ),
          ),
          if (_loading)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator())),
          if (!_loading && _experiments.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.science_rounded, size: 48, color: Colors.grey[300]),
                    const SizedBox(height: 12),
                    Text('No experiments yet',
                        style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          if (!_loading && _experiments.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final exp = _experiments[index];
                    final color = _parseColor(exp.color);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        elevation: 1,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _openEdit(exp),
                          child: Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border(left: BorderSide(color: color, width: 4)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(_toolIcon(exp.toolType), color: color, size: 24),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(exp.title,
                                          style: GoogleFonts.poppins(
                                              fontSize: 15, fontWeight: FontWeight.w600)),
                                      Text(
                                          '${exp.toolType.toUpperCase()} • ${exp.verificationType} verification',
                                          style: GoogleFonts.inter(
                                              fontSize: 12, color: AppColors.textSecondary)),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: exp.isPublished
                                        ? AppColors.success.withValues(alpha: 0.1)
                                        : Colors.orange.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(exp.isPublished ? 'Published' : 'Draft',
                                      style: GoogleFonts.inter(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: exp.isPublished ? AppColors.success : Colors.orange)),
                                ),
                                IconButton(
                                  icon: Icon(
                                      exp.isPublished ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                      size: 20),
                                  onPressed: () => _togglePublish(exp),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded,
                                      size: 20, color: AppColors.error),
                                  onPressed: () => _delete(exp),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: _experiments.length,
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }
}
