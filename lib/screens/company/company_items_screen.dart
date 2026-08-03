import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../constants/app_colors.dart';
import '../../services/api_service.dart';

/// Public, no-login card grid for one company_items category (Team,
/// Placed Profiles, Affiliated Institutes, Clients, Services, Products,
/// Blog) — one reusable screen instead of seven near-identical ones.
class CompanyItemsScreen extends StatefulWidget {
  final String category;
  final String title;
  final IconData icon;
  const CompanyItemsScreen({super.key, required this.category, required this.title, required this.icon});

  @override
  State<CompanyItemsScreen> createState() => _CompanyItemsScreenState();
}

class _CompanyItemsScreenState extends State<CompanyItemsScreen> {
  List<dynamic> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await ApiService.getCompanyItems(category: widget.category);
      if (mounted) setState(() { _items = items; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop() ? context.pop() : context.go('/company'),
        ),
        title: Row(children: [
          Icon(widget.icon, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Text(widget.title,
              style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
        ]),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Failed to load', style: GoogleFonts.inter(color: AppColors.textSecondary)))
              : _items.isEmpty
                  ? Center(
                      child: Text('Coming soon.', style: GoogleFonts.inter(color: AppColors.textSecondary)))
                  : LayoutBuilder(builder: (context, constraints) {
                      final cols = constraints.maxWidth > 900 ? 3 : (constraints.maxWidth > 560 ? 2 : 1);
                      return GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cols,
                          mainAxisSpacing: 14,
                          crossAxisSpacing: 14,
                          childAspectRatio: 1.5,
                        ),
                        itemCount: _items.length,
                        itemBuilder: (context, i) => _ItemCard(item: _items[i] as Map<String, dynamic>),
                      );
                    }),
    );
  }
}

class _ItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  const _ItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final imageUrl = item['image_url'] as String? ?? '';
    final linkUrl = item['link_url'] as String? ?? '';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: linkUrl.isEmpty
            ? null
            : () async {
                final uri = Uri.tryParse(linkUrl);
                if (uri != null && await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              if (imageUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(imageUrl, width: 44, height: 44, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholderAvatar()),
                )
              else
                _placeholderAvatar(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(item['title'] as String? ?? '',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  if ((item['subtitle'] as String? ?? '').isNotEmpty)
                    Text(item['subtitle'] as String,
                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.primary),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                ]),
              ),
            ]),
            if ((item['description'] as String? ?? '').isNotEmpty) ...[
              const SizedBox(height: 10),
              Expanded(
                child: Text(item['description'] as String,
                    style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textSecondary, height: 1.5),
                    maxLines: 4, overflow: TextOverflow.ellipsis),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _placeholderAvatar() => Container(
        width: 44, height: 44,
        decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
        child: const Icon(Icons.business_rounded, color: AppColors.primary, size: 20),
      );
}
