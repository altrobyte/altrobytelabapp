import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants/app_colors.dart';
import '../../services/api_service.dart';
import '../../services/cashfree_checkout.dart';
import '../../services/google_auth_service.dart';

/// Public pricing page — Free / Plus (₹999) / Elite (₹9999) / Institution /
/// Industry. All copy (price labels, features) comes from the DB, admin-
/// editable without a code deploy.
///
/// The paid tiers are self-serve: `tier_key` doubles as the billing plan id
/// ('999' / '9999'), so the card the student sees is literally the plan the
/// backend charges for. Institution/Industry stay sales-assisted and route
/// to the partner enquiry form.
class PricingScreen extends StatefulWidget {
  const PricingScreen({super.key});

  @override
  State<PricingScreen> createState() => _PricingScreenState();
}

/// tier_keys the backend will actually take money for (`PAID_PLANS` in
/// student_subscriptions.py). Anything else on the pricing page is either
/// free or "talk to us".
const _selfServeTiers = {'999', '9999'};

class _PricingScreenState extends State<PricingScreen> {
  List<dynamic> _plans = [];
  Map<String, dynamic>? _subscription;
  bool _loading = true;

  /// tier_key -> one quote per duration, priced by the server so the page can
  /// never advertise a discount the checkout does not honour.
  Map<String, List<dynamic>> _quotes = {};
  List<int> _durations = const [1];
  int _months = 1;

  Map<String, dynamic>? _quoteFor(String tierKey) {
    for (final q in _quotes[tierKey] ?? const []) {
      if (q['months'] == _months) return Map<String, dynamic>.from(q);
    }
    return null;
  }

