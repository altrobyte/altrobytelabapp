import 'package:flutter_test/flutter_test.dart';
import 'package:altrobytelab/utils/invoice_share.dart';

void main() {
  group('whatsappNumber', () {
    test('adds 91 to a bare 10-digit mobile', () => expect(whatsappNumber('98765 43210'), '919876543210'));
    test('keeps an existing country code', () => expect(whatsappNumber('+91 98765-43210'), '919876543210'));
    test('drops a leading 0', () => expect(whatsappNumber('09876543210'), '919876543210'));
    test('handles 00 international prefix', () => expect(whatsappNumber('0091 9876543210'), '919876543210'));
    test('rejects junk and too-short numbers', () {
      expect(whatsappNumber(''), isNull);
      expect(whatsappNumber('12345'), isNull);
      expect(whatsappNumber('abc'), isNull);
    });
  });

  group('message', () {
    test('unpaid invoice mentions balance, due date and the link', () {
      final m = invoiceShareMessage(
          customerName: 'Rahul',
          invoiceNo: 'INV/2026-27/0001',
          businessName: 'Altrobyte Lab',
          total: 1180,
          balance: 680,
          shareUrl: 'https://altrobytelab.com/inv/abc',
          dueDate: '14 Oct 2026');
      expect(m, contains('INV/2026-27/0001'));
      expect(m, contains('Rs. 1180'));
      expect(m, contains('Balance due: Rs. 680 (by 14 Oct 2026)'));
      expect(m, contains('https://altrobytelab.com/inv/abc'));
    });

    test('paid invoice says so and does not ask for payment', () {
      final m = invoiceShareMessage(
          customerName: 'Rahul', invoiceNo: 'X', businessName: 'B', total: 99.5, balance: 0, shareUrl: 'u');
      expect(m, contains('fully paid'));
      expect(m, isNot(contains('Balance due')));
      expect(m, contains('Rs. 99.50'));
    });
  });

  group('whatsappLink', () {
    test('goes to the customer when the number is valid', () {
      final u = whatsappLink(phone: '9876543210', message: 'hi there');
      expect(u.path, '/919876543210');
      expect(u.queryParameters['text'], 'hi there');
    });
    test('falls back to the picker when there is no number', () {
      final u = whatsappLink(phone: '', message: 'hi');
      expect(u.path, '/');
      expect(u.queryParameters['text'], 'hi');
    });
  });
}
