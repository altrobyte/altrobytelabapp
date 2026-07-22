import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:data_table_2/data_table_2.dart';
import '../../constants/app_colors.dart';
import '../../models/student_model.dart';
import '../../models/batch_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/institute_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/loading_widget.dart';
import 'add_student_screen.dart';
import 'bulk_import_dialog.dart';

class StudentsScreen extends StatefulWidget {
  const StudentsScreen({super.key});

  @override
  State<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> {
  final _search = TextEditingController();
  int? _batchFilter;
  String? _feeFilter;
  bool _loading = false;
  List<Student> _students = [];
  List<Batch> _batches = [];

  @override
  void initState() {
    super.initState();
    // Show cached data instantly; only spin if we have nothing yet.
    final provider = context.read<InstituteProvider>();
    _students = provider.students;
    _batches = provider.batches;
    _loading = !provider.studentsLoaded;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load({bool force = false}) async {
    final auth = context.read<AuthProvider>();
    if (auth.instituteId == null) return;
    final provider = context.read<InstituteProvider>();
    if (force) setState(() => _loading = true);
    try {
      await Future.wait([
        provider.ensureStudents(auth.instituteId!, force: force),
        provider.ensureBatches(auth.instituteId!, force: force),
      ]);
      if (!mounted) return;
      setState(() {
        _students = provider.students;
        _batches = provider.batches;
      });
    } catch (_) {}
    if (!mounted) return;
    setState(() => _loading = false);
  }

  List<Student> get _filtered {
    var list = _students;
    if (_search.text.isNotEmpty) {
      final q = _search.text.toLowerCase();
      list = list
          .where((s) =>
              s.name.toLowerCase().contains(q) ||
              s.phone.contains(q))
          .toList();
    }
    if (_feeFilter != null) {
      list = list.where((s) => s.feeStatus == _feeFilter).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InstituteProvider>();
    final sub = provider.subscription;
    final used = sub?['students_used'] ?? 0;
    final max = sub?['max_students'] ?? 50;
    final unlimited = (max as int) >= 100000;
    final usageText = unlimited ? '$used students (unlimited on plan)' : '$used / $max students';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Usage meter + upgrade prompt (consistent with dashboard)
          if (sub != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Student usage: $usageText',
                      style: GoogleFonts.inter(fontSize: 13, color: Colors.white70),
                    ),
                  ),
                  if (!unlimited)
                    TextButton(
                      onPressed: () => context.push('/plans'),
                      child: const Text('Upgrade', style: TextStyle(fontSize: 12)),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          _TopBar(
            count: _filtered.length,
            search: _search,
            batches: _batches,
            batchFilter: _batchFilter,
            feeFilter: _feeFilter,
            onBatchChanged: (v) => setState(() => _batchFilter = v),
            onFeeChanged: (v) => setState(() => _feeFilter = v),
            onSearch: () => setState(() {}),
            onAdd: () async {
              final result = await showDialog<bool>(
                context: context,
                builder: (_) => AddStudentDialog(
                  batches: _batches,
                  onSaved: () => _load(force: true),
                ),
              );
              if (result == true) _load(force: true);
            },
            onImport: () async {
              final result = await showDialog<bool>(
                context: context,
                builder: (_) => BulkImportDialog(
                  onImported: () => _load(force: true),
                ),
              );
              if (result == true) _load(force: true);
            },
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _loading
                ? const LoadingWidget(message: 'Loading students...')
                : _filtered.isEmpty
                    ? const EmptyState(
                        icon: Icons.people_outline,
                        title: 'No students found',
                        subtitle: 'Add students to get started')
                    : _StudentsTable(
                        students: _filtered,
                        onRefresh: () => _load(force: true),
                      ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final int count;
  final TextEditingController search;
  final List<Batch> batches;
  final int? batchFilter;
  final String? feeFilter;
  final ValueChanged<int?> onBatchChanged;
  final ValueChanged<String?> onFeeChanged;
  final VoidCallback onSearch;
  final VoidCallback onAdd;
  final VoidCallback onImport;

  const _TopBar({
    required this.count,
    required this.search,
    required this.batches,
    required this.batchFilter,
    required this.feeFilter,
    required this.onBatchChanged,
    required this.onFeeChanged,
    required this.onSearch,
    required this.onAdd,
    required this.onImport,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Students ($count)',
                style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
            const Spacer(),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primaryLight),
              ),
              onPressed: onImport,
              icon: const Icon(Icons.upload_file_rounded, size: 18),
              label: const Text('Import CSV'),
            ),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white),
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Student'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: search,
          onChanged: (_) => onSearch(),
          decoration: const InputDecoration(
            hintText: 'Search by name or phone...',
            prefixIcon: Icon(Icons.search),
            isDense: true,
          ),
        ),
        if (!isMobile) ...[
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: DropdownButtonFormField<int?>(
              initialValue: batchFilter,
              decoration: const InputDecoration(labelText: 'Batch', isDense: true),
              items: [
                const DropdownMenuItem(value: null, child: Text('All Batches')),
                ...batches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))),
              ],
              onChanged: onBatchChanged,
            )),
            const SizedBox(width: 12),
            Expanded(child: DropdownButtonFormField<String?>(
              initialValue: feeFilter,
              decoration: const InputDecoration(labelText: 'Fee Status', isDense: true),
              items: const [
                DropdownMenuItem(value: null, child: Text('All')),
                DropdownMenuItem(value: 'paid', child: Text('Paid')),
                DropdownMenuItem(value: 'pending', child: Text('Pending')),
              ],
              onChanged: onFeeChanged,
            )),
          ]),
        ],
      ],
    );
  }
}