  /// Which tier's button is mid-flight, so only that card shows a spinner.
  String? _busyTier;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      _plans = await ApiService.getSubscriptionPlans();
    } catch (_) {}
    try {
      final q = await ApiService.getSubscriptionQuotes();
      _durations = List<int>.from(q['durations'] ?? const [1]);
      _quotes = (q['quotes'] as Map?)?.map(
              (k, v) => MapEntry(k.toString(), List<dynamic>.from(v as List))) ??
          {};
    } catch (_) {
      // Quotes are an enhancement — without them the cards still show the
      // plan's own monthly price_label.
    }
    await _loadSubscription();
    if (mounted) setState(() => _loading = false);
  }

  /// Signed-out visitors just see the plans — the pricing page itself is
  /// public, only subscribing needs an account.
  Future<void> _loadSubscription() async {
    if (!await _isLoggedIn()) {
      _subscription = null;
      return;
    }
    try {
      _subscription = await ApiService.getStudentSubscription();
    } catch (_) {
      _subscription = null;
    }
  }

  Future<bool> _isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('student_token') ?? prefs.getString('token');
    return token != null && token.isNotEmpty;
  }

  String get _activePlan {
    final sub = _subscription;
    if (sub == null) return '';
    final premium = sub['is_premium'] == true;
    return premium ? (sub['plan'] as String? ?? '') : 'free';
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppColors.error : AppColors.success,
    ));
  }

  Future<void> _subscribe(String tierKey, String displayName) async {
    if (!await _isLoggedIn()) {
      final signedIn = await _promptSignIn();
      if (!signedIn) return;
      await _loadSubscription();
      if (mounted) setState(() {});
    }

    // Ask before opening checkout, not after Cashfree rejects the order.
    // Google accounts have no phone of their own — the server stores a
    // placeholder — and Cashfree 400s on it, so the student would otherwise
    // meet a raw payment-gateway error mid-purchase.
    var phone = '';
    if (_subscription?['has_phone'] != true) {
      phone = await _askForPhone() ?? '';
      if (phone.isEmpty) return;
    }

    setState(() => _busyTier = tierKey);
    try {
      final result = await ApiService.createStudentSubscriptionLink(
          plan: tierKey, phone: phone, months: _months);

      // Backend short-circuits when the student already holds this tier (or
      // better) — nothing to pay for, just refresh what we show.
      if (result['already_active'] == true) {
        await _loadSubscription();
        if (!mounted) return;
        setState(() => _busyTier = null);
        _snack('You are already on $displayName.');
        return;
      }

      final sessionId = result['payment_session_id'] as String? ?? '';
      if (sessionId.isEmpty) {
        throw ApiException('Payment could not be started. Please try again.');
      }
      // Cashfree's payment_session_id only works through their JS Checkout
      // SDK — a raw redirect to the hosted page is rejected as "client
      // session is invalid" (same constraint as live-session registration).
      CashfreeCheckout.open(
        paymentSessionId: sessionId,
        mode: result['cashfree_mode'] as String? ?? 'production',
      );
      _startPaymentPolling(displayName);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busyTier = null);
      _snack(e is ApiException ? e.message : 'Could not start payment', error: true);
    }
  }

  /// Payment happens in Cashfree's overlay, which gives us no completion
  /// callback — so poll our own verify endpoint until it flips to paid,
  /// exactly like live-session registration does.
  void _startPaymentPolling(String displayName) {
    _pollTimer?.cancel();
    int attempts = 0;
    const maxAttempts = 36; // 5s × 36 = 3 minutes
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      attempts++;
      if (!mounted || attempts > maxAttempts) {
        timer.cancel();
        if (mounted) setState(() => _busyTier = null);
        return;
      }
      try {
        final result = await ApiService.verifyStudentSubscription();
        if (result['status'] != 'paid') return;
        timer.cancel();
        await _loadSubscription();
        if (!mounted) return;
        setState(() => _busyTier = null);
        _showSuccess(displayName, result['valid_till'] as String?);
      } catch (_) {
        // 400 "No subscription payment found" is expected until Cashfree
        // registers the order — keep polling.
      }
    });
  }

  /// Returns a 10-digit mobile, or null if the student backs out. The number
  /// is saved server-side on the first purchase, so this is asked once.
  Future<String?> _askForPhone() async {
    final ctrl = TextEditingController();
    String? error;
    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => AlertDialog(
          title: Text('Your mobile number',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 17)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Needed for the payment receipt and order updates.',
                style: GoogleFonts.inter(fontSize: 13, height: 1.4)),
            const SizedBox(height: 14),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              decoration: InputDecoration(
                prefixText: '+91 ',
                counterText: '',
                hintText: '10-digit mobile',
                errorText: error,
                border: const OutlineInputBorder(),
              ),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () {
                final v = ctrl.text.replaceAll(RegExp(r'\D'), '');
                // Indian mobile numbers are 10 digits starting 6-9 — the same
                // rule the backend and Cashfree apply, checked here so the
                // student is corrected before a payment is attempted.
                if (v.length != 10 || !RegExp(r'^[6-9]').hasMatch(v)) {
                  setSheetState(() => error = 'Enter a valid 10-digit mobile number');
                  return;
                }
                Navigator.pop(ctx, v);
              },
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _promptSignIn() async {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Sign in to subscribe',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 17)),
        content: Text(
          'Your plan is tied to your account, so you need to sign in before subscribing.',
          style: GoogleFonts.inter(fontSize: 13.5, height: 1.5),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Sign in with Google'),
          ),
        ],
      ),
    );
    if (proceed != true) return false;
    try {
      await GoogleAuthService.signIn();
      return await _isLoggedIn();
    } catch (e) {
      _snack('Sign-in failed. Please try again.', error: true);
      return false;
    }
  }

  void _showSuccess(String displayName, String? validTill) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.verified_rounded, color: AppColors.success, size: 44),
        title: Text('$displayName activated',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 18)),
        content: Text(
          validTill == null
              ? 'Your plan is active. Enjoy!'
              : 'Your plan is active till ${_formatDate(validTill)}.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(fontSize: 13.5, height: 1.5),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  static String _formatDate(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
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
                if (_subscription != null) ...[
                  const SizedBox(height: 16),
                  _CurrentPlanBanner(subscription: _subscription!),
                ],
                if (_durations.length > 1) ...[
                  const SizedBox(height: 20),
                  _DurationSelector(
                    durations: _durations,
                    selected: _months,
                    // Any tier's quote carries the same discount percentage,
                    // so the badge is read off whichever is available.
                    discountFor: (m) {
                      for (final list in _quotes.values) {
                        for (final q in list) {
                          if (q['months'] == m) return (q['discount_pct'] ?? 0) as int;
                        }
                      }
                      return 0;
                    },
                    onChanged: (m) => setState(() => _months = m),
                  ),
                ],
                const SizedBox(height: 28),
                Wrap(
                  spacing: 20, runSpacing: 20, alignment: WrapAlignment.center,
                  children: _plans.map((p) {
                    final tier = p['tier_key'] as String? ?? '';
                    return _PlanCard(
                      plan: p,
                      quote: _quoteFor(tier),
                      months: _months,
                      isCurrent: tier.isNotEmpty && tier == _activePlan,
                      busy: _busyTier == tier,
                      // One purchase at a time — the others stay tappable-
                      // looking but inert while Cashfree's overlay is open.
                      disabled: _busyTier != null && _busyTier != tier,
                      onSubscribe: _selfServeTiers.contains(tier)
                          ? () => _subscribe(tier, p['display_name'] as String? ?? 'Plan')
                          : null,
                      onTalkToUs: _selfServeTiers.contains(tier) || tier == 'free'
                          ? null
                          : () => context.push('/partner'),
                    );
                  }).toList(),
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

/// What the signed-in student is on right now, plus their remaining AI
/// generation quota — the single most common reason someone opens this page.
class _CurrentPlanBanner extends StatelessWidget {
  final Map<String, dynamic> subscription;
  const _CurrentPlanBanner({required this.subscription});

  @override
  Widget build(BuildContext context) {
    final premium = subscription['is_premium'] == true;
    final validTill = subscription['valid_till'] as String?;
    final remaining = subscription['generations_remaining'];
    final limit = subscription['monthly_generation_limit'];
    // Read the tier straight off `plan` — deriving it from is_elite/is_premium
    // silently mislabels every tier that is neither, which Pro now is.
    const names = {'free': 'Free', '999': 'Plus', '4999': 'Pro', '9999': 'Elite'};
    final label = premium ? (names[subscription['plan']] ?? 'Paid') : 'Free';
    final workshopsLeft = subscription['workshops_remaining'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: (premium ? AppColors.success : AppColors.primary).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: (premium ? AppColors.success : AppColors.primary).withValues(alpha: 0.25)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(premium ? Icons.verified_rounded : Icons.person_rounded,
            size: 18, color: premium ? AppColors.success : AppColors.primary),
        const SizedBox(width: 10),
        Flexible(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(
              premium && validTill != null
                  ? 'You are on $label — till ${_PricingScreenState._formatDate(validTill)}'
                  : 'You are on the $label plan',
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            if (remaining is int && limit is int)
              Text('$remaining of $limit Custom Test Series left this month',
                  style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.textSecondary)),
            if (workshopsLeft is int && workshopsLeft > 0)
              Text('$workshopsLeft live workshops included this month',
                  style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.success)),
          ]),
        ),
      ]),
    );
  }
}

