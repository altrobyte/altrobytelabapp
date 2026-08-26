import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

class StatRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool locked;
  const StatRow({
    required this.icon,
    required this.label,
    required this.value,
    this.locked = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final color = locked ? Colors.grey : AppColors.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(locked ? Icons.lock_rounded : icon, size: 18, color: color),
          const SizedBox(width: 10),
          Text('$label: ',
              style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          Expanded(
            child: Text(value,
                style: GoogleFonts.inter(
                    fontSize: 13,
                    fontStyle: locked ? FontStyle.italic : FontStyle.normal,
                    color: locked ? Colors.grey : AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet shown when a student hits the daily free-quiz limit.
/// [lastResult] (optional) shows the score from the most recent attempt.
/// [onPaymentOpened] is called once the Cashfree payment page has been
/// launched, so the caller can start polling for activation.
///
/// Sells the Plus tier only — one decision at the moment someone is blocked.
/// Elite and the full comparison live on `/pricing`, one tap away.
class UpgradeSheet extends StatefulWidget {
  final Map<String, dynamic>? lastResult;
  final VoidCallback onPaymentOpened;
  final int premiumPrice;
  const UpgradeSheet({
    required this.lastResult,
    required this.onPaymentOpened,
    this.premiumPrice = 999,
    super.key,
  });

  @override
  State<UpgradeSheet> createState() => _UpgradeSheetState();
}

class _UpgradeSheetState extends State<UpgradeSheet> {

  @override
  Widget build(BuildContext context) {
    final score = widget.lastResult?['score'];
    final total = widget.lastResult?['total'];

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text("You've used today's free quizzes",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          if (score != null && total != null)
            StatRow(
              icon: Icons.emoji_events_rounded,
              label: 'Score',
              value: '$score/$total',
            ),
          const StatRow(
            icon: Icons.leaderboard_rounded,
            label: 'Class Rank',
            value: '#?? — unlock with Plus',
            locked: true,
          ),
          const StatRow(
            icon: Icons.psychology_alt_rounded,
            label: 'Weak Topic',
            value: '?? — unlock with Plus',
            locked: true,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: AppColors.gradientOrange,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text('₹${widget.premiumPrice}',
                    style: GoogleFonts.poppins(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text('/month',
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.9))),
                ),
                const Spacer(),
                // No tier is uncapped, so this must not promise "unlimited".
                Text('20 quiz attempts\nper day',
                    textAlign: TextAlign.right,
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              // Straight to /pricing, not into checkout from here.
              //
              // This sheet showed one tier and one price and asked for money.
              // Somebody deciding whether to pay wants to see what the other
              // tiers give and what they are giving up by not taking them —
              // and that comparison already exists, in full, on the pricing
              // page. Two half-explanations of the same plans is how they
              // drift apart.
              onPressed: () {
                Navigator.pop(context);
                context.push('/pricing');
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('See plans & upgrade',
                  style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white)),
            ),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Maybe later',
                style: GoogleFonts.inter(color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }
}
