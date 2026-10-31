import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../constants/app_colors.dart';
import '../../services/api_service.dart';
import '../../utils/invoice_calc.dart';
import '../../utils/invoice_share.dart';

/// Payment links with a custom amount (31 Oct 2026, founder: enrol someone manually at the fee you agreed).
/// The admin makes a link and shares it themselves; when it is paid the number gets full access, the CRM marks it
/// Enrolled and a paid invoice appears in Invoices. "Mark paid" records money taken another way and does the same.
class PayLinksScreen extends StatefulWidget {
  const PayLinksScreen({super.key});

  @override
  State<PayLinksScreen> createState() => _PayLinksScreenState();
}

class _PayLinksScreenState extends State<PayLinksScreen> {
  List<Map<String, dynamic>> _links = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ApiService.payLinks();
      if (!mounted) return;
      setState(() {
        _links = List<Map<String, dynamic>>.from(res['links'] ?? []);
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  void _toast(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  String _message(Map<String, dynamic> l) =>
      'Hi ${(l['name'] ?? '').toString().split(' ').first}, here is your payment link for ${l['title']} '
      '(Rs. ${formatInr((l['amount'] as num).toDouble())}, GST included):\n${l['url']}\n\n'
      'After paying, sign in at altrobytelab.com/learn with this WhatsApp number to start.';

  Future<void> _share(Map<String, dynamic> l) =>
      launchUrl(whatsappLink(phone: l['phone'] ?? '', message: _message(l)), mode: LaunchMode.externalApplication);

  Future<void> _copy(Map<String, dynamic> l) async {
    await Clipboard.setData(ClipboardData(text: l['url']));
    _toast('Link copied');
  }

  Future<void> _act(Map<String, dynamic> l, String action, {String reference = ''}) async {
    try {
      final r = await ApiService.payLinkAction(l['id'], action, reference: reference);
      _toast(action == 'check'
          ? (r['status'] == 'paid' ? 'Paid. Access and invoice done.' : 'Not paid yet.')
          : action == 'cancel'
              ? 'Link cancelled'
              : 'Marked paid. Access and invoice done.');
      _load();
    } catch (e) {
      _toast(e.toString());
    }
  }

  Future<void> _markPaid(Map<String, dynamic> l) async {
    final ref = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Mark as paid'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Only after you have the money (cash or UPI to our account). This opens access and makes the invoice.',
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          TextField(controller: ref, decoration: const InputDecoration(labelText: 'UTR / reference (optional)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Back')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Mark paid')),
        ],
      ),
    );
    if (ok == true) await _act(l, 'mark-paid', reference: ref.text.trim());
  }

  Future<void> _create() async {
    final made = await showDialog<Map<String, dynamic>>(context: context, builder: (_) => const _NewLinkDialog());
    if (made == null || !mounted) return;
    await _load();
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Payment link ready'),
        content: SelectableText(made['url'] ?? ''),
        actions: [
          TextButton(onPressed: () { _copy(made); Navigator.pop(context); }, child: const Text('Copy link')),
          ElevatedButton.icon(
            onPressed: () { _share(made); Navigator.pop(context); },
            icon: const Icon(Icons.send_rounded, size: 18),
            label: const Text('Send on WhatsApp'),
          ),
        ],
      ),
    );
  }

  Color _color(String s) => s == 'paid' ? AppColors.success : s == 'cancelled' ? AppColors.textSecondary : AppColors.warning;

  Widget _tile(Map<String, dynamic> l) {
    final status = (l['status'] ?? 'pending').toString();
    final pending = status == 'pending';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text('${l['name']} · ${l['phone']}',
                  style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
            Text('Rs. ${formatInr((l['amount'] as num).toDouble())}',
                style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 2),
          Row(children: [
            Expanded(
              child: Text(l['title'] ?? '',
                  style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                  color: _color(status).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
              child: Text(status == 'paid' ? 'Paid' : status == 'cancelled' ? 'Cancelled' : 'Waiting',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: _color(status))),
            ),
            const SizedBox(width: 8),
          ]),
          if (l['give_access'] == false)
            Text('Payment only, no course access', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
          Wrap(spacing: 2, children: [
            if (pending) TextButton.icon(onPressed: () => _share(l), icon: const Icon(Icons.send_rounded, size: 16), label: const Text('WhatsApp')),
            if (pending) TextButton.icon(onPressed: () => _copy(l), icon: const Icon(Icons.copy_rounded, size: 16), label: const Text('Copy')),
            if (pending) TextButton(onPressed: () => _act(l, 'check'), child: const Text('Check payment')),
            if (pending) TextButton(onPressed: () => _markPaid(l), child: const Text('Mark paid')),
            if (pending)
              TextButton(
                  onPressed: () => _act(l, 'cancel'),
                  child: Text('Cancel', style: TextStyle(color: AppColors.error))),
            if (status == 'paid' && (l['invoice_url'] ?? '').toString().isNotEmpty)
              TextButton.icon(
                  onPressed: () => launchUrl(Uri.parse(l['invoice_url']), mode: LaunchMode.externalApplication),
                  icon: const Icon(Icons.receipt_long_rounded, size: 16),
                  label: Text('Invoice ${l['invoice_no'] ?? ''}')),
          ]),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment links')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_link_rounded),
        label: const Text('New payment link'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 96), children: [
                Text('Enrol someone at any fee: make a link, send it, and when it is paid their WhatsApp number '
                    'gets full course access and the invoice is made here.',
                    style: GoogleFonts.inter(fontSize: 13.5, color: AppColors.textSecondary)),
                const SizedBox(height: 14),
                if (_error != null) Text(_error!, style: TextStyle(color: AppColors.error)),
                if (_error == null && _links.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: Center(child: Text('No payment links yet.', style: GoogleFonts.inter(color: AppColors.textSecondary))),
                  ),
                ..._links.map(_tile),
              ]),
            ),
    );
  }
}

