import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../models/batch_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/institute_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/custom_button_widget.dart';
import '../../widgets/loading_widget.dart';
import 'qr_display_screen.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  List<Batch> _batches = [];
  Batch? _selectedBatch;
  DateTime _date = DateTime.now();
  List<Map<String, dynamic>> _records = [];
  Map<int, String> _attendance = {};
  bool _loading = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadBatches();
  }

  Future<void> _loadBatches() async {
    final auth = context.read<AuthProvider>();
    if (auth.instituteId == null) return;
    await context.read<InstituteProvider>().ensureBatches(auth.instituteId!);
    setState(() {
      _batches = context.read<InstituteProvider>().batches;
      if (_batches.isNotEmpty) {
        _selectedBatch = _batches.first;
        _loadAttendance();
      }
    });
  }

  Future<void> _loadAttendance() async {
    if (_selectedBatch == null) return;
    setState(() => _loading = true);
    try {
      final data = await ApiService.getAttendance(
          _selectedBatch!.id, DateFormat('yyyy-MM-dd').format(_date));
      final records = List<Map<String, dynamic>>.from(
          data['records']?.map((r) => Map<String, dynamic>.from(r)) ?? []);
      setState(() {
        _records = records;
        _attendance = {
          for (final r in records)
            r['student_id'] as int: r['status'] as String
        };
      });
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (_selectedBatch == null) return;
    setState(() => _saving = true);
    try {
      await ApiService.markAttendance(_selectedBatch!.id, {
        'date': DateFormat('yyyy-MM-dd').format(_date),
        'records': _attendance.entries
            .map((e) => {'student_id': e.key, 'status': e.value})
            .toList(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Attendance saved!'),
            backgroundColor: AppColors.success),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.error),
      );
    }
    setState(() => _saving = false);
  }

  int get _presentCount =>
      _attendance.values.where((s) => s == 'present').length;

  @override
  Widget build(BuildContext context) {
    final total = _records.length;
    final present = _presentCount;
    final rate =
        total > 0 ? (present / total * 100).toStringAsFixed(0) : '0';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('Attendance',
                style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: _selectedBatch == null
                  ? null
                  : () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => QrDisplayScreen(
                          batchId: _selectedBatch!.id,
                          batchName: _selectedBatch!.name,
                        ),
                      )),
              icon: const Icon(Icons.qr_code_2_rounded, size: 18),
              label: const Text('Show QR'),
            ),
          ]),
          const SizedBox(height: 16),
          // Controls
          Row(children: [
            if (_batches.isNotEmpty)
              Expanded(
                child: DropdownButtonFormField<Batch>(
                  initialValue: _selectedBatch,
                  decoration: const InputDecoration(
                      labelText: 'Select Batch', isDense: true),
                  items: _batches
                      .map((b) =>
                          DropdownMenuItem(value: b, child: Text(b.name)))
                      .toList(),
                  onChanged: (v) {
                    setState(() => _selectedBatch = v);
                    _loadAttendance();
                  },
                ),
              ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2024),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  setState(() => _date = picked);
                  _loadAttendance();
                }
              },
              icon: const Icon(Icons.calendar_today_rounded, size: 16),
              label: Text(DateFormat('dd MMM yyyy').format(_date)),
            ),
          ]),
          const SizedBox(height: 16),
          // Stats — 4 equal chips
          Row(children: [
            Expanded(child: _statChip('Present', '$present', AppColors.success)),
            const SizedBox(width: 6),
            Expanded(child: _statChip('Absent', '${total - present}', AppColors.error)),
            const SizedBox(width: 6),
            Expanded(child: _statChip('Total', '$total', AppColors.primary)),
            const SizedBox(width: 6),
            Expanded(child: _statChip('Rate', '$rate%',
                double.parse(rate) >= 75 ? AppColors.success : AppColors.warning)),
          ]),
          const SizedBox(height: 8),
          // Bulk actions
          Row(children: [
            Expanded(child: OutlinedButton.icon(
              onPressed: () => setState(() {
                for (final r in _records) { _attendance[r['student_id'] as int] = 'present'; }
              }),
              icon: const Icon(Icons.check_circle_rounded, size: 15),
              label: const Text('All Present', style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.success, side: const BorderSide(color: AppColors.success), padding: const EdgeInsets.symmetric(vertical: 8)),
            )),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton.icon(
              onPressed: () => setState(() {
                for (final r in _records) { _attendance[r['student_id'] as int] = 'absent'; }
              }),
              icon: const Icon(Icons.cancel_rounded, size: 15),
              label: const Text('All Absent', style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.error, side: const BorderSide(color: AppColors.error), padding: const EdgeInsets.symmetric(vertical: 8)),
            )),
          ]),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const LoadingWidget(message: 'Loading students...')
                : _records.isEmpty
                    ? const EmptyState(
                        icon: Icons.people_outline,
                        title: 'No students in this batch')
                    : ListView.builder(
                        itemCount: _records.length,
                        itemBuilder: (_, i) {
                          final r = _records[i];
                          final sid = r['student_id'] as int;
                          final status =
                              _attendance[sid] ?? 'absent';
                          final present = status == 'present';
                          return Card(
                            margin:
                                const EdgeInsets.only(bottom: 6),
                            color: present
                                ? AppColors.success.withValues(alpha: 0.05)
                                : AppColors.error.withValues(alpha: 0.05),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: present
                                    ? AppColors.success.withValues(alpha: 0.2)
                                    : AppColors.error.withValues(alpha: 0.2),
                                child: Text(
                                  (r['name'] as String)
                                      .substring(0, 1)
                                      .toUpperCase(),
                                  style: TextStyle(
                                      color: present
                                          ? AppColors.success
                                          : AppColors.error,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              title: Text(r['name'] as String,
                                  style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600)),
                              subtitle: Text(r['phone'] as String? ?? ''),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _toggleBtn('P', sid, 'present',
                                      AppColors.success),
                                  const SizedBox(width: 8),
                                  _toggleBtn('A', sid, 'absent',
                                      AppColors.error),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
          const SizedBox(height: 12),
          GradientButton(
            label: 'Save Attendance',
            icon: Icons.save_rounded,
            onPressed: _save,
            loading: _saving,
          ),
        ],
      ),
    );
  }

  Widget _toggleBtn(
      String label, int sid, String status, Color color) {
    final active = _attendance[sid] == status;
    return InkWell(
      onTap: () => setState(() => _attendance[sid] = status),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? color : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label,
            style: TextStyle(
                color: active ? Colors.white : color,
                fontWeight: FontWeight.bold,
                fontSize: 13)),
      ),
    );
  }

  Widget _statChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(value,
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold, color: color, fontSize: 16)),
        Text(label, style: GoogleFonts.inter(fontSize: 10, color: color.withValues(alpha: 0.8))),
      ]),
    );
  }
}
