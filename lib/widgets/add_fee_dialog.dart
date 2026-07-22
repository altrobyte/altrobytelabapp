import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import '../services/api_service.dart';

/// Add-fee dialog. When [fixedStudentId] is given (e.g. opened from a student's
/// page) the student is pre-selected; otherwise a searchable dropdown is shown.
/// Returns `true` via Navigator.pop when a fee was added.
class AddFeeDialog extends StatefulWidget {
  final int instituteId;
  final int? fixedStudentId;
  final String? fixedStudentName;

  const AddFeeDialog({
    super.key,
    required this.instituteId,
    this.fixedStudentId,
    this.fixedStudentName,
  });

  @override
  State<AddFeeDialog> createState() => _AddFeeDialogState();
}

class _AddFeeDialogState extends State<AddFeeDialog> {
  final _amountCtrl = TextEditingController();
  List<Map<String, dynamic>> _students = [];
  int? _studentId;
  DateTime _due = DateTime.now();
  bool _loading = true;
  bool _saving = false;

  bool get _fixed => widget.fixedStudentId != null;

  @override
  void initState() {
    super.initState();
    if (_fixed) {
      _studentId = widget.fixedStudentId;
      _loading = false;
    } else {
      _loadStudents();
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStudents() async {
    try {
      final raw = await ApiService.getStudents(widget.instituteId);
      if (!mounted) return;
      setState(() {
        _students = raw.map((s) => Map<String, dynamic>.from(s)).toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  String get _dueStr =>
      '${_due.year}-${_due.month.toString().padLeft(2, '0')}-${_due.day.toString().padLeft(2, '0')}';

  Future<void> _save() async {
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (_studentId == null) {
      _snack('Please select a student');
      return;
    }
    if (amount <= 0) {
      _snack('Enter a valid amount');
      return;
    }
    setState(() => _saving = true);
    try {
      await ApiService.addFee(widget.instituteId, {
        'student_id': _studentId,
        'amount': amount,
        'due_date': _dueStr,
      });
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack(e.toString());
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppColors.error));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Add Fee',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      content: _loading
          ? const SizedBox(
              height: 80, child: Center(child: CircularProgressIndicator()))
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_fixed)
                  InputDecorator(
                    decoration: const InputDecoration(labelText: 'Student'),
                    child: Text(widget.fixedStudentName ?? 'Student',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                  )
                else
                  DropdownButtonFormField<int>(
                    // ignore: deprecated_member_use
                    value: _studentId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Student'),
                    items: _students
                        .map((s) => DropdownMenuItem<int>(
                              value: s['id'] as int,
                              child: Text(
                                  '${s['name']}${s['phone'] != null && s['phone'].toString().isNotEmpty ? ' (${s['phone']})' : ''}',
                                  overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _studentId = v),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: _amountCtrl,
                  keyboardType: TextInputType.number,
                  autofocus: _fixed,
                  decoration: const InputDecoration(
                      labelText: 'Amount (₹)', prefixText: '₹ '),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _due,
                      firstDate: DateTime(2024),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) setState(() => _due = picked);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Due Date'),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_dueStr),
                        const Icon(Icons.calendar_today_rounded, size: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
      actions: [
        TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _saving || _loading ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Add'),
        ),
      ],
    );
  }
}
