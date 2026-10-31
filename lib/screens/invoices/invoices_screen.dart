import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../models/invoice_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../utils/invoice_calc.dart';
import '../../widgets/loading_widget.dart';
import 'invoice_detail_screen.dart';
import 'invoice_form_screen.dart';
import 'invoice_settings_screen.dart';
import 'pay_links_screen.dart';

/// Invoices for the institute: what has been billed, collected and is overdue,
/// with one-tap access to share or record a payment.
class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  static const _filters = [
    (null, 'All'),
    ('unpaid', 'Unpaid'),
    ('partial', 'Part paid'),
    ('overdue', 'Overdue'),
    ('paid', 'Paid'),
    ('cancelled', 'Cancelled'),
  ];

  List<Invoice> _invoices = [];
  InvoiceSummary _summary = const InvoiceSummary();
  InvoiceSettings _settings = InvoiceSettings();
  String? _status;
  String _query = '';
  bool _loading = true;
  String? _error;
  Timer? _debounce;
  final _search = TextEditingController();

  int? get _instituteId => context.read<AuthProvider>().instituteId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load(withSettings: true));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool withSettings = false}) async {
    final id = _instituteId;
    if (id == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final results = await Future.wait([
        ApiService.listInvoices(id, status: _status, q: _query),
        if (withSettings) ApiService.getInvoiceSettings(id),
      ]);
      if (!mounted) return;
      final data = results[0];
      setState(() {
        _invoices = [for (final i in data['invoices'] as List) Invoice.fromJson(Map<String, dynamic>.from(i))];
        _summary = InvoiceSummary.fromJson(Map<String, dynamic>.from(data['summary']));
        if (withSettings) _settings = InvoiceSettings.fromJson(results[1]);
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

  bool get _setupIncomplete =>
      _settings['business_name'].trim().isEmpty || _settings['state'].trim().isEmpty || !_settings.hasUpi;

  Future<void> _openSettings() async {
    final id = _instituteId;
    if (id == null) return;
    final res = await Navigator.push<InvoiceSettings>(
      context,
      MaterialPageRoute(builder: (_) => InvoiceSettingsScreen(instituteId: id, initial: _settings)),
    );
    if (res != null && mounted) setState(() => _settings = res);
  }

  Future<void> _newInvoice() async {
    final id = _instituteId;
    if (id == null) return;
    final created = await Navigator.push<Invoice>(
      context,
      MaterialPageRoute(builder: (_) => InvoiceFormScreen(instituteId: id, settings: _settings)),
    );
    if (created == null || !mounted) return;
    await _open(created); // straight to share/pay actions
  }

  Future<void> _open(Invoice inv) async {
    final id = _instituteId;
    if (id == null) return;
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) => InvoiceDetailScreen(instituteId: id, invoiceId: inv.id, settings: _settings)),
    );
    if (mounted) _load();
  }

  Color _color(Invoice i) => i.isCancelled
      ? AppColors.textSecondary
      : i.isPaid
          ? AppColors.success
          : i.isOverdue
              ? AppColors.error
              : i.status == 'partial'
                  ? AppColors.warning
                  : AppColors.primary;

  String _label(Invoice i) => i.isCancelled
      ? 'Cancelled'
      : i.isPaid
          ? 'Paid'
          : i.isOverdue
              ? 'Overdue'
              : i.status == 'partial'
                  ? 'Part paid'
                  : 'Unpaid';

  Widget _stat(String label, double value, Color color) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('Rs. ${formatInr(value)}',
                  style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700, color: color)),
            ),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingWidget(message: 'Loading invoices...');
    return RefreshIndicator(
      onRefresh: () => _load(withSettings: true),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text('Invoices',
                style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(width: 24),
            OutlinedButton.icon(
              onPressed: _openSettings,
              icon: const Icon(Icons.tune_rounded, size: 18),
              label: const Text('Settings'),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => const PayLinksScreen()));
                if (mounted) _load();
              },
              icon: const Icon(Icons.add_link_rounded, size: 18),
              label: const Text('Payment link / enrol'),
            ),
            ElevatedButton.icon(
              onPressed: _newInvoice,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('New invoice'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white),
            ),
          ]),
          const SizedBox(height: 14),
          if (_setupIncomplete)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                const Icon(Icons.info_outline_rounded, color: AppColors.warning),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                      'Finish Invoice Settings (business name, state, GSTIN, UPI ID, bank) so your invoices carry the right GST split and a payment QR.',
                      style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textPrimary)),
                ),
                TextButton(onPressed: _openSettings, child: const Text('Open settings')),
              ]),
            ),
          Row(children: [
            _stat('Billed', _summary.billed, AppColors.primary),
            const SizedBox(width: 10),
            _stat('Collected', _summary.collected, AppColors.success),
            const SizedBox(width: 10),
            _stat('Outstanding', _summary.outstanding, AppColors.warning),
            const SizedBox(width: 10),
            _stat('Overdue', _summary.overdue, AppColors.error),
          ]),
          const SizedBox(height: 16),
          TextField(
            controller: _search,
            decoration: InputDecoration(
              hintText: 'Search by customer, phone or invoice number',
              prefixIcon: const Icon(Icons.search_rounded),
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onChanged: (v) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 350), () {
                _query = v;
                _load();
              });
            },
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 6, children: [
            for (final f in _filters)
              ChoiceChip(
                label: Text(f.$2),
                selected: _status == f.$1,
                onSelected: (_) {
                  setState(() => _status = f.$1);
                  _load();
                },
              ),
          ]),
          const SizedBox(height: 14),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(_error!, style: GoogleFonts.inter(color: AppColors.error)),
            )
          else if (_invoices.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: EmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'No invoices here',
                  subtitle: 'Create one with "New invoice" and share it with a student on WhatsApp'),
            )
          else
            for (final inv in _invoices)
              Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 8),
                color: AppColors.cardBg,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.black.withValues(alpha: 0.06))),
                child: ListTile(
                  onTap: () => _open(inv),
                  title: Text(inv.customerName, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text('${inv.invoiceNo}  •  ${inv.issueDate}',
                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                  trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('Rs. ${formatInr(inv.grandTotal)}', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14)),
                    const SizedBox(height: 3),
                    Text(_label(inv), style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: _color(inv))),
                  ]),
                ),
              ),
        ],
      ),
    );
  }
}
