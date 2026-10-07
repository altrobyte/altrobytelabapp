// WhatsApp message + click-to-chat link for sharing an invoice.

/// Digits-only number with a country code, or null if it cannot be one.
/// A bare 10-digit Indian mobile gets 91; a leading 0 is dropped.
String? whatsappNumber(String raw) {
  var digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('00')) digits = digits.substring(2);
  if (digits.length == 11 && digits.startsWith('0')) digits = digits.substring(1);
  if (digits.length == 10) return '91$digits';
  if (digits.length >= 11 && digits.length <= 15) return digits;
  return null;
}

String invoiceShareMessage({
  required String customerName,
  required String invoiceNo,
  required String businessName,
  required double total,
  required double balance,
  required String shareUrl,
  String? dueDate,
}) {
  String inr(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
  final b = StringBuffer('Hello $customerName,\n\n');
  b.write('Here is your invoice $invoiceNo from $businessName for Rs. ${inr(total)}.');
  if (balance > 0) {
    b.write('\nBalance due: Rs. ${inr(balance)}');
    if (dueDate != null && dueDate.isNotEmpty) b.write(' (by $dueDate)');
    b.write('.\nYou can pay by scanning the UPI QR on the invoice.');
  } else {
    b.write('\nThis invoice is fully paid. Thank you!');
  }
  b.write('\n\nView / download: $shareUrl');
  return b.toString();
}

/// wa.me link to the customer when their number is usable, otherwise the
/// WhatsApp share picker so the admin can choose a chat.
Uri whatsappLink({String phone = '', required String message}) {
  final number = whatsappNumber(phone);
  return number == null
      ? Uri.parse('https://wa.me/').replace(queryParameters: {'text': message})
      : Uri.parse('https://wa.me/$number').replace(queryParameters: {'text': message});
}
