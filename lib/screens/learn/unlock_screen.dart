import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../constants/app_colors.dart';
import '../../services/api_service.dart';

/// Every way to go further after the free week, on one page (29 Oct 2026, founder).
///
/// Laid out for the decision: the premium programmes first, the ₹29,000 live programme beside the ₹58,000 and ₹98,000
/// ones so it reads as the sensible choice; then the plans that fit a ₹2–5k budget; then the lab kits and the team
/// options. The live programme books a seat online (₹999, adjusted in the fee); every other choice opens a WhatsApp
/// chat with the team on 72229 77927 with the choice written in. Each tap is counted for the funnel (by plan, not by
/// person).
class _Offer {
  final String title, price, line;
  final IconData icon;
  final String? badge;
  final String? link;          // a page of ours instead of WhatsApp
  final String? linkLabel;
  const _Offer(this.title, this.price, this.line, this.icon, {this.badge, this.link, this.linkLabel});
}

const _premium = [
  _Offer('Product engineer: programme, lab and Jarvis', '₹98,000',
      'The live programme with the complete Iron Man 3 lab, Jarvis and Altron at home.', Icons.auto_awesome_rounded),
  _Offer('Placement programme with lab (6 months)', '₹58,000', 'Premium internship, lab setup and placement support.',
      Icons.work_rounded),
  _Offer('Live product engineering programme', '₹29,000',
      'Live classes with industry engineers, your lab kit from day one, four real products. Or ₹9,999 a month.',
      Icons.groups_rounded,
      badge: 'Best value', link: '/enroll/program-enrolment?plan=token', linkLabel: 'Book my seat · ₹999'),
];

const _budget = [
  // ₹4,999 with a live class every week (30 Oct 2026, founder; it was ₹1,999 without one).
  _Offer('Self-paced with Altron AI', '₹4,999 / month', 'Every module and recorded lecture, Altron explaining each one by voice, and a live class every week.',
      Icons.record_voice_over_rounded, badge: 'Most affordable'),
  _Offer('Lab at home', 'from ₹4,000', 'Your own kit, so every lesson is done on real hardware.', Icons.home_work_rounded),
  _Offer('Learn with an industry expert', 'from ₹8,800 / month', 'Live classes and reviews from engineers who build products.',
      Icons.school_rounded),
];

const _labs = [
  _Offer('Mini lab', '₹4,800', 'The starter kit for the beginner levels.', Icons.memory_rounded),
  _Offer('Developer lab', '₹8,800', 'Sensors, displays and boards for the full IoT track.', Icons.developer_board_rounded),
  _Offer('Iron Man 1', '₹28,000', 'Advanced lab for industrial projects.', Icons.precision_manufacturing_rounded),
  _Offer('Iron Man 3 with Jarvis', '₹48,000', 'The advanced lab with the Jarvis voice assistant.', Icons.smart_toy_rounded),
  _Offer('Iron Man 3 with Jarvis and Altron', '₹98,000', 'The complete lab, with Jarvis and Altron, our AI trainer.',
      Icons.auto_awesome_rounded),
];

const _teams = [
  _Offer('Dedicated 1:1 industrial training', '₹2,800 / hour', 'A trainer only for you, on your goals and your project.',
      Icons.person_rounded),
  _Offer('Corporate training', '₹4,000–5,000 / hour', 'For teams: embedded, IoT and edge AI, shaped to your products.',
      Icons.business_rounded),
  _Offer('Lab for an institute', 'from ₹1,18,000', 'A full embedded and IoT lab set up at your college.', Icons.account_balance_rounded),
];

class UnlockScreen extends StatefulWidget {
  const UnlockScreen({super.key});

  @override
  State<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends State<UnlockScreen> {
  @override
  void initState() {
    super.initState();
    ApiService.funnel('unlock_view');
  }

  void _choose(_Offer o) {
    ApiService.funnel('plan_click', o.title);
    if (o.link != null) {
      launchUrl(Uri.parse(o.link!), webOnlyWindowName: '_self');
      return;
    }
    launchUrl(
        Uri.parse('https://wa.me/917222977927')
            .replace(queryParameters: {'text': 'Hi, I would like "${o.title}" (${o.price}). Please tell me how to start.'}),
        mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Text('Unlock Altrobyte', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 20, 16, 40), children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Go as far as you want',
                  style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 6),
              Text('Pick how you want to carry on. Not sure? Our team answers on WhatsApp and helps you choose.',
                  style: GoogleFonts.inter(fontSize: 14.5, color: AppColors.textSecondary, height: 1.5)),
              const SizedBox(height: 20),
              _section('Premium programmes', 'Learn live with engineers and build real products.', _premium),
              const SizedBox(height: 26),
              _section('Learn at your pace', 'Start small and grow into it.', _budget),
              const SizedBox(height: 26),
              _section('Lab packages', 'Real hardware for every level.', _labs),
              const SizedBox(height: 26),
              _section('For professionals, companies and colleges', '', _teams),
              const SizedBox(height: 24),
              Center(
                child: TextButton.icon(
                    onPressed: () => context.go('/learn'),
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('Back to the roadmap')),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _section(String title, String line, List<_Offer> offers) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primary)),
          if (line.isNotEmpty) Text(line, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          LayoutBuilder(builder: (context, c) {
            final cols = c.maxWidth > 820 ? 3 : (c.maxWidth > 520 ? 2 : 1);
            final w = (c.maxWidth - (cols - 1) * 14) / cols;
            return Wrap(spacing: 14, runSpacing: 14, children: [for (final o in offers) SizedBox(width: w, child: _card(o))]);
          }),
        ],
      );

  Widget _card(_Offer o) {
    final hot = o.badge != null;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: hot ? AppColors.accent : const Color(0xFFE5E7EB), width: hot ? 2 : 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(o.icon, color: hot ? AppColors.accent : AppColors.primary),
          const Spacer(),
          if (hot)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(20)),
              child: Text(o.badge!, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
            ),
        ]),
        const SizedBox(height: 10),
        SizedBox(
            height: 40,
            child: Text(o.title,
                maxLines: 2, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
        const SizedBox(height: 4),
        Text(o.price, style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.primary)),
        const SizedBox(height: 6),
        SizedBox(
            height: 56,
            child: Text(o.line, maxLines: 3, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary, height: 1.4))),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: hot
              ? FilledButton(
                  onPressed: () => _choose(o),
                  style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
                  child: Text(o.linkLabel ?? 'Get this'))
              : OutlinedButton(onPressed: () => _choose(o), child: Text(o.linkLabel ?? 'Ask about this')),
        ),
      ]),
    );
  }
}