class _StudentsTable extends StatelessWidget {
  final List<Student> students;
  final VoidCallback onRefresh;

  const _StudentsTable({required this.students, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;
    if (isMobile) return _mobileList(context);
    return Card(
      child: DataTable2(
        columnSpacing: 12,
        horizontalMargin: 16,
        minWidth: 700,
        headingRowColor: WidgetStateProperty.all(AppColors.background),
        columns: const [
          DataColumn2(label: Text('Student'), size: ColumnSize.L),
          DataColumn2(label: Text('Phone')),
          DataColumn2(label: Text('Batch')),
          DataColumn2(label: Text('Fee Status')),
          DataColumn2(label: Text('Actions'), size: ColumnSize.S),
        ],
        rows: students.map((s) => _row(context, s)).toList(),
      ),
    );
  }

  Widget _mobileList(BuildContext context) {
    return ListView.separated(
      itemCount: students.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final s = students[i];
        return Card(
          child: InkWell(
            onTap: () => context.go('/students/${s.id}'),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                  child: Text(s.initials,
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.name,
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600, fontSize: 14),
                          overflow: TextOverflow.ellipsis),
                      if (s.phone.isNotEmpty)
                        Text(s.phone,
                            style: GoogleFonts.inter(
                                color: AppColors.textSecondary, fontSize: 12)),
                      if (s.batchName != null)
                        Text(s.batchName!,
                            style: GoogleFonts.inter(
                                color: AppColors.primaryLight, fontSize: 11)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _FeeBadge(status: s.feeStatus),
                const SizedBox(width: 4),
                if (context.read<AuthProvider>().canDelete)
                  IconButton(
                    icon: const Icon(Icons.delete_rounded, size: 18),
                    color: AppColors.error,
                    onPressed: () => _confirmDelete(context, s, onRefresh),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ]),
            ),
          ),
        );
      },
    );
  }

  DataRow2 _row(BuildContext context, Student s) {
    return DataRow2(
      onTap: () => context.go('/students/${s.id}'),
      cells: [
        DataCell(Row(children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primary.withValues(alpha: 0.15),
            child: Text(s.initials,
                style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(s.name,
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis),
          ),
        ])),
        DataCell(Text(s.phone.isEmpty ? '-' : s.phone)),
        DataCell(
          s.batchName != null
              ? Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(s.batchName!,
                      style: GoogleFonts.inter(
                          fontSize: 11, color: AppColors.primaryLight)),
                )
              : const Text('-'),
        ),
        DataCell(_FeeBadge(status: s.feeStatus)),
        DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
            icon: const Icon(Icons.visibility_rounded, size: 18),
            onPressed: () => context.go('/students/${s.id}'),
            tooltip: 'View',
            color: AppColors.primary,
          ),
          if (context.read<AuthProvider>().canDelete)
            IconButton(
              icon: const Icon(Icons.delete_rounded, size: 18),
              color: AppColors.error,
              tooltip: 'Delete',
              onPressed: () => _confirmDelete(context, s, onRefresh),
            ),
        ])),
      ],
    );
  }

  void _confirmDelete(BuildContext ctx, Student s, VoidCallback onRefresh) {
    showDialog<bool>(
      context: ctx,
      useRootNavigator: true,
      builder: (dCtx) => AlertDialog(
        title: const Text('Delete Student'),
        content: Text('Delete ${s.name}? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dCtx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(dCtx).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ).then((confirmed) async {
      if (confirmed != true) return;
      try {
        await ApiService.deleteStudent(s.id);
        onRefresh();
      } catch (e) {
        if (ctx.mounted) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
          );
        }
      }
    });
  }
}

class _FeeBadge extends StatelessWidget {
  final String status;
  const _FeeBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = status == 'paid'
        ? AppColors.success
        : status == 'partial'
            ? AppColors.warning
            : AppColors.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        status[0].toUpperCase() + status.substring(1),
        style: GoogleFonts.inter(
            fontSize: 11, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
