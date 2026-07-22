import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../models/batch_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/institute_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/loading_widget.dart';

class BatchesScreen extends StatefulWidget {
  const BatchesScreen({super.key});

  @override
  State<BatchesScreen> createState() => _BatchesScreenState();
}

class _BatchesScreenState extends State<BatchesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load({bool force = false}) async {
    final auth = context.read<AuthProvider>();
    if (auth.instituteId != null) {
      await context.read<InstituteProvider>().ensureBatches(auth.instituteId!, force: force);
    }
  }

  void _showForm({Batch? batch}) {
    final nameCtrl = TextEditingController(text: batch?.name ?? '');
    final subjectCtrl = TextEditingController(text: batch?.subject ?? '');
    final scheduleCtrl = TextEditingController(text: batch?.schedule ?? '');
    final teacherCtrl = TextEditingController(text: batch?.teacherName ?? '');
    final formKey = GlobalKey<FormState>();
    bool saving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(batch == null ? 'Create Batch' : 'Edit Batch',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Batch Name *'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: subjectCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Subject', hintText: 'e.g. Mathematics'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: scheduleCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Schedule', hintText: 'e.g. Mon/Wed 6-7 PM'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: teacherCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Teacher Name'),
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setS(() => saving = true);
                      final auth = context.read<AuthProvider>();
                      final body = {
                        'name': nameCtrl.text.trim(),
                        'subject': subjectCtrl.text.trim(),
                        'schedule': scheduleCtrl.text.trim(),
                        'teacher_name': teacherCtrl.text.trim(),
                      };
                      try {
                        if (batch == null) {
                          await ApiService.createBatch(
                              auth.instituteId!, body);
                        } else {
                          await ApiService.updateBatch(batch.id, body);
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                        _load(force: true);
                      } catch (e) {
                        setS(() => saving = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                              content: Text(e.toString()),
                              backgroundColor: AppColors.error));
                        }
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(batch == null ? 'Create' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _delete(Batch batch) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Batch?'),
        content: Text(
            'Delete "${batch.name}"? Students in this batch will be unassigned.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiService.deleteBatch(batch.id);
      _load(force: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InstituteProvider>();
    final batches = provider.batches;
    final loading = provider.isLoading;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => _load(force: true),
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(24),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Batches',
                              style: GoogleFonts.poppins(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary)),
                          Text('Manage your class batches',
                              style: GoogleFonts.inter(
                                  color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: () => _showForm(),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('New Batch'),
                      style: FilledButton.styleFrom(
                          backgroundColor: AppColors.accent),
                    ),
                  ],
                ),
              ),
            ),
            if (loading)
              const SliverFillRemaining(
                  child: Center(child: LoadingWidget()))
            else if (batches.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.groups_rounded,
                          size: 64,
                          color: AppColors.textSecondary.withValues(alpha: 0.3)),
                      const SizedBox(height: 16),
                      Text('No batches yet',
                          style: GoogleFonts.poppins(
                              fontSize: 18,
                              color: AppColors.textSecondary)),
                      const SizedBox(height: 8),
                      Text('Create your first batch to get started',
                          style: GoogleFonts.inter(
                              color: AppColors.textSecondary)),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: () => _showForm(),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Create Batch'),
                        style: FilledButton.styleFrom(
                            backgroundColor: AppColors.accent),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _BatchCard(
                      batch: batches[i],
                      onEdit: () => _showForm(batch: batches[i]),
                      onDelete: () => _delete(batches[i]),
                    ),
                    childCount: batches.length,
                  ),
                  gridDelegate:
                      const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 340,
                    childAspectRatio: 1.6,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                  ),
                ),
              ),
            const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
          ],
        ),
      ),
    );
  }
}

class _BatchCard extends StatelessWidget {
  final Batch batch;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _BatchCard(
      {required this.batch, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(batch.name,
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: AppColors.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              PopupMenuButton(
                icon: const Icon(Icons.more_vert_rounded,
                    size: 18, color: AppColors.textSecondary),
                itemBuilder: (_) => [
                  const PopupMenuItem(
                      value: 'edit',
                      child: Row(children: [
                        Icon(Icons.edit_rounded, size: 16),
                        SizedBox(width: 8),
                        Text('Edit')
                      ])),
                  const PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [
                        Icon(Icons.delete_rounded,
                            size: 16, color: AppColors.error),
                        SizedBox(width: 8),
                        Text('Delete',
                            style: TextStyle(color: AppColors.error))
                      ])),
                ],
                onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
              ),
            ]),
            if (batch.subject.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(batch.subject,
                  style: GoogleFonts.inter(
                      color: AppColors.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w500)),
            ],
            const Spacer(),
            Row(children: [
              _chip(Icons.people_rounded,
                  '${batch.studentCount ?? 0} students'),
              const SizedBox(width: 8),
              if (batch.schedule.isNotEmpty)
                Expanded(
                  child: _chip(Icons.schedule_rounded, batch.schedule,
                      expand: true),
                ),
            ]),
            if (batch.teacherName.isNotEmpty) ...[
              const SizedBox(height: 6),
              _chip(Icons.person_rounded, batch.teacherName),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label, {bool expand = false}) {
    final w = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        expand
            ? Flexible(
                child: Text(label,
                    style: GoogleFonts.inter(
                        fontSize: 11, color: AppColors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis))
            : Text(label,
                style: GoogleFonts.inter(
                    fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
    return w;
  }
}
