import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFF1a237e);
  static const primaryLight = Color(0xFF3949ab);
  static const accent = Color(0xFFFF6B35);
  static const accentLight = Color(0xFFFF8A50);
  static const success = Color(0xFF4CAF50);
  static const warning = Color(0xFFFF9800);
  static const error = Color(0xFFF44336);
  static const background = Color(0xFFF5F6FA);
  static const cardBg = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF1a237e);
  static const textSecondary = Color(0xFF757575);
  static const sidebar = Color(0xFF0D1B5E);
  static const teal = Color(0xFF00BFA5);
  static const tealDark = Color(0xFF00897B);
  static const whatsapp = Color(0xFF25D366);

  static const gradientNavy = LinearGradient(
    colors: [primary, primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const gradientOrange = LinearGradient(
    colors: [accent, accentLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
