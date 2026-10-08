import 'package:flutter/material.dart';

/// Single source of truth for every color used in the app.
/// No screen should hardcode a Color(0xFF...) literal outside this file —
/// reference these tokens (or a .withValues(alpha: ...) tint of one) instead.
class AppColors {
  // Brand
  static const primary = Color(0xFF1A3C5E); // navy
  static const primaryLight = Color(0xFF3D6690); // lighter navy, for gradients/tints
  static const primaryDark = Color(0xFF0F2740); // deeper navy, for banner/hero gradients
  static const accent = Color(0xFFD4500A); // orange
  static const accentLight = Color(0xFFE8794A); // lighter orange, for gradients/tints

  // Semantic states — pick one of each, use everywhere
  static const success = Color(0xFF1E8E3E);
  static const warning = Color(0xFFFF9800);
  static const error = Color(0xFFF44336);

  // Neutrals
  static const background = Color(0xFFF7F8FA);
  static const cardBg = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF1F2937); // dark grey, not pure black
  static const textSecondary = Color(0xFF6B7280);

  // Kept for backwards-compat call sites — both now resolve to the navy brand color.
  static const sidebar = primary;
  static const teal = primary;
  static const tealDark = primary;

  // External-brand exception: WhatsApp's own green, used only for
  // "open WhatsApp" affordances, never as app chrome.
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
