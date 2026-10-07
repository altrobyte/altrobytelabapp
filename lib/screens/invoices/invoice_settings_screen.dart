import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../models/invoice_model.dart';
import '../../services/api_service.dart';

/// The seller details printed on every invoice: business, GSTIN, UPI (for the
/// QR) and bank account. Read live when an invoice is drawn, so fixing a UPI id
/// here fixes every invoice that is still being paid.
class InvoiceSettingsScreen extends StatefulWidget {
  final int instituteId;
  final InvoiceSettings initial;
  const InvoiceSettingsScreen({super.key, required this.instituteId, required this.initial});

  @override
  State<InvoiceSettingsScreen> createState() => _InvoiceSettingsScreenState();
}

class _InvoiceSettingsScreenState extends State<InvoiceSettingsScreen> {
  static final _gstin = RegExp(r'^\d{2}[A-Z]{5}\d{4}[A-Z][1-9A-Z]Z[0-9A-Z]$');
  late final Map<String, TextEditingController> _c = {
    for (final f in InvoiceSettings.textFields) f: TextEditingController(text: widget.initial[f]),
  };
  late final _gstCtl = TextEditingController(
      text: widget.initial.defaultGstRate == widget.initial.defaultGstRate.roundToDouble()
          ? widget.initial.defaultGstRate.toStringAsFixed(0)
          : '${widget.initial.defaultGstRate}');
  final _form = GlobalKey<FormState>();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    _gstCtl.dispose();
    super.dispose();
  }

  InputDecoration _dec(String label, {String? hint, String? helper}) => InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helper,
        helperMaxLines: 2,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      );

  Widget _field(String key, String label,
          {String? hint, String? helper, int lines = 1, String? Function(String?)? validator, TextInputType? type}) =>
      TextFormField(
        controller: _c[key],
        decoration: _dec(label, hint: hint, helper: helper),
        minLines: 1,
        maxLines: lines,
        keyboardType: type,
        validator: validator,
      );

  Widget _section(String title, String? subtitle, List<Widget> children) => Card(
        elevation: 0,
        color: AppColors.cardBg,
        margin: const EdgeInsets.only(bottom: 14),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14), side: BorderSide(color: Colors.black.withValues(alpha: 0.06))),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
              ),
            const SizedBox(height: 14),
            for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(height: 12), children[i]],
          ]),
        ),
      );

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final gst = double.tryParse(_gstCtl.text.trim());
    if (gst == null || gst < 0 || gst > 100) {
      setState(() => _error = 'Default GST rate must be between 0 and 100');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final body = {for (final e in _c.entries) e.key: e.value.text.trim(), 'default_gst_rate': gst};
      final saved = await ApiService.saveInvoiceSettings(widget.instituteId, body);
      if (!mounted) return;
      Navigator.pop(context, InvoiceSettings.fromJson(saved));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text('Invoice Settings',
            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 17)),
        actions: [
          TextButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save_rounded, color: Colors.white, size: 20),
            label: Text(_saving ? 'Saving…' : 'Save',
                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: Form(
        key: _form,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(padding: const EdgeInsets.all(16), children: [
              if (_error != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
                  child: Text(_error!, style: GoogleFonts.inter(fontSize: 13, color: AppColors.error)),
                ),
              _section('Business', 'Printed at the top of every invoice.', [
                _field('business_name', 'Business name',
                    validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null),
                _field('address', 'Address', lines: 3),
                Row(children: [
                  Expanded(child: _field('city', 'City')),
                  const SizedBox(width: 10),
                  Expanded(child: _field('pincode', 'Pincode', type: TextInputType.number)),
                ]),
                DropdownButtonFormField<String>(
                  initialValue: indianStates.contains(_c['state']!.text) ? _c['state']!.text : null,
                  isExpanded: true,
                  decoration: _dec('State',
                      helper: 'Decides CGST+SGST (same state) or IGST (other state) on every invoice.'),
                  items: [for (final s in indianStates) DropdownMenuItem(value: s, child: Text(s))],
                  onChanged: (v) => _c['state']!.text = v ?? '',
                ),
                Row(children: [
                  Expanded(child: _field('phone', 'Phone', type: TextInputType.phone)),
                  const SizedBox(width: 10),
                  Expanded(child: _field('email', 'Email', type: TextInputType.emailAddress)),
                ]),
              ]),
              _section('GST & numbering', 'Leave GSTIN empty if you are not GST-registered — the document is then a plain "Invoice".', [
                _field('gstin', 'GSTIN', hint: '23ABCDE1234F1Z5', validator: (v) {
                  final t = (v ?? '').trim().toUpperCase();
                  return t.isEmpty || _gstin.hasMatch(t) ? null : 'A GSTIN is 15 characters, like 23ABCDE1234F1Z5';
                }),
                _field('pan', 'PAN (optional)'),
                Row(children: [
                  Expanded(
                      child: _field('default_sac', 'Default SAC code',
                          helper: '999293 = commercial training & coaching. Confirm with your CA.')),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _gstCtl,
                      decoration: _dec('Default GST %', helper: 'Pre-fills each new line item.'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                ]),
                _field('invoice_prefix', 'Invoice number prefix',
                    helper: 'Numbers look like INV/2026-27/0001 and restart every April.'),
              ]),
              _section('Get paid', 'The UPI QR on each invoice carries the balance due; bank details print next to it.', [
                _field('upi_id', 'UPI ID', hint: 'yourname@okhdfcbank', validator: (v) {
                  final t = (v ?? '').trim();
                  return t.isEmpty || t.contains('@') ? null : 'A UPI ID looks like name@bank';
                }),
                _field('upi_name', 'Name shown in the UPI app', helper: 'Usually your business name.'),
                _field('bank_account_name', 'Account holder name'),
                Row(children: [
                  Expanded(child: _field('bank_name', 'Bank')),
                  const SizedBox(width: 10),
                  Expanded(child: _field('bank_branch', 'Branch')),
                ]),
                Row(children: [
                  Expanded(child: _field('bank_account_no', 'Account number', type: TextInputType.number)),
                  const SizedBox(width: 10),
                  Expanded(child: _field('bank_ifsc', 'IFSC')),
                ]),
              ]),
              _section('Terms & signature', null, [
                _field('terms', 'Terms & conditions', lines: 5, hint: '1. Fees once paid are non-refundable.'),
                _field('signatory', 'Authorised signatory', hint: 'Name printed above "Authorised signatory"'),
              ]),
              const SizedBox(height: 40),
            ]),
          ),
        ),
      ),
    );
  }
}
