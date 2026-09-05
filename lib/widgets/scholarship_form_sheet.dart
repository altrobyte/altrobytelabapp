import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_colors.dart';
import '../services/api_service.dart';

/// The details we take before somebody sits the scholarship test.
///
/// Asked here rather than after the score, for two reasons. A scholarship is
/// money, and money needs a name and a college somebody can ring — details
/// taken after a result are details filled in a hurry, or not at all. And a
/// form standing between a candidate and the number they just earned is the
/// most abandoned form there is.
///
/// Returns true when the details were saved.
Future<bool> showScholarshipFormSheet(BuildContext context,
    {Map<String, dynamic>? existing}) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _FormSheet(existing: existing),
  );
  return ok == true;
}

class _FormSheet extends StatefulWidget {
  final Map<String, dynamic>? existing;
  const _FormSheet({this.existing});

  @override
  State<_FormSheet> createState() => _FormSheetState();
}

class _FormSheetState extends State<_FormSheet> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _college = TextEditingController();
  final _branch = TextEditingController();
  final _year = TextEditingController();
  final _city = TextEditingController();
  String _occupation = 'student';
  bool _busy = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _name.text = '${e['name'] ?? ''}';
      _phone.text = '${e['phone'] ?? ''}';
      _email.text = '${e['email'] ?? ''}';
      _college.text = '${e['college'] ?? ''}';
      _branch.text = '${e['branch'] ?? ''}';
      _year.text = '${e['year_of_study'] ?? ''}';
      _city.text = '${e['city'] ?? ''}';
      _occupation = '${e['occupation'] ?? 'student'}';
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _email, _college, _branch, _year, _city]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _working => _occupation == 'working';

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      await ApiService.registerForScholarship({
        'name': _name.text.trim(),
        'phone': _phone.text.trim(),
        'email': _email.text.trim(),
        'occupation': _occupation,
        'college': _college.text.trim(),
        'branch': _branch.text.trim(),
        'year_of_study': _year.text.trim(),
        'city': _city.text.trim(),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e is ApiException ? e.message : '$e';
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(22, 10, 22, 26),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(2)),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Your details',
                  style: GoogleFonts.poppins(
                      fontSize: 18, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                  'We verify these before a scholarship is honoured, so please '
                  'give the real ones. Two minutes now, once.',
                  style: GoogleFonts.inter(
                      fontSize: 12.5,
                      height: 1.45,
                      color: AppColors.textSecondary)),
            ),
            const SizedBox(height: 16),
            if (_error.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(_error,
                    style:
                        GoogleFonts.inter(fontSize: 12, color: AppColors.error)),
              ),
              const SizedBox(height: 14),
            ],
            _field(_name, 'Full name', autofocus: true),
            const SizedBox(height: 11),
            _field(_phone, 'WhatsApp number',
                keyboard: TextInputType.phone,
                formatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                help: 'Your scholarship code is issued against this number.'),
            const SizedBox(height: 11),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'student', label: Text('Student')),
                ButtonSegment(value: 'working', label: Text('Working')),
              ],
              selected: {_occupation},
              onSelectionChanged: (v) => setState(() => _occupation = v.first),
            ),
            const SizedBox(height: 11),
            _field(_college, _working ? 'Company' : 'College'),
            const SizedBox(height: 11),
            _field(_branch, _working ? 'Role' : 'Branch'),
            const SizedBox(height: 11),
            Row(children: [
              Expanded(
                  child:
                      _field(_year, _working ? 'Years of experience' : 'Year')),
              const SizedBox(width: 11),
              Expanded(child: _field(_city, 'City')),
            ]),
            const SizedBox(height: 11),
            _field(_email, 'Email (optional)',
                keyboard: TextInputType.emailAddress),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 15)),
                onPressed: _busy ? null : _save,
                child: Text(_busy ? 'Saving...' : 'Save and start the test',
                    style: GoogleFonts.poppins(
                        fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label,
          {TextInputType? keyboard,
          List<TextInputFormatter>? formatters,
          String? help,
          bool autofocus = false}) =>
      TextField(
        controller: c,
        autofocus: autofocus,
        keyboardType: keyboard,
        inputFormatters: formatters,
        decoration: InputDecoration(
          labelText: label,
          helperText: help,
          helperMaxLines: 2,
          border: const OutlineInputBorder(),
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
      );
}
