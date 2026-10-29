import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../constants/app_colors.dart';

/// Every way to go further after the free modules, on one page (29 Oct 2026, founder: the whole ladder side by side,
/// so ₹1,999 reads small next to the rest). Each choice opens a WhatsApp chat with the team on 72229 77927, with the
/// choice written in; payment is taken there until a self-serve plan exists for it.
class _Offer {
  final String title, price, line;
  final IconData icon;
  final bool best;
  const _Offer(this.title, this.price, this.line, this.icon, {this.best = false});
}

const _learn = [
  _Offer('Self-paced with Altron AI', '₹1,999', 'Every module and lesson, with Altron explaining each one to you by voice.',
      Icons.record_voice_over_rounded, best: true),
  _Offer('Learn with an industry expert', 'from ₹8,800 / month', 'Live classes and reviews from engineers who build products.',
      Icons.groups_rounded),
  _Offer('Lab at home', 'from ₹4,000', 'Your own kit, so every lesson is done on real hardware.', Icons.home_work_rounded),
  _Offer('Placement programme with lab (6 months)', '₹58,000', 'Premium internship, lab setup and placement support.',
      Icons.work_rounded),
  _Offer('Dedicated 1:1 industrial training', '₹2,800 / hour', 'A trainer only for you, on your goals and your project.',
      Icons.person_rounded),
  _Offer('Corporate training', '₹4,000–5,000 / hour', 'For teams: embedded, IoT and edge AI, shaped to your products.',
      Icons.business_rounded),
];

const _labs = [
  _Offer('Mini lab', '₹4,800', 'The starter kit for the beginner levels.', Icons.memory_rounded),
  _Offer('Developer lab', '₹8,800', 'Sensors, displays and boards for the full IoT track.', Icons.developer_board_rounded),
  _Offer('Iron Man 1', '₹28,000', 'Advanced lab for industrial projects.', Icons.precision_manufacturing_rounded),
  _Offer('Iron Man 3 with Jarvis', '₹48,000', 'The advanced lab with the Jarvis voice assistant.', Icons.smart_toy_rounded),
  _Offer('Iron Man 3 with Jarvis and Altron', '₹98,000', 'The complete lab, with Jarvis and Altron, our AI trainer.',
      Icons.auto_awesome_rounded),
  _Offer('Lab for an institute', 'from ₹1,18,000', 'A full embedded and IoT lab set up at your college.', Icons.school_rounded),
];

class UnlockScreen extends StatelessWidget {
  const UnlockScreen({super.key});

  void _ask(_Offer o) => launchUrl(
      Uri.parse('https://wa.me/917222977927')
          .replace(queryParameters: {'text': 'Hi, I would like "${o.title}" (${o.price}). Please tell me how to start.'}),
      mode: LaunchMode.externalApplication);

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
              Text('You have tried the free modules. Pick how you want to carry on; our team replies on WhatsApp.',
                  style: GoogleFonts.inter(fontSize: 14.5, color: AppColors.textSecondary, height: 1.5)),
              const SizedBox(height: 20),
              _section(context, 'Learning', _learn),
              const SizedBox(height: 26),
              _section(context, 'Lab packages', _labs),
              const SizedBox(height: 24),
              Center(
                child: TextButton.icon(
                    onPressed: () => context.go('/learn'),
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('Back to the free modules')),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _section(BuildContext context, String title, List<_Offer> offers) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primary)),
          const SizedBox(height: 12),
          LayoutBuilder(builder: (context, c) {
            final cols = c.maxWidth > 820 ? 3 : (c.maxWidth > 520 ? 2 : 1);
            final w = (c.maxWidth - (cols - 1) * 14) / cols;
            return Wrap(spacing: 14, runSpacing: 14, children: [for (final o in offers) SizedBox(width: w, child: _card(o))]);
          }),
        ],
      );

  Widget _card(_Offer o) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: o.best ? AppColors.accent : const Color(0xFFE5E7EB), width: o.best ? 2 : 1),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(o.icon, color: o.best ? AppColors.accent : AppColors.primary),
            const Spacer(),
            if (o.best)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(20)),
                child: const Text('Recommended', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
          ]),
          const SizedBox(height: 10),
          Text(o.title, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text(o.price, style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.primary)),
          const SizedBox(height: 6),
          SizedBox(
              height: 40,
              child: Text(o.line, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary, height: 1.4))),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: o.best
                ? FilledButton(
                    onPressed: () => _ask(o),
                    style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
                    child: const Text('Get this'))
                : OutlinedButton(onPressed: () => _ask(o), child: const Text('Ask about this')),
          ),
        ]),
      );
}
