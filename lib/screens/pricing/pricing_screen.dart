import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../services/api_service.dart';

/// Public pricing page — Free / Student Pro / Institution / Industry.
/// All copy (price labels, features) comes from the DB, admin-editable
/// without a code deploy.
class PricingScreen extends StatefulWidget {
  const PricingScreen({super.key});

  @override
  State<PricingScreen> createState() => _PricingScreenState();
}

class _PricingScreenState extends State<PricingScreen> {
  List<dynamic> _plans = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _plans = await ApiService.getSubscriptionPlans();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text('Pricing', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                Text('Choose the plan that fits you',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 24), textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text('Simple pricing for students, institutions and industry partners',
                    style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 14), textAlign: TextAlign.center),
                const SizedBox(height: 28),
                Wrap(
                  spacing: 20, runSpacing: 20, alignment: WrapAlignment.center,
                  children: _plans.map((p) => _PlanCard(plan: p)).toList(),
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () => context.push('/partner'),
                  child: Text('Need Institution or Industry pricing? Talk to us →',
                      style: GoogleFonts.inter(color: AppColors.accent, fontWeight: FontWeight.w600)),
                ),
              ]),
            ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final Map<String, dynamic> plan;
  const _PlanCard({required this.plan});

  @override
  Widget build(BuildContext context) {
    final highlighted = plan['is_highlighted'] == true;
    final features = List<String>.from(plan['features'] ?? []);
    return Container(
      width: 280,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: highlighted ? AppColors.primary : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: highlighted ? AppColors.primary : Colors.grey.withValues(alpha: 0.15)),
        boxShadow: highlighted
            ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.25), blurRadius: 20, offset: const Offset(0, 8))]
            : null,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(plan['display_name'] ?? '',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16,
                color: highlighted ? Colors.white : AppColors.textPrimary)),
        const SizedBox(height: 12),
        Text(plan['price_label'] ?? '',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 26,
                color: highlighted ? Colors.white : AppColors.textPrimary)),
        if ((plan['billing_note'] ?? '').isNotEmpty)
          Text(plan['billing_note'],
              style: GoogleFonts.inter(fontSize: 12, color: highlighted ? Colors.white70 : AppColors.textSecondary)),
        const SizedBox(height: 18),
        Divider(color: highlighted ? Colors.white24 : Colors.grey.withValues(alpha: 0.2)),
        const SizedBox(height: 12),
        ...features.map((f) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.check_circle_rounded, size: 16,
                color: highlighted ? AppColors.accent : AppColors.success),
            const SizedBox(width: 8),
            Expanded(
              child: Text(f, style: GoogleFonts.inter(fontSize: 12.5, height: 1.4,
                  color: highlighted ? Colors.white70 : AppColors.textPrimary)),
            ),
          ]),
        )),
      ]),
    );
  }
}
