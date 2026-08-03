import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/api_service.dart';

/// Holds the per-institute PWA branding loaded from a slug URL
/// (e.g. /ekhilakshya). Used to brand the pre-login experience.
class BrandProvider extends ChangeNotifier {
  Map<String, dynamic>? _brand;
  bool loading = false;
  String? error;

  Map<String, dynamic>? get brand => _brand;
  bool get hasBrand => _brand != null;
  String get name => (_brand?['name'] ?? 'AltrobyteLab').toString();
  String? get slug => _brand?['slug']?.toString();
  String? get instituteCode => _brand?['institute_code']?.toString();
  String? get tagline => _brand?['tagline']?.toString();
  int? get instituteId => _brand?['id'] as int?;

  Color get color {
    final hex = (_brand?['brand_color'] ?? 'D4500A').toString().replaceAll('#', '');
    try {
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return AppColors.accent;
    }
  }

  Future<void> loadBySlug(String slug) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      _brand = await ApiService.getBrand(slug);
    } catch (e) {
      error = e.toString();
      _brand = null;
    }
    loading = false;
    notifyListeners();
  }
}
