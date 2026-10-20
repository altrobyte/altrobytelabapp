import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../models/invoice_model.dart';
import '../../services/api_service.dart';
import '../../utils/invoice_calc.dart';

/// Create or edit an invoice. The totals panel is a live estimate (same maths
/// as the server); the saved invoice always shows the server's figures.
class InvoiceFormScreen extends StatefulWidget {
  final int instituteId;
  final InvoiceSettings settings;
  final Invoice? existing;
  /// Duplicate: a new invoice filled from this one (customer, items, notes), dated today with a new number.
  final Invoice? copyFrom;
  const InvoiceFormScreen({super.key, required this.instituteId, required this.settings, this.existing, this.copyFrom});

  @override
  State<InvoiceFormScreen> createState() => _InvoiceFormScreenState();
}

class _ItemRow {
  final desc = TextEditingController();
  final sac = TextEditingController();
  final qty = TextEditingController(text: '1');
  final rate = TextEditingController();
  final gst = TextEditingController();
  void dispose() {
    desc.dispose();
    sac.dispose();
    qty.dispose();
    rate.dispose();
    gst.dispose();
  }
}

class _InvoiceFormScreenState extends State<InvoiceFormScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _gstin = TextEditingController();
  final _discount = TextEditingController();
  final _notes = TextEditingController();
  final List<_ItemRow> _rows = [];
  String _state = '';
  bool _include = false;
  int? _studentId;
  DateTime _issue = DateTime.now();
  DateTime? _due;
  bool _saving = false;
  String? _error;
  List<Map<String, dynamic>> _students = [];

  bool get _editing => widget.existing != null;

  String _gstText(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : '$v';

  @override
  void initState() {
    super.initState();
    final e = widget.existing ?? widget.copyFrom;
    _state = e?.customerState ?? widget.settings['state'];
    if (e != null) {
      _name.text = e.customerName;
      _phone.text = e.customerPhone;
      _email.text = e.customerEmail;
      _address.text = e.customerAddress;
      _gstin.text = e.customerGstin;
      _notes.text = e.notes;
      _discount.text = e.discount > 0 ? '${e.discount}' : '';
      _include = e.pricesIncludeTax;
      _studentId = e.studentId;
      if (widget.existing != null) {
        _issue = DateTime.tryParse(e.issueDate) ?? _issue;
        _due = e.dueDate == null ? null : DateTime.tryParse(e.dueDate!);
      } else {
        _due = DateTime.now().add(const Duration(days: 7));      // a copy is a new invoice: today, due in a week
      }
      for (final i in e.items) {
        final r = _addRow(notify: false);
        r.desc.text = i.description;
        r.sac.text = i.sac;
        r.qty.text = i.qty == i.qty.roundToDouble() ? i.qty.toStringAsFixed(0) : '${i.qty}';
        r.rate.text = '${i.rate}';
        r.gst.text = _gstText(i.gstRate);
      }
    } else {
      _due = DateTime.now().add(const Duration(days: 7));
      _addRow(notify: false);
    }
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    try {
      final raw = await ApiService.getStudents(widget.instituteId);
      if (!mounted) return;
      setState(() => _students = [for (final s in raw) Map<String, dynamic>.from(s)]);
    } catch (_) {
      // Picking a student is a convenience; typing the customer in still works.
    }
  }

  _ItemRow _addRow({bool notify = true}) {
    final r = _ItemRow()
      ..sac.text = widget.settings['default_sac']
      ..gst.text = _gstText(widget.settings.defaultGstRate);
    for (final c in [r.desc, r.sac, r.qty, r.rate, r.gst]) {
      c.addListener(_refresh);
    }
    _rows.add(r);
    if (notify) setState(() {});
    return r;
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _email, _address, _gstin, _discount, _notes]) {
      c.dispose();
    }
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  double _num(TextEditingController c) => double.tryParse(c.text.trim()) ?? 0;

  bool get _inter => isInterState(widget.settings['state'], _state);

  InvoiceTotals? get _totals => computeInvoiceTotals(
        [
          for (final r in _rows)
            InvoiceLineInput(
                description: r.desc.text, sac: r.sac.text, qty: _num(r.qty), rate: _num(r.rate), gstRate: _num(r.gst))
        ],
        discount: _num(_discount),
        pricesIncludeTax: _include,
        interState: _inter,
      );

  String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate({required bool due}) async {
    final initial = due ? (_due ?? _issue.add(const Duration(days: 7))) : _issue;
    final d = await showDatePicker(
        context: context, initialDate: initial, firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (d == null) return;
    setState(() => due ? _due = d : _issue = d);
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Enter the customer name');
      return;
    }
    if (_totals == null) {
      setState(() => _error = 'Add at least one line item with a quantity and rate (and a discount no larger than the total)');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final body = {
      'student_id': _studentId,
      'customer_name': _name.text.trim(),
      'customer_phone': _phone.text.trim(),
      'customer_email': _email.text.trim(),
      'customer_address': _address.text.trim(),
      'customer_gstin': _gstin.text.trim(),
      'customer_state': _state,
      'issue_date': _iso(_issue),
      'due_date': _due == null ? null : _iso(_due!),
      'items': [
        for (final r in _rows)
          if (r.desc.text.trim().isNotEmpty)
            InvoiceItem(
                    description: r.desc.text,
                    sac: r.sac.text,
                    qty: _num(r.qty),
                    rate: _num(r.rate),
                    gstRate: _num(r.gst))
                .toJson()
      ],
      'discount': _num(_discount),
      'prices_include_tax': _include,
      'notes': _notes.text.trim(),
    };
    try {
      final res = _editing
          ? await ApiService.updateInvoice(widget.existing!.id, body)
          : await ApiService.createInvoice(widget.instituteId, body);
      if (!mounted) return;
      Navigator.pop(context, Invoice.fromJson(res));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString();
      });
    }
  }

  InputDecoration _dec(String label, {String? hint, Widget? suffix}) => InputDecoration(
        labelText: label,
        hintText: hint,
        suffixIcon: suffix,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      );

  Widget _card(String title, Widget child) => Card(
        elevation: 0,
        color: AppColors.cardBg,
        margin: const EdgeInsets.only(bottom: 14),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14), side: BorderSide(color: Colors.black.withValues(alpha: 0.06))),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
            const SizedBox(height: 12),
            child,
          ]),
        ),
      );

  Widget _customer() => _card(
        'Customer',
        Column(children: [
          Autocomplete<Map<String, dynamic>>(
            displayStringForOption: (s) => '${s['name'] ?? ''}',
            optionsBuilder: (v) {
              final q = v.text.trim().toLowerCase();
              if (q.isEmpty) return const Iterable.empty();
              return _students
                  .where((s) => '${s['name'] ?? ''}'.toLowerCase().contains(q) || '${s['phone'] ?? ''}'.contains(q))
                  .take(8);
            },
            fieldViewBuilder: (context, ctl, focus, onSubmit) => TextField(
              controller: ctl,
              focusNode: focus,
              decoration: _dec('Find a student (optional)', hint: 'Type a name or phone to fill the details below',
                  suffix: const Icon(Icons.search_rounded, size: 20)),
            ),
            optionsViewBuilder: (context, onSelected, options) => Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(10),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420, maxHeight: 260),
                  child: ListView(shrinkWrap: true, children: [
                    for (final s in options)
                      ListTile(
                        dense: true,
                        title: Text('${s['name'] ?? ''}'),
                        subtitle: Text('${s['phone'] ?? ''}'),
                        onTap: () => onSelected(s),
                      )
                  ]),
                ),
              ),
            ),
            onSelected: (s) => setState(() {
              _studentId = s['id'] is int ? s['id'] as int : int.tryParse('${s['id']}');
              _name.text = '${s['name'] ?? ''}';
              _phone.text = '${s['phone'] ?? ''}';
              if ('${s['address'] ?? ''}'.isNotEmpty) _address.text = '${s['address']}';
              if ('${s['email'] ?? ''}'.isNotEmpty) _email.text = '${s['email']}';
            }),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(flex: 3, child: TextField(controller: _name, decoration: _dec('Customer name *'))),
            const SizedBox(width: 10),
            Expanded(
                flex: 2,
                child: TextField(
                    controller: _phone, decoration: _dec('Phone (for WhatsApp)'), keyboardType: TextInputType.phone)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: TextField(controller: _email, decoration: _dec('Email'))),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: _gstin, decoration: _dec('Customer GSTIN (if any)'))),
          ]),
          const SizedBox(height: 12),
          TextField(controller: _address, decoration: _dec('Address'), minLines: 1, maxLines: 3),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: indianStates.contains(_state) ? _state : null,
            isExpanded: true,
            decoration: _dec('Customer state'),
            items: [for (final s in indianStates) DropdownMenuItem(value: s, child: Text(s))],
            onChanged: (v) => setState(() => _state = v ?? ''),
          ),
          if (widget.settings['state'].isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Set your own state in Invoice Settings, otherwise GST is always split as CGST + SGST.',
                  style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.warning)),
            ),
        ]),
      );

  Widget _items() => _card(
        'Line items',
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (var i = 0; i < _rows.length; i++) _itemRow(i),
          TextButton.icon(onPressed: _addRow, icon: const Icon(Icons.add_rounded), label: const Text('Add line')),
          const Divider(height: 24),
          Row(children: [
            Expanded(
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text('Prices already include GST', style: GoogleFonts.inter(fontSize: 13)),
                subtitle: Text('Off: GST is added on top of the rates.', style: GoogleFonts.inter(fontSize: 11.5)),
                value: _include,
                onChanged: (v) => setState(() => _include = v),
              ),
            ),
            SizedBox(width: 160, child: TextField(controller: _discount, decoration: _dec('Discount (Rs.)'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true))),
          ]),
        ]),
      );

  Widget _itemRow(int i) {
    final r = _rows[i];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: LayoutBuilder(builder: (context, c) {
        final narrow = c.maxWidth < 560;
        final desc = TextField(controller: r.desc, decoration: _dec('Description'), minLines: 1, maxLines: 3);
        final nums = [
          Expanded(flex: 2, child: TextField(controller: r.sac, decoration: _dec('SAC'))),
          const SizedBox(width: 8),
          Expanded(child: TextField(controller: r.qty, decoration: _dec('Qty'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true))),
          const SizedBox(width: 8),
          Expanded(
              flex: 2,
              child: TextField(controller: r.rate, decoration: _dec('Rate (Rs.)'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true))),
          const SizedBox(width: 8),
          Expanded(child: TextField(controller: r.gst, decoration: _dec('GST %'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true))),
          IconButton(
            tooltip: 'Remove line',
            icon: const Icon(Icons.close_rounded, size: 18),
            onPressed: _rows.length == 1
                ? null
                : () => setState(() {
                      _rows.removeAt(i).dispose();
                    }),
          ),
        ];
        return narrow
            ? Column(children: [desc, const SizedBox(height: 8), Row(children: nums)])
            : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(flex: 4, child: desc),
                const SizedBox(width: 8),
                Expanded(flex: 6, child: Row(children: nums)),
              ]);
      }),
    );
  }

  Widget _dates() => _card(
        'Dates & notes',
        Column(children: [
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickDate(due: false),
                icon: const Icon(Icons.event_rounded, size: 18),
                label: Text('Invoice date: ${_iso(_issue)}'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickDate(due: true),
                icon: const Icon(Icons.event_busy_rounded, size: 18),
                label: Text(_due == null ? 'Set due date' : 'Due: ${_iso(_due!)}'),
              ),
            ),
            if (_due != null) IconButton(onPressed: () => setState(() => _due = null), icon: const Icon(Icons.close_rounded, size: 18)),
          ]),
          const SizedBox(height: 12),
          TextField(controller: _notes, decoration: _dec('Notes (printed on the invoice)'), minLines: 1, maxLines: 4),
        ]),
      );

  Widget _summary() {
    final t = _totals;
    Widget row(String l, double v, {bool bold = false, Color? color}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            Text(l, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary, fontWeight: bold ? FontWeight.w600 : FontWeight.normal)),
            const Spacer(),
            Text('Rs. ${formatInr(v)}',
                style: GoogleFonts.inter(fontSize: bold ? 16 : 13, fontWeight: bold ? FontWeight.w700 : FontWeight.w500, color: color)),
          ]),
        );
    return _card(
      'Summary (estimate)',
      t == null
          ? Text('Add a line item to see the totals.', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary))
          : Column(children: [
              row('Subtotal', t.subtotal),
              if (t.discount > 0) row('Discount', -t.discount),
              row('Taxable value', t.taxable),
              if (_inter) row('IGST', t.igst) else ...[row('CGST', t.cgst), row('SGST', t.sgst)],
              if (t.roundOff != 0) row('Round off', t.roundOff),
              const Divider(),
              row('Total', t.grand, bold: true, color: AppColors.primary),
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(_inter ? 'Other-state customer: IGST applies.' : 'Same state (or state not set): CGST + SGST.',
                      style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.textSecondary)),
                ),
              ),
            ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(_editing ? 'Edit ${widget.existing!.invoiceNo}' : 'New Invoice',
            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 17)),
        actions: [
          TextButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.check_rounded, color: Colors.white, size: 20),
            label: Text(_saving ? 'Saving…' : (_editing ? 'Save changes' : 'Create invoice'),
                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: ListView(padding: const EdgeInsets.all(16), children: [
            if (_error != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
                child: Text(_error!, style: GoogleFonts.inter(fontSize: 13, color: AppColors.error)),
              ),
            _customer(),
            _items(),
            _dates(),
            _summary(),
            const SizedBox(height: 40),
          ]),
        ),
      ),
    );
  }
}
