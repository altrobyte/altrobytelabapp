class Validators {
  static String? required(String? v, [String label = 'This field']) {
    if (v == null || v.trim().isEmpty) return '$label is required';
    return null;
  }

  static String? phone(String? v) {
    if (v == null || v.isEmpty) return null;
    if (!RegExp(r'^\d{10}$').hasMatch(v)) return 'Enter valid 10-digit phone';
    return null;
  }

  static String? email(String? v) {
    if (v == null || v.isEmpty) return null;
    if (!RegExp(r'^[\w.-]+@[\w.-]+\.\w+$').hasMatch(v)) return 'Enter valid email';
    return null;
  }

  static String? amount(String? v) {
    if (v == null || v.isEmpty) return 'Amount required';
    if (double.tryParse(v) == null || double.parse(v) <= 0) {
      return 'Enter valid amount';
    }
    return null;
  }
}
