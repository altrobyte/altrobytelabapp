import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/add_fee_dialog.dart';
import '../../widgets/loading_widget.dart';

class StudentDetailScreen extends StatefulWidget {
  final int studentId;
  const StudentDetailScreen({super.key, required this.studentId});

  @override
  State<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _data = await ApiService.getStudentAnalytics(widget.studentId);
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _editStudent() async {
    final student = Map<String, dynamic>.from(_data!['student'] ?? {});
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => _EditStudentDialog(
        studentId: widget.studentId,
        name: (student['name'] ?? '').toString(),
        phone: (student['phone'] ?? '').toString(),
        email: (student['email'] ?? '').toString(),
        batchId: student['batch_id'] as int?,
        parentPhone: (student['parent_phone'] ?? '').toString(),
        instituteId: context.read<AuthProvider>().instituteId!,
      ),
    );
    if (result == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingWidget(message: 'Loading student...');
    if (_data == null) {
      return const EmptyState(
          icon: Icons.person_off, title: 'Student not found');
    }
    final student = Map<String, dynamic>.from(_data!['student'] ?? {});
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () =>
                  context.canPop() ? context.pop() : context.go('/students'),
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('Back to Students'),
              style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  padding: EdgeInsets.zero),
            ),
          ),
          const SizedBox(height: 8),
          _ProfileCard(student: student, data: _data!, onEdit: _editStudent),
          const SizedBox(height: 20),
          Card(
            child: Column(
              children: [
                TabBar(
                  controller: _tabs,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textSecondary,
                  indicatorColor: AppColors.accent,
                  tabs: const [
                    Tab(text: 'Test Performance'),
                    Tab(text: 'Attendance'),
                    Tab(text: 'Fee History'),
                  ],
                ),
                SizedBox(
                  height: 400,
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      _TestTab(data: _data!),
                      _AttendanceTab(data: _data!),
                      _FeeTab(
                        studentId: widget.studentId,
                        instituteId: context.read<AuthProvider>().instituteId,
                        studentName: (student['name'] ?? 'Student').toString(),
                        studentPhone: (student['phone'] ?? '').toString(),
                      ),
                    ],
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

class _ProfileCard extends StatelessWidget {
  final Map<String, dynamic> student;
  final Map<String, dynamic> data;
  final VoidCallback onEdit;
  const _ProfileCard({required this.student, required this.data, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final name = student['name'] ?? '';
    final initials = name.isNotEmpty
        ? name.trim().split(' ').take(2).map((p) => p[0]).join().toUpperCase()
        : '?';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
              child: Text(initials,
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 22,
                      fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(name,
                          style: GoogleFonts.poppins(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_rounded, size: 18),
                      color: AppColors.primary,
                      tooltip: 'Edit Student',
                      onPressed: onEdit,
                    ),
                  ]),
                  const SizedBox(height: 4),
                  Text(student['phone'] ?? '',
                      style:
                          GoogleFonts.inter(color: AppColors.textSecondary)),
                  if ((student['email'] ?? '').toString().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(student['email'],
                        style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12)),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      _chip('Avg Score: ${data['avg_test_score'] ?? 0}%',
                          AppColors.accent),
                      _chip('Attendance: ${data['attendance_rate'] ?? 0}%',
                          AppColors.success),
                      if (student['batch_name'] != null)
                        _chip(student['batch_name'], AppColors.primary),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: GoogleFonts.inter(
              fontSize: 12, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

class _TestTab extends StatelessWidget {
  final Map<String, dynamic> data;
  const _TestTab({required this.data});

  @override
  Widget build(BuildContext context) {
    final history = List<Map<String, dynamic>>.from(
        data['test_history']?.map((e) => Map<String, dynamic>.from(e)) ?? []);
    if (history.isEmpty) {
      return const EmptyState(
          icon: Icons.quiz_outlined, title: 'No tests taken yet');
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: history.length,
      separatorBuilder: (_, __) => const Divider(),
      itemBuilder: (_, i) {
        final t = history[i];
        final pct = (t['percentage'] ?? 0).toDouble();
        final color = pct >= 70
            ? AppColors.success
            : pct >= 40
                ? AppColors.warning
                : AppColors.error;
        return ListTile(
          title: Text(t['title'] ?? '',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          subtitle: Text('${t['subject'] ?? ''} • ${Fmt.date(t['completed_at']?.toString())}'),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('${t['score']}/${t['total']} (${pct.toStringAsFixed(0)}%)',
                style: GoogleFonts.inter(
                    color: color, fontWeight: FontWeight.bold)),
          ),
        );
      },
    );
  }
}

class _AttendanceTab extends StatelessWidget {
  final Map<String, dynamic> data;
  const _AttendanceTab({required this.data});

  @override
  Widget build(BuildContext context) {
    final total = data['total_classes'] ?? 0;
    final present = data['classes_present'] ?? 0;
    final rate = (data['attendance_rate'] ?? 0).toDouble();
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _stat('Total Classes', '$total', AppColors.primary),
              _stat('Present', '$present', AppColors.success),
              _stat('Absent', '${total - present}', AppColors.error),
              _stat('Rate', '${rate.toStringAsFixed(0)}%',
                  rate >= 75 ? AppColors.success : AppColors.warning),
            ],
          ),
          const SizedBox(height: 24),
          LinearProgressIndicator(
            value: rate / 100,
            backgroundColor: AppColors.error.withValues(alpha: 0.2),
            valueColor: AlwaysStoppedAnimation(
                rate >= 75 ? AppColors.success : AppColors.warning),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 8),
          Text(rate >= 75 ? 'Good attendance!' : 'Needs improvement',
              style: GoogleFonts.inter(
                  color: rate >= 75 ? AppColors.success : AppColors.warning)),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value,
            style: GoogleFonts.poppins(
                fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }
}

class _FeeTab extends StatefulWidget {
  final int studentId;
  final int? instituteId;
  final String studentName;
  final String studentPhone;
  const _FeeTab({
    required this.studentId,
    required this.instituteId,
    required this.studentName,
    required this.studentPhone,
  });

  @override
  State<_FeeTab> createState() => _FeeTabState();
}

class _FeeTabState extends State<_FeeTab> {
  List<dynamic> _fees = [];
  bool _loading = true;
  int? _busyFee;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ApiService.getStudentFees(widget.studentId);
      if (!mounted) return;
      setState(() {
        _fees = data;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  Future<void> _addFee() async {
    if (widget.instituteId == null) return;
    final added = await showDialog<bool>(
      context: context,
      builder: (_) => AddFeeDialog(
        instituteId: widget.instituteId!,
        fixedStudentId: widget.studentId,
        fixedStudentName: widget.studentName,
      ),
    );
    if (added == true) _load();
  }

  Future<void> _run(int feeId, Future<Map<String, dynamic>> Function() action,
      String okMsg) async {
    setState(() => _busyFee = feeId);
    try {
      await action();
      _snack(okMsg, AppColors.success);
      await _load();
    } catch (e) {
      _snack(e.toString(), AppColors.error);
    }
    if (mounted) setState(() => _busyFee = null);
  }

  // Admin collects via their own method (cash/UPI/etc.) and records it here.
  Future<void> _markPaid(int feeId) async {
    final mode = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('How was it paid?',
                  style: GoogleFonts.poppins(
                      fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            for (final m in const [
              ('Cash', Icons.payments_rounded),
              ('UPI', Icons.qr_code_rounded),
              ('Bank Transfer', Icons.account_balance_rounded),
              ('Card', Icons.credit_card_rounded),
              ('Cheque', Icons.receipt_long_rounded),
            ])
              ListTile(
                leading: Icon(m.$2, color: AppColors.primary),
                title: Text(m.$1),
                onTap: () => Navigator.pop(context, m.$1),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (mode == null) return;
    _run(feeId, () => ApiService.markFeePaid(feeId, {'payment_mode': mode}),
        'Marked paid ($mode)');
  }

  Future<void> _remind(int feeId) async {
    setState(() => _busyFee = feeId);
    try {
      await ApiService.sendFeeReminder(feeId);
      _snack('Reminder sent on WhatsApp', AppColors.success);
    } catch (e) {
      _snack(e.toString(), AppColors.error);
    }
    if (mounted) setState(() => _busyFee = null);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingWidget();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _addFee,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Fee'),
            ),
          ),
        ),
        Expanded(
          child: _fees.isEmpty
              ? const EmptyState(
                  icon: Icons.receipt_outlined, title: 'No fee records')
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  itemCount: _fees.length,
                  itemBuilder: (_, i) {
                    final f = Map<String, dynamic>.from(_fees[i]);
                    final paid = f['status'] == 'paid';
                    final feeId = f['id'] as int;
                    final busy = _busyFee == feeId;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                    paid
                                        ? Icons.check_circle
                                        : Icons.pending,
                                    color: paid
                                        ? AppColors.success
                                        : AppColors.error,
                                    size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('₹${f['amount']}',
                                          style: GoogleFonts.poppins(
                                              fontWeight: FontWeight.w600)),
                                      Text(
                                          'Due: ${Fmt.date(f['due_date']?.toString())}',
                                          style: GoogleFonts.inter(
                                              fontSize: 12,
                                              color:
                                                  AppColors.textSecondary)),
                                    ],
                                  ),
                                ),
                                Text(paid ? 'Paid' : 'Pending',
                                    style: TextStyle(
                                        color: paid
                                            ? AppColors.success
                                            : AppColors.error,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                            if (!paid) ...[
                              const SizedBox(height: 6),
                              busy
                                  ? const Padding(
                                      padding: EdgeInsets.all(6),
                                      child: SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2)),
                                    )
                                  : Row(
                                      children: [
                                        Expanded(
                                          child: SizedBox(
                                            height: 32,
                                            child: ElevatedButton(
                                              style:
                                                  ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    AppColors.success,
                                                padding: const EdgeInsets
                                                    .symmetric(horizontal: 6),
                                              ),
                                              onPressed: () =>
                                                  _markPaid(feeId),
                                              child: const Text('Mark Paid',
                                                  style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 12)),
                                            ),
                                          ),
                                        ),
                                        _act(Icons.send_rounded,
                                            AppColors.accent, 'Send Reminder',
                                            () => _remind(feeId)),
                                      ],
                                    ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _act(IconData icon, Color color, String tip, VoidCallback onTap) {
    return IconButton(
      icon: Icon(icon, color: color, size: 20),
      tooltip: tip,
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
    );
  }
}

class _EditStudentDialog extends StatefulWidget {
  final int studentId;
  final int instituteId;
  final String name;
  final String phone;
  final String email;
  final int? batchId;
  final String parentPhone;

  const _EditStudentDialog({
    required this.studentId,
    required this.instituteId,
    required this.name,
    required this.phone,
    required this.email,
    required this.batchId,
    required this.parentPhone,
  });

  @override
  State<_EditStudentDialog> createState() => _EditStudentDialogState();
}

class _EditStudentDialogState extends State<_EditStudentDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _parentPhoneCtrl;
  int? _batchId;
  List<Map<String, dynamic>> _batches = [];
  bool _saving = false;
  bool _loadingBatches = true;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.name);
    _phoneCtrl = TextEditingController(text: widget.phone);
    _emailCtrl = TextEditingController(text: widget.email);
    _parentPhoneCtrl = TextEditingController(text: widget.parentPhone);
    _batchId = widget.batchId;
    _loadBatches();
  }

  Future<void> _loadBatches() async {
    try {
      final raw = await ApiService.getBatches(widget.instituteId);
      _batches = List<Map<String, dynamic>>.from(raw.map((b) => Map<String, dynamic>.from(b)));
    } catch (_) {}
    if (mounted) setState(() => _loadingBatches = false);
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await ApiService.updateStudent(widget.studentId, {
        'name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'batch_id': _batchId,
        'parent_phone': _parentPhoneCtrl.text.trim(),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
        );
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _parentPhoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(children: [
        const Icon(Icons.edit_rounded, color: AppColors.primary, size: 20),
        const SizedBox(width: 8),
        Text('Edit Student', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      ]),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Name', prefixIcon: Icon(Icons.person_rounded)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Phone', prefixIcon: Icon(Icons.phone_rounded)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_rounded)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _parentPhoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Parent Phone', prefixIcon: Icon(Icons.family_restroom_rounded)),
          ),
          const SizedBox(height: 12),
          _loadingBatches
              ? const LinearProgressIndicator()
              : DropdownButtonFormField<int?>(
                  // ignore: deprecated_member_use
                  value: _batchId,
                  decoration: const InputDecoration(labelText: 'Batch', prefixIcon: Icon(Icons.class_rounded)),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('No Batch')),
                    ..._batches.map((b) => DropdownMenuItem(
                        value: b['id'] as int, child: Text(b['name'] ?? ''))),
                  ],
                  onChanged: (v) => setState(() => _batchId = v),
                ),
        ]),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(width: 14, height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.save_rounded, size: 16),
          label: const Text('Save'),
        ),
      ],
    );
  }
}
