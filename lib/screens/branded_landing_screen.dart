import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/brand_provider.dart';

/// Public, branded entry for a slug URL (e.g. /ekhilakshya).
/// Shows the institute's name + brand color and Student / Staff entry cards.
class BrandedLandingScreen extends StatefulWidget {
  final String slug;
  const BrandedLandingScreen({super.key, required this.slug});

  @override
  State<BrandedLandingScreen> createState() => _BrandedLandingScreenState();
}

class _BrandedLandingScreenState extends State<BrandedLandingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BrandProvider>().loadBySlug(widget.slug);
    });
  }

  @override
  Widget build(BuildContext context) {
    final brand = context.watch<BrandProvider>();
    const bg = Color(0xFF1A1A2E);

    if (brand.loading) {
      return const Scaffold(
        backgroundColor: bg,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (!brand.hasBrand || brand.slug != widget.slug) {
      return Scaffold(
        backgroundColor: bg,
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.search_off_rounded, color: Colors.white54, size: 56),
            const SizedBox(height: 12),
            Text('Institute not found',
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 18)),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => context.go('/'),
              child: const Text('Go to AltrobyteLab'),
            ),
          ]),
        ),
      );
    }

    final color = brand.color;
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                            color: color.withValues(alpha: 0.4),
                            blurRadius: 24,
                            offset: const Offset(0, 8)),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        brand.name.trim().isNotEmpty
                            ? brand.name.trim()[0].toUpperCase()
                            : 'A',
                        style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 40,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(brand.name,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.bold)),
                  if ((brand.tagline ?? '').isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(brand.tagline!,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                            color: Colors.white70, fontSize: 14)),
                  ],
                  const SizedBox(height: 40),
                  _EntryCard(
                    color: color,
                    icon: Icons.school_rounded,
                    title: 'Student',
                    subtitle: 'Tests, results & attendance',
                    onTap: () => context.go('/student/login'),
                  ),
                  const SizedBox(height: 14),
                  _EntryCard(
                    color: color,
                    icon: Icons.badge_rounded,
                    title: 'Staff',
                    subtitle: 'Teachers & managers',
                    onTap: () => context.go('/manager/login'),
                  ),
                  const SizedBox(height: 28),
                  Text('Powered by AltrobyteLab',
                      style: GoogleFonts.inter(
                          color: Colors.white38, fontSize: 11)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _EntryCard({
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600)),
                    Text(subtitle,
                        style: GoogleFonts.inter(
                            color: Colors.white60, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white38),
            ],
          ),
        ),
      ),
    );
  }
}
