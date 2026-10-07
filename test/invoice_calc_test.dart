// The form's live preview must agree with the server's invoice maths
// (altrocoach-backend/invoice_calc.py). These are the same cases its tests use.

import 'package:flutter_test/flutter_test.dart';
import 'package:altrobytelab/utils/invoice_calc.dart';

InvoiceLineInput line(double rate, {double qty = 1, double gst = 18, String d = 'Course fee'}) =>
    InvoiceLineInput(description: d, qty: qty, rate: rate, gstRate: gst);

void main() {
  test('exclusive, same state: CGST + SGST', () {
    final t = computeInvoiceTotals([line(1000)])!;
    expect(t.taxable, 1000);
    expect(t.cgst, 90);
    expect(t.sgst, 90);
    expect(t.igst, 0);
    expect(t.grand, 1180);
  });

  test('inter-state: IGST only', () {
    final t = computeInvoiceTotals([line(1000)], interState: true)!;
    expect(t.igst, 180);
    expect(t.cgst + t.sgst, 0);
  });

  test('tax-inclusive price backs the tax out', () {
    final t = computeInvoiceTotals([line(1180)], pricesIncludeTax: true)!;
    expect(t.taxable, 1000);
    expect(t.tax, 180);
    expect(t.grand, 1180);
  });

  test('discount reduces the taxable value', () {
    final t = computeInvoiceTotals([line(1000)], discount: 200)!;
    expect(t.taxable, 800);
    expect(t.tax, 144);
    expect(t.grand, 944);
  });

  test('odd tax halves still add up (0.18 -> 0.09 + 0.09, 0.19 -> 0.10 + 0.09)', () {
    final a = computeInvoiceTotals([line(1)])!;
    expect(a.cgst + a.sgst, closeTo(0.18, 1e-9));
    final b = computeInvoiceTotals([line(1, gst: 19)])!;
    expect(b.cgst, closeTo(0.10, 1e-9));
    expect(b.sgst, closeTo(0.09, 1e-9));
  });

  test('totals reconcile with the round-off line', () {
    final t = computeInvoiceTotals(
        [line(999.99, qty: 3, gst: 12, d: 'x'), line(450.50, gst: 5, d: 'y')],
        discount: 37.25)!;
    expect(t.taxable + t.cgst + t.sgst + t.igst + t.roundOff, closeTo(t.grand, 1e-9));
    expect(t.grand, t.grand.roundToDouble());
  });

  test('nothing billable, or an impossible discount, gives no preview', () {
    expect(computeInvoiceTotals([]), isNull);
    expect(computeInvoiceTotals([line(0, qty: 0)]), isNull);
    expect(computeInvoiceTotals([line(100)], discount: 101), isNull);
  });

  test('inter-state needs both states known and different', () {
    expect(isInterState('Madhya Pradesh', 'Maharashtra'), isTrue);
    expect(isInterState('Madhya Pradesh', ' madhya  pradesh '), isFalse);
    expect(isInterState('Madhya Pradesh', ''), isFalse);
    expect(isInterState(null, 'Goa'), isFalse);
  });

  test('Indian digit grouping', () {
    expect(formatInr(1234567.5), '12,34,567.50');
    expect(formatInr(999), '999.00');
    expect(formatInr(100000), '1,00,000.00');
    expect(formatInr(-1500), '-1,500.00');
  });
}