/// Segmented 1 / 3 / 6-month picker. The saving is shown on the control
/// itself — a discount nobody notices is a discount that does not sell.
class _DurationSelector extends StatelessWidget {
  final List<int> durations;
  final int selected;
  final int Function(int months) discountFor;
  final ValueChanged<int> onChanged;

  const _DurationSelector({
    required this.durations,
    required this.selected,
    required this.discountFor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: durations.map((m) {
        final active = m == selected;
        final pct = discountFor(m);
        return InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => onChanged(m),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: active ? AppColors.primary : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                  color: active ? AppColors.primary : Colors.grey.withValues(alpha: 0.3)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(m == 1 ? '1 month' : '$m months',
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: active ? Colors.white : AppColors.textPrimary)),
              if (pct > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                      color: AppColors.success, borderRadius: BorderRadius.circular(20)),
                  child: Text('save $pct%',
                      style: GoogleFonts.inter(
                          fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ],
            ]),
          ),
        );
      }).toList(),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final Map<String, dynamic> plan;
  /// Server-priced total for the selected duration; null for the free and
  /// sales-assisted tiers, which fall back to the plan's own price_label.
  final Map<String, dynamic>? quote;
  final int months;
  final bool isCurrent;
  final bool busy;
  final bool disabled;
  final VoidCallback? onSubscribe;
  final VoidCallback? onTalkToUs;

  const _PlanCard({
    required this.plan,
    required this.quote,
    required this.months,
    required this.isCurrent,
    required this.busy,
    required this.disabled,
    this.onSubscribe,
    this.onTalkToUs,
  });

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
        border: Border.all(
          color: isCurrent
              ? AppColors.success
              : (highlighted ? AppColors.primary : Colors.grey.withValues(alpha: 0.15)),
          width: isCurrent ? 2 : 1,
        ),
        boxShadow: highlighted
            ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.25), blurRadius: 20, offset: const Offset(0, 8))]
            : null,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(plan['display_name'] ?? '',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16,
                    color: highlighted ? Colors.white : AppColors.textPrimary)),
          ),
          if (isCurrent)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: AppColors.success, borderRadius: BorderRadius.circular(20)),
              child: Text('Current',
                  style: GoogleFonts.inter(
                      fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
        ]),
        const SizedBox(height: 12),
        Text(quote != null ? '₹${quote!['total']}' : (plan['price_label'] ?? ''),
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 26,
                color: highlighted ? Colors.white : AppColors.textPrimary)),
        if (quote != null && months > 1) ...[
          Row(children: [
            Text('₹${quote!['gross']}',
                style: GoogleFonts.inter(
                    fontSize: 12.5,
                    decoration: TextDecoration.lineThrough,
                    color: highlighted ? Colors.white54 : AppColors.textSecondary)),
            const SizedBox(width: 6),
            Text('save ₹${quote!['discount_amount']}',
                style: GoogleFonts.inter(
                    fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.success)),
          ]),
          Text('for $months months — ₹${quote!['monthly_price']}/month',
              style: GoogleFonts.inter(
                  fontSize: 12, color: highlighted ? Colors.white70 : AppColors.textSecondary)),
        ] else if ((plan['billing_note'] ?? '').isNotEmpty)
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
        if (_cta(context) != null) ...[
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: _cta(context)!),
        ],
      ]),
    );
  }

  Widget? _cta(BuildContext context) {
    final highlighted = plan['is_highlighted'] == true;
    if (isCurrent && onSubscribe == null) {
      // Free tier the student is already on — nothing to sell.
      return null;
    }
    if (onTalkToUs != null) {
      return OutlinedButton(
        onPressed: onTalkToUs,
        style: OutlinedButton.styleFrom(
          foregroundColor: highlighted ? Colors.white : AppColors.primary,
          side: BorderSide(color: highlighted ? Colors.white54 : AppColors.primary),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
        ),
        child: Text('Talk to us',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13.5)),
      );
    }
    if (onSubscribe == null) return null;
    return FilledButton(
      onPressed: (busy || disabled) ? null : onSubscribe,
      style: FilledButton.styleFrom(
        backgroundColor: highlighted ? AppColors.accent : AppColors.primary,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
      ),
      child: busy
          ? const SizedBox(
              height: 18, width: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : Text(
              isCurrent
                  ? (months > 1 ? 'Renew — $months months' : 'Renew')
                  : 'Get ${plan['display_name'] ?? 'this plan'}',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13.5)),
    );
  }
}
