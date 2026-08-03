import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../services/api_service.dart';
import '../../widgets/html_view.dart';

/// Public, no-login page for a single long-form HTML company_pages row
/// (About the Company, About the Founder & Team, About the App).
class CompanyPageViewScreen extends StatefulWidget {
  final String slug;
  final String fallbackTitle;
  const CompanyPageViewScreen({super.key, required this.slug, required this.fallbackTitle});

  @override
  State<CompanyPageViewScreen> createState() => _CompanyPageViewScreenState();
}

class _CompanyPageViewScreenState extends State<CompanyPageViewScreen> {
  Map<String, dynamic>? _page;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final page = await ApiService.getCompanyPage(widget.slug);
      if (mounted) setState(() { _page = page; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop() ? context.pop() : context.go('/company'),
        ),
        title: Text(_page?['title'] ?? widget.fallbackTitle,
            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Failed to load page', style: GoogleFonts.inter(color: AppColors.textSecondary)))
              : ((_page?['html_content'] as String?)?.isEmpty ?? true)
                  ? Center(
                      child: Text('Content coming soon.',
                          style: GoogleFonts.inter(color: AppColors.textSecondary)))
                  : HtmlView(html: _page!['html_content'] as String, fontSize: 16),
    );
  }
}
