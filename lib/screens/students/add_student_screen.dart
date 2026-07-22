import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../models/batch_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../utils/validators.dart';
import '../../widgets/custom_button_widget.dart';

class AddStudentDialog extends StatefulWidget {
  final List<Batch> batches;
  final VoidCallback? onSaved;

  const AddStudentDialog({super.key, required this.batches, this.onSaved});

  @override
  State<AddStudentDialog> createState() => _AddStudentDialogState();
}

class _AddStudentDialogState extends State<AddStudentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _parentPhone = TextEditingController();
  int? _batchId;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _parentPhone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final auth = context.read<AuthProvider>();
      await ApiService.addStudent(auth.instituteId!, {
        'name': _name.text.trim(),
        'phone': _phone.text.trim(),
        'email': _email.text.trim(),
        'batch_id': _batchId,
        'parent_phone': _parentPhone.text.trim(),
      });
      if (!mounted) return;
      Navigator.pop(context, true);
      widget.onSaved?.call();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
      );
    }
    setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('Add New Student',
                          style: GoogleFonts.poppins(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'Full Name *'),
                    validator: (v) => Validators.required(v, 'Name'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phone,
                    decoration: const InputDecoration(labelText: 'Phone Number'),
                    keyboardType: TextInputType.phone,
                    validator: Validators.phone,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _email,
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: Validators.email,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    // ignore: deprecated_member_use
                    value: _batchId,
                    decoration: const InputDecoration(labelText: 'Batch'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('No Batch')),
                      ...widget.batches.map((b) =>
                          DropdownMenuItem(value: b.id, child: Text(b.name))),
                    ],
                    onChanged: (v) => setState(() => _batchId = v),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _parentPhone,
                    decoration:
                        const InputDecoration(labelText: 'Parent Phone'),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 24),
                  GradientButton(
                    label: 'Save Student',
                    icon: Icons.save_rounded,
                    onPressed: _save,
                    loading: _saving,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