class _NewLinkDialog extends StatefulWidget {
  const _NewLinkDialog();

  @override
  State<_NewLinkDialog> createState() => _NewLinkDialogState();
}

class _NewLinkDialogState extends State<_NewLinkDialog> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _title = TextEditingController(text: 'Altrobyte Live Training');
  final _amount = TextEditingController();
  final _email = TextEditingController();
  bool _access = true;
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() { _saving = true; _error = null; });
    try {
      final made = await ApiService.createPayLink({
        'name': _name.text.trim(),
        'phone': _phone.text.trim(),
        'title': _title.text.trim(),
        'amount': double.parse(_amount.text.trim()),
        'email': _email.text.trim(),
        'give_access': _access,
      });
      if (mounted) Navigator.pop(context, made);
    } catch (e) {
      if (mounted) setState(() { _saving = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    String? need(String? v) => (v ?? '').trim().length < 2 ? 'Required' : null;
    return AlertDialog(
      title: const Text('New payment link'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Student name'), validator: need),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'WhatsApp number', helperText: 'Their course opens on this number'),
                validator: (v) => (v ?? '').replaceAll(RegExp(r'\D'), '').length < 10 ? 'Enter a 10-digit number' : null,
              ),
              TextFormField(controller: _title, decoration: const InputDecoration(labelText: 'For (shows on page and invoice)'), validator: need),
              TextFormField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Amount in Rs. (GST included)'),
                validator: (v) {
                  final n = double.tryParse((v ?? '').trim());
                  return n == null || n <= 0 ? 'Enter the amount' : null;
                },
              ),
              TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email (optional)')),
              const SizedBox(height: 6),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _access,
                onChanged: (v) => setState(() => _access = v),
                title: const Text('Open full course access when paid'),
              ),
              if (_error != null) Text(_error!, style: TextStyle(color: AppColors.error)),
            ]),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Making…' : 'Make link')),
      ],
    );
  }
}
