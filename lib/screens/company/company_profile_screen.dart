import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../constants/app_colors.dart';
import '../../services/api_service.dart';

const _navTiles = [
  ('About Company', Icons.info_outline_rounded, '/about', AppColors.primary),
  ('Founder & Team', Icons.groups_rounded, '/founder', AppColors.accent),
  ('Services', Icons.design_services_rounded, '/services', AppColors.primary),
  ('Products', Icons.widgets_rounded, '/products', AppColors.accent),
  ('Placed Profiles', Icons.emoji_events_rounded, '/placements', AppColors.primary),
  ('Affiliated Institutes', Icons.school_rounded, '/institutes', AppColors.accent),
  ('Clients', Icons.handshake_rounded, '/clients', AppColors.primary),
  ('Blog', Icons.article_rounded, '/blog', AppColors.accent),
  ('About the App', Icons.phone_iphone_rounded, '/about-app', AppColors.primary),
];

/// Public, no-login, SEO-friendly company marketing site home — the hub
/// linking to every other company-profile page. Route: /company
class CompanyProfileScreen extends StatefulWidget {
  const CompanyProfileScreen({super.key});

  @override
  State<CompanyProfileScreen> createState() => _CompanyProfileScreenState();
}

class _CompanyProfileScreenState extends State<CompanyProfileScreen> {
  List<dynamic> _stats = [];
  Map<String, dynamic> _links = {};
  Map<String, dynamic>? _homePage;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        ApiService.getCompanyStats(),
        ApiService.getCompanySocialLinks(),
        ApiService.getCompanyPage('home'),
      ]);
      if (!mounted) return;
      setState(() {
        _stats = results[0] as List;
        _links = results[1] as Map<String, dynamic>;
        _homePage = results[2] as Map<String, dynamic>;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openLink(String url) async {
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(slivers: [
              SliverToBoxAdapter(child: _Hero(tagline: _homePage?['title'] as String? ?? 'AltrobyteLab')),
              if (_stats.isNotEmpty) SliverToBoxAdapter(child: _StatsRow(stats: _stats)),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: Text('Explore', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.5,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final (label, icon, route, color) = _navTiles[i];
                      return _NavTile(label: label, icon: icon, color: color, onTap: () => context.push(route));
                    },
                    childCount: _navTiles.length,
                  ),
                ),
              ),
              SliverToBoxAdapter(child: _SocialFooter(links: _links, onOpen: _openLink)),
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ]),
    );
  }
}

class _Hero extends StatelessWidget {
  final String tagline;
  const _Hero({required this.tagline});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 40),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [AppColors.primary, AppColors.primaryDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset('assets/images/logo.png', width: 44, height: 44, fit: BoxFit.cover),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text('AltrobyteLab', style: GoogleFonts.poppins(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () => context.push('/pricing'),
            child: Text('Pricing', style: GoogleFonts.inter(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 4),
          OutlinedButton(
            onPressed: () => context.push('/partner'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white38),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Partner With Us', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600)),
          ),
        ]),
        const SizedBox(height: 16),
        Text('Learn. Build. Compete in Deeptech.',
            style: GoogleFonts.poppins(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700, height: 1.3)),
        const SizedBox(height: 8),
        Text('Embedded systems, IoT, and hardware training — for students, colleges and industry.',
            style: GoogleFonts.inter(color: Colors.white70, fontSize: 14)),
      ]),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final List<dynamic> stats;
  const _StatsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: stats.map((s) {
            final m = s as Map<String, dynamic>;
            return Container(
              width: 140,
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
              decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(14)),
              child: Column(children: [
                Text(m['value'] as String? ?? '', style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primary)),
                const SizedBox(height: 4),
                Text(m['label'] as String? ?? '', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
              ]),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _NavTile({required this.label, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 10),
            Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12.5)),
          ]),
        ),
      ),
    );
  }
}

class _SocialFooter extends StatelessWidget {
  final Map<String, dynamic> links;
  final void Function(String) onOpen;
  const _SocialFooter({required this.links, required this.onOpen});

  IconData _iconFor(String platform) {
    switch (platform) {
      case 'instagram': return Icons.camera_alt_rounded;
      case 'youtube': return Icons.play_circle_fill_rounded;
      case 'linkedin': return Icons.business_center_rounded;
      case 'twitter': return Icons.alternate_email_rounded;
      case 'facebook': return Icons.facebook_rounded;
      default: return Icons.link_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = links.entries.where((e) => (e.value as String? ?? '').isNotEmpty).toList();
    if (active.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Column(children: [
        Text('Follow AltrobyteLab', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          children: active.map((e) => IconButton(
            onPressed: () => onOpen(e.value as String),
            icon: Icon(_iconFor(e.key), color: AppColors.primary),
            style: IconButton.styleFrom(backgroundColor: AppColors.primary.withValues(alpha: 0.08)),
          )).toList(),
        ),
      ]),
    );
  }
}
