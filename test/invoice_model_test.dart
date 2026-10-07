// Parses JSON captured from the real backend (test/fixtures/*.json, produced by
// running altrocoach-backend's invoices.py against PostgreSQL), so a renamed
// field on either side fails here rather than showing up as a blank screen.

import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:altrobytelab/models/invoice_model.dart';

Map<String, dynamic> fixture(String name) =>
    jsonDecode(File('test/fixtures/$name.json').readAsStringSync()) as Map<String, dynamic>;

void main() {
  test('invoice detail: every field the screens read is present and typed', () {
    final inv = Invoice.fromJson(fixture('invoice_detail'));
    expect(inv.invoiceNo, matches(RegExp(r'^FX/\d{4}-\d{2}/\d{4}$')));
    expect(inv.customerName, 'Fixture Customer');
    expect(inv.interState, isTrue); // Maharashtra vs Madhya Pradesh
    expect(inv.igstTotal, greaterThan(0));
    expect(inv.cgstTotal + inv.sgstTotal, 0);
    expect(inv.items.length, 2);
    expect(inv.items.first.qty, 2);
    expect(inv.items.last.gstRate, 5);
    expect(inv.payments.length, 1);
    expect(inv.payments.single.amount, 300);
    expect(inv.payments.single.mode, 'UPI');
    expect(inv.status, 'partial');
    expect(inv.isOverdue, isTrue); // due 2020
    expect(inv.balance, closeTo(inv.grandTotal - 300, 1e-9));
    expect(inv.shareUrl, contains('/inv/'));
    expect(inv.canEdit, isFalse); // a payment is recorded
    expect(inv.taxableTotal + inv.igstTotal + inv.roundOff, closeTo(inv.grandTotal, 1e-9));
  });

  test('invoice list and summary', () {
    final data = fixture('invoice_list');
    final list = [for (final i in data['invoices'] as List) Invoice.fromJson(Map<String, dynamic>.from(i))];
    expect(list, isNotEmpty);
    final s = InvoiceSummary.fromJson(Map<String, dynamic>.from(data['summary']));
    expect(s.billed, greaterThan(0));
    expect(s.outstanding, closeTo(s.billed - s.collected, 1e-9));
    expect(s.overdue, greaterThan(0));
  });

  test('settings round-trip keeps every field the server sent', () {
    final raw = fixture('invoice_settings');
    final s = InvoiceSettings.fromJson(raw);
    expect(s['business_name'], 'Altrobyte Automation');
    expect(s['gstin'], '23ABCDE1234F1Z5');
    expect(s.hasGstin, isTrue);
    expect(s.hasUpi, isTrue);
    expect(s.defaultGstRate, 18);
    final back = s.toJson();
    for (final f in InvoiceSettings.textFields) {
      expect(back.containsKey(f), isTrue, reason: f);
      expect(raw.containsKey(f), isTrue, reason: 'server no longer sends $f');
    }
  });

  test('a blank institute gets 18% and no GSTIN', () {
    final s = InvoiceSettings.fromJson({'default_gst_rate': null});
    expect(s.defaultGstRate, 18);
    expect(s.hasGstin, isFalse);
  });
}
