import 'package:intl/intl.dart';

class Fmt {
  static String currency(double v) =>
      '₹${NumberFormat('#,##,###').format(v)}';

  static String date(String? s) {
    if (s == null || s.isEmpty) return '-';
    try {
      return DateFormat('dd MMM yyyy').format(DateTime.parse(s));
    } catch (_) {
      return s;
    }
  }

  static String dateTime(DateTime? dt) {
    if (dt == null) return '-';
    return DateFormat('dd MMM, hh:mm a').format(dt);
  }

  static String pct(double v) => '${v.toStringAsFixed(1)}%';

  static String shortDate() =>
      DateFormat('yyyy-MM-dd').format(DateTime.now());

  static String displayDate(DateTime dt) =>
      DateFormat('EEEE, dd MMMM yyyy').format(dt);
}
