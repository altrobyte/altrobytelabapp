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

  /// The name to greet someone by, from whatever they saved as their display
  /// name.
  ///
  /// Students often append a tagline — "Pawan Meena : Electroholic Engineer" —
  /// which reads badly after "Hi,". The tagline is theirs and stays on the
  /// profile; only the greeting is shortened. Hyphens and apostrophes are
  /// never separators, so Anne-Marie and D'Souza survive intact.
  static String greetingName(String? full, {String fallback = 'Student'}) {
    var s = (full ?? '').trim();
    for (final sep in [':', '|', ',', '(', '–', '—']) {
      if (s.contains(sep)) {
        final head = s.split(sep).first.trim();
        if (head.length >= 2) s = head;
      }
    }
    return s.isEmpty ? fallback : s;
  }
}
