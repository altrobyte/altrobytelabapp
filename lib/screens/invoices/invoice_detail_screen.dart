import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../constants/app_colors.dart';
import '../../models/invoice_model.dart';
import '../../services/api_service.dart';
import '../../utils/file_download.dart';
import '../../utils/invoice_calc.dart';
import '../../utils/invoice_share.dart';
import 'invoice_form_screen.dart';

/// One invoice: share it, record what has been paid, edit or cancel it.
/// Pops with `true` when anything changed so the list can refresh.
class InvoiceDetailScreen extends StatefulWidget {
  final int instituteId;
  final int invoiceId;
  final InvoiceSettings settings;
  const InvoiceDetailScreen({super.key, required this.instituteId, required this.invoiceId, required this.settings});

  @override
  State<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends State<InvoiceDetailScreen> {
  static const _modes = ['UPI', 'Cash', 'Bank transfer', 'Cheque', 'Card', 'Other'];
  Invoice? _inv;
  bool _loading = true;
  bool _busy = false;
  bool _changed = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final j = await ApiService.getInvoice(widget.invoiceId);
      if (!mounted) return;
      setState(() {
        _inv = Invoice.fromJson(j);
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: error ? AppColors.error : AppColors.success));
  }

  Future<void> _run(Future<void> Function() job) async {
    setState(() => _busy = true);
    try {
      await job();
    } catch (e) {
      _toast(e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _download() => _run(() async {
        final inv = _inv!;
        final bytes = await ApiService.fetchInvoicePdf(inv.id);
        downloadBytes('${inv.invoiceNo.replaceAll('/', '-')}.pdf', bytes);
      });

  Future<void> _whatsapp() async {
    final inv = _inv!;
    final msg = invoiceShareMessage(
      customerName: inv.customerName,
      invoiceNo: inv.invoiceNo,
      businessName: widget.settings['business_name'].isEmpty ? 'us' : widget.settings['business_name'],
      total: inv.grandTotal,
      balance: inv.balance,
      shareUrl: inv.shareUrl,
      dueDate: inv.dueDate,
    );
    final ok = await launchUrl(whatsappLink(phone: inv.customerPhone, message: msg), mode: LaunchMode.externalApplication);
    if (!ok) _toast('Could not open WhatsApp', error: true);
  }

  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: _inv!.shareUrl));
    _toast('Link copied');
  }

  Future<void> _openLink() => launchUrl(Uri.parse(_inv!.shareUrl), mode: LaunchMode.externalApplication);

  Future<void> _edit() async {
    final res = await Navigator.push<Invoice>(
      context,
      MaterialPageRoute(
          builder: (_) => InvoiceFormScreen(instituteId: widget.instituteId, settings: widget.settings, existing: _inv)),
    );
    if (res != null) {
      _changed = true;
      await _load();
    }
  }

