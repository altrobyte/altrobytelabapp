// Live preview of invoice totals while the form is being filled in.
//
// A mirror of the backend's invoice_calc.py, done in whole paise (integers) so
// the half-up rounding matches. It is only an estimate: the server computes the
// real totals when the invoice is saved, and those are what the invoice shows.

class InvoiceLineInput {
  final String description;
  final String sac;
  final double qty;
  final double rate;
  final double gstRate;
  const InvoiceLineInput({
    required this.description,
    this.sac = '',
    required this.qty,
    required this.rate,
    required this.gstRate,
  });
}

class InvoiceTotals {
  final double subtotal;
  final double discount;
  final double taxable;
  final double cgst;
  final double sgst;
  final double igst;
  final double roundOff;
  final double grand;
  const InvoiceTotals({
    required this.subtotal,
    required this.discount,
    required this.taxable,
    required this.cgst,
    required this.sgst,
    required this.igst,
    required this.roundOff,
    required this.grand,
  });

  double get tax => cgst + sgst + igst;
}

int _paise(double v) => (v * 100 + (v >= 0 ? 1e-9 : -1e-9)).round();

/// Half-up division of a non-negative paise value.
int _divRound(int numerator, int denominator) =>
    denominator == 0 ? 0 : (numerator * 2 + denominator) ~/ (denominator * 2);

/// IGST applies only when both states are known and differ.
bool isInterState(String? seller, String? customer) {
  String norm(String? s) => (s ?? '').toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).join(' ');
  final a = norm(seller), b = norm(customer);
  return a.isNotEmpty && b.isNotEmpty && a != b;
}

/// Null when there is nothing billable yet (so the form can show a blank
/// summary rather than zeros).
InvoiceTotals? computeInvoiceTotals(
  List<InvoiceLineInput> items, {
  double discount = 0,
  bool pricesIncludeTax = false,
  bool interState = false,
}) {
  final lines = items.where((i) => i.description.trim().isNotEmpty && i.qty > 0 && i.rate >= 0).toList();
  if (lines.isEmpty) return null;

  final gross = [for (final l in lines) _paise(l.qty * l.rate)];
  final subtotal = gross.fold<int>(0, (a, b) => a + b);
  final disc = _paise(discount);
  if (disc < 0 || disc > subtotal) return null;

  var remaining = disc;
  var taxable = 0, cgst = 0, sgst = 0, igst = 0;
  for (var i = 0; i < lines.length; i++) {
    final share = i == lines.length - 1 ? remaining : _divRound(disc * gross[i], subtotal);
    remaining -= share;
    final net = gross[i] - share;
    final r = lines[i].gstRate;
    int lineTaxable, tax;
    if (pricesIncludeTax) {
      lineTaxable = _paise(net / (1 + r / 100) / 100);
      tax = net - lineTaxable;
    } else {
      lineTaxable = net;
      tax = _paise(net * r / 100 / 100);
    }
    taxable += lineTaxable;
    if (interState) {
      igst += tax;
    } else {
      final half = (tax + 1) ~/ 2;
      cgst += half;
      sgst += tax - half;
    }
  }

  final total = taxable + cgst + sgst + igst;
  final grand = ((total + 50) ~/ 100) * 100;
  double rs(int p) => p / 100;
  return InvoiceTotals(
    subtotal: rs(subtotal),
    discount: rs(disc),
    taxable: rs(taxable),
    cgst: rs(cgst),
    sgst: rs(sgst),
    igst: rs(igst),
    roundOff: rs(grand - total),
    grand: rs(grand),
  );
}

/// Indian digit grouping with two decimals: 1234567.5 -> 12,34,567.50
String formatInr(num value) {
  final negative = value < 0;
  final fixed = value.abs().toStringAsFixed(2);
  final parts = fixed.split('.');
  var whole = parts[0];
  if (whole.length > 3) {
    var head = whole.substring(0, whole.length - 3);
    final tail = whole.substring(whole.length - 3);
    final groups = <String>[];
    while (head.length > 2) {
      groups.insert(0, head.substring(head.length - 2));
      head = head.substring(0, head.length - 2);
    }
    if (head.isNotEmpty) groups.insert(0, head);
    whole = [...groups, tail].join(',');
  }
  return '${negative ? '-' : ''}$whole.${parts[1]}';
}
