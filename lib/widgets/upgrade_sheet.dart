import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import '../services/api_service.dart';
import '../services/cashfree_checkout.dart';

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
  bool _paying = false;

  Future<void> _upgradeNow() async {
    setState(() => _paying = true);
    try {
      final res = await ApiService.createStudentSubscriptionLink(plan: '999');
      if (res['already_active'] == true) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Your plan is already active!')),
          );
        }
        return;
      }
      // payment_session_id + the JS Checkout SDK is the only path that works
      // — Cashfree's Orders API returns no navigable link_url, and a raw
      // redirect to their hosted page is rejected as "client session is
      // invalid" (same as live-session registration).
      final sessionId = (res['payment_session_id'] ?? '').toString();
      if (sessionId.isNotEmpty) {
        CashfreeCheckout.open(
          paymentSessionId: sessionId,
          mode: (res['cashfree_mode'] ?? 'production').toString(),
        );
        widget.onPaymentOpened();
        if (mounted) Navigator.pop(context);
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open payment page. Please try again.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
        );
      }
    }
    if (mounted) setState(() => _paying = false);
  }

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
                Text('Unlimited\nquiz attempts',
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
              onPressed: _paying ? null : _upgradeNow,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: _paying
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text('Upgrade to Plus',
                      style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white)),
            ),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.push('/pricing');
            },
            child: Text('Compare all plans',
                style: GoogleFonts.inter(
                    color: AppColors.accent, fontWeight: FontWeight.w600)),
          ),
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