  Future<void> _cancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this invoice?'),
        content: Text(
            '${_inv!.invoiceNo} will be marked CANCELLED and kept on record. Its number is never reused. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep it')),
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Cancel invoice')),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() async {
      final j = await ApiService.cancelInvoice(_inv!.id);
      _changed = true;
      setState(() => _inv = Invoice.fromJson(j));
    });
  }

  Future<void> _recordPayment() async {
    final inv = _inv!;
    final amount = TextEditingController(text: inv.balance == inv.balance.roundToDouble() ? inv.balance.toStringAsFixed(0) : '${inv.balance}');
    final ref = TextEditingController();
    var mode = _modes.first;
    var date = DateTime.now();
    String? err;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text('Record payment', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          content: SizedBox(
            width: 380,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Balance due: Rs. ${formatInr(inv.balance)}',
                    style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textSecondary)),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: amount,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                    labelText: 'Amount received (Rs.)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: mode,
                decoration: InputDecoration(labelText: 'Mode', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                items: [for (final m in _modes) DropdownMenuItem(value: m, child: Text(m))],
                onChanged: (v) => setD(() => mode = v ?? mode),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: ref,
                decoration: InputDecoration(
                    labelText: 'Reference / UTR (optional)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  icon: const Icon(Icons.event_rounded, size: 18),
                  label: Text('Received on ${date.day}/${date.month}/${date.year}'),
                  onPressed: () async {
                    final d = await showDatePicker(
                        context: ctx, initialDate: date, firstDate: DateTime(2020), lastDate: DateTime.now());
                    if (d != null) setD(() => date = d);
                  },
                ),
              ),
              if (err != null) Text(err!, style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.error)),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final v = double.tryParse(amount.text.trim());
                if (v == null || v <= 0) {
                  setD(() => err = 'Enter an amount greater than zero');
                  return;
                }
                if (v > inv.balance + 0.0001) {
                  setD(() => err = 'That is more than the balance due');
                  return;
                }
                Navigator.pop(ctx, {
                  'amount': v,
                  'mode': mode,
                  'reference': ref.text.trim(),
                  'paid_on':
                      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
                });
              },
              child: const Text('Save payment'),
            ),
          ],
        ),
      ),
    );
    if (result == null) return;
    await _run(() async {
      final j = await ApiService.addInvoicePayment(inv.id, result);
      _changed = true;
      setState(() => _inv = Invoice.fromJson(j));
      _toast('Payment recorded');
    });
  }

  Future<void> _removePayment(InvoicePayment p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove this payment?'),
        content: Text('Rs. ${formatInr(p.amount)} (${p.mode}) will be removed and the balance due goes back up.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove')),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() async {
      final j = await ApiService.deleteInvoicePayment(_inv!.id, p.id);
      _changed = true;
      setState(() => _inv = Invoice.fromJson(j));
    });
  }

  Color _statusColor(Invoice i) => i.isCancelled
      ? AppColors.textSecondary
      : i.isPaid
          ? AppColors.success
          : i.isOverdue
              ? AppColors.error
              : i.status == 'partial'
                  ? AppColors.warning
                  : AppColors.primary;

  String _statusLabel(Invoice i) => i.isOverdue && !i.isCancelled && !i.isPaid ? 'Overdue' : '${i.status[0].toUpperCase()}${i.status.substring(1)}';

  Widget _card(Widget child) => Card(
        elevation: 0,
        color: AppColors.cardBg,
        margin: const EdgeInsets.only(bottom: 14),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14), side: BorderSide(color: Colors.black.withValues(alpha: 0.06))),
        child: Padding(padding: const EdgeInsets.all(16), child: child),
      );

  Widget _kv(String k, String v, {bool bold = false, Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Text(k, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
          const Spacer(),
          Text(v, style: GoogleFonts.inter(fontSize: bold ? 15 : 13, fontWeight: bold ? FontWeight.w700 : FontWeight.w500, color: color)),
        ]),
      );

  Widget _action(IconData icon, String label, VoidCallback? onTap, {Color? color, bool filled = false}) => filled
      ? ElevatedButton.icon(
          onPressed: _busy ? null : onTap,
          icon: Icon(icon, size: 18),
          label: Text(label),
          style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white),
        )
      : OutlinedButton.icon(
          onPressed: _busy ? null : onTap,
          icon: Icon(icon, size: 18, color: color),
          label: Text(label, style: TextStyle(color: color)),
        );

  @override
  Widget build(BuildContext context) {
    final inv = _inv;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          iconTheme: const IconThemeData(color: Colors.white),
          leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => Navigator.pop(context, _changed)),
          title: Text(inv?.invoiceNo ?? 'Invoice',
              style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 17)),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : inv == null
                ? Center(child: Text(_error ?? 'Invoice not found'))
                : Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 820),
                      child: ListView(padding: const EdgeInsets.all(16), children: [
                        if (_busy) const LinearProgressIndicator(minHeight: 2),
                        _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Expanded(
                              child: Text(inv.customerName, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                  color: _statusColor(inv).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                              child: Text(_statusLabel(inv),
                                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: _statusColor(inv))),
                            ),
                          ]),
                          if (inv.customerPhone.isNotEmpty || inv.customerEmail.isNotEmpty)
                            Text([inv.customerPhone, inv.customerEmail].where((e) => e.isNotEmpty).join('  |  '),
                                style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textSecondary)),
                          const SizedBox(height: 12),
                          _kv('Invoice date', inv.issueDate),
                          _kv('Due date', inv.dueDate ?? 'On receipt', color: inv.isOverdue ? AppColors.error : null),
                          const Divider(height: 22),
                          _kv('Total', 'Rs. ${formatInr(inv.grandTotal)}', bold: true),
                          _kv('Paid', 'Rs. ${formatInr(inv.amountPaid)}', color: AppColors.success),
                          _kv('Balance due', 'Rs. ${formatInr(inv.balance)}', bold: true, color: inv.balance > 0 && !inv.isCancelled ? AppColors.error : AppColors.success),
                        ])),
                        _card(Wrap(spacing: 10, runSpacing: 10, children: [
                          _action(Icons.picture_as_pdf_rounded, 'Download PDF', _download, filled: true, color: AppColors.primary),
                          _action(Icons.chat_rounded, 'Send on WhatsApp', _whatsapp, filled: true, color: AppColors.whatsapp),
                          _action(Icons.link_rounded, 'Copy link', _copyLink),
                          _action(Icons.open_in_new_rounded, 'Open', _openLink),
                          if (!inv.isCancelled && !inv.isPaid) _action(Icons.payments_rounded, 'Record payment', _recordPayment, color: AppColors.success),
                          if (inv.canEdit) _action(Icons.edit_rounded, 'Edit', _edit),
                          if (!inv.isCancelled && inv.amountPaid <= 0) _action(Icons.block_rounded, 'Cancel invoice', _cancel, color: AppColors.error),
                        ])),
                        _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Items', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
                          const SizedBox(height: 8),
                          for (final i in inv.items)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Expanded(child: Text(i.description, style: GoogleFonts.inter(fontSize: 13))),
                                Text('${i.qty == i.qty.roundToDouble() ? i.qty.toStringAsFixed(0) : i.qty} × ${formatInr(i.rate)}  (${i.gstRate == i.gstRate.roundToDouble() ? i.gstRate.toStringAsFixed(0) : i.gstRate}% GST)',
                                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                              ]),
                            ),
                          const Divider(height: 22),
                          _kv('Subtotal', formatInr(inv.subtotal)),
                          if (inv.discount > 0) _kv('Discount', '-${formatInr(inv.discount)}'),
                          _kv('Taxable value', formatInr(inv.taxableTotal)),
                          if (inv.interState)
                            _kv('IGST', formatInr(inv.igstTotal))
                          else ...[_kv('CGST', formatInr(inv.cgstTotal)), _kv('SGST', formatInr(inv.sgstTotal))],
                          if (inv.roundOff != 0) _kv('Round off', formatInr(inv.roundOff)),
                        ])),
                        _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Payments', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
                          const SizedBox(height: 6),
                          if (inv.payments.isEmpty)
                            Text('Nothing received yet.', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary))
                          else
                            for (final p in inv.payments)
                              ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text('Rs. ${formatInr(p.amount)}  •  ${p.mode.isEmpty ? 'Payment' : p.mode}',
                                    style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                                subtitle: Text('${p.paidOn}${p.reference.isEmpty ? '' : '  •  ${p.reference}'}'),
                                trailing: inv.isCancelled
                                    ? null
                                    : IconButton(
                                        tooltip: 'Remove this payment',
                                        icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.error),
                                        onPressed: _busy ? null : () => _removePayment(p)),
                              ),
                        ])),
                        const SizedBox(height: 30),
                      ]),
                    ),
                  ),
      ),
    );
  }
}
