import 'dart:async';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../models/training_module_model.dart';
import '../../services/api_service.dart';
import '../../services/cashfree_checkout.dart';
import '../../services/google_auth_service.dart';
import '../../widgets/fomo_countdown.dart';
import '../../widgets/registration_success_card.dart';

enum _PurchaseState { none, pending, paid }

/// The paywall + checkout flow for a locked (paid) Training Module — mirrors
/// the Live Session registration flow (SDK checkout, coupons, reuse-pending-
/// order dedup) so both purchase paths behave identically.
class ModulePurchaseSection extends StatefulWidget {
  final TrainingModule module;
  final VoidCallback onUnlocked;
  const ModulePurchaseSection({super.key, required this.module, required this.onUnlocked});

  @override
  State<ModulePurchaseSection> createState() => _ModulePurchaseSectionState();
}

class _ModulePurchaseSectionState extends State<ModulePurchaseSection> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _couponCtrl = TextEditingController(text: 'DEV100');

  bool _loading = true;
  _PurchaseState _state = _PurchaseState.none;
  bool _submitting = false;
  String? _actionError;

  String? _pendingPaymentSessionId;
  String _pendingCashfreeMode = 'production';
  bool _forceNewOnNextRegister = false;

  bool _couponChecking = false;
  String? _couponError;
  String? _appliedCouponCode;
  double? _appliedDiscountPercent;
  double? _appliedDiscountAmount;

  Timer? _pollTimer;
  String? _enrolledName;
  StreamSubscription<html.Event>? _visibilitySub;
  StreamSubscription<html.Event>? _cashfreeDoneSub;

  @override
  void initState() {
    super.initState();
    _load();
    // Background-tab timer throttling means the 5s poll can stall for
    // minutes while the student is away completing Cashfree checkout in
    // another tab — the DB itself is already correct by then (webhook),
    // so the moment they switch back here, check immediately instead of
    // waiting for the throttled timer to eventually catch up.
    _visibilitySub = html.document.onVisibilityChange.listen((_) {
      if (html.document.visibilityState == 'visible' && _state == _PurchaseState.pending) {
        _silentCheckPayment();
      }
    });
    // Fires the instant the Cashfree modal closes (paid, failed, or
    // dismissed) — the modal never navigates away from this page, so this
    // is the primary signal now; visibilitychange above stays as a
    // fallback for any edge case that still leaves the page.
    _cashfreeDoneSub = html.window.on['altrobyte-cashfree-done'].listen((_) {
      if (_state == _PurchaseState.pending) _silentCheckPayment();
    });
  }

  Future<void> _silentCheckPayment() async {
    try {
      final result = await ApiService.verifyModulePayment(widget.module.id);
      if (!mounted || _state != _PurchaseState.pending) return;
      if (result['status'] == 'paid') {
        _pollTimer?.cancel();
        setState(() { _state = _PurchaseState.paid; _submitting = false; });
        _showSuccessCard();
        widget.onUnlocked();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _visibilitySub?.cancel();
    _cashfreeDoneSub?.cancel();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _couponCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.getModuleMyEnrollment(widget.module.id);
      final enrollment = res['enrollment'] as Map<String, dynamic>?;
      if (!mounted) return;
      if (enrollment != null) {
        _enrolledName = enrollment['name'] as String?;
        if (enrollment['status'] == 'paid') {
          setState(() { _state = _PurchaseState.paid; _loading = false; });
          widget.onUnlocked();
          return;
        }
        setState(() {
          _state = _PurchaseState.pending;
          _pendingPaymentSessionId = enrollment['payment_session_id'] as String?;
          _pendingCashfreeMode = (enrollment['cashfree_mode'] as String?) ?? 'production';
          _loading = false;
        });
        _startPolling();
        return;
      }
      setState(() { _state = _PurchaseState.none; _loading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _state = _PurchaseState.none; _loading = false; });
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    int attempts = 0;
    const maxAttempts = 36;
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      attempts++;
      if (!mounted || _state != _PurchaseState.pending || attempts > maxAttempts) {
        timer.cancel();
        return;
      }
      try {
        final result = await ApiService.verifyModulePayment(widget.module.id);
        if (!mounted) return;
        if (result['status'] == 'paid') {
          timer.cancel();
          setState(() { _state = _PurchaseState.paid; _submitting = false; });
          _showSuccessCard();
          widget.onUnlocked();
        }
      } catch (_) {}
    });
  }

  Future<void> _applyCoupon() async {
    final code = _couponCtrl.text.trim();
    if (code.isEmpty) return;
    setState(() { _couponChecking = true; _couponError = null; });
    try {
      final result = await ApiService.validateModuleCoupon(widget.module.id, code);
      if (!mounted) return;
      setState(() {
        _appliedCouponCode = code;
        _appliedDiscountPercent = (result['discount_percent'] as num?)?.toDouble() ?? 0;
        _appliedDiscountAmount = (result['discount_amount'] as num?)?.toDouble() ?? 0;
        _couponChecking = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _couponChecking = false;
        _appliedCouponCode = null;
        _appliedDiscountPercent = null;
        _appliedDiscountAmount = null;
        _couponError = e is ApiException ? e.message : 'Invalid or expired coupon code';
      });
    }
  }

  void _removeCoupon() {
    setState(() {
      _appliedCouponCode = null;
      _appliedDiscountPercent = null;
      _appliedDiscountAmount = null;
      _couponError = null;
      _couponCtrl.clear();
    });
  }

  void _startOver() {
    _pollTimer?.cancel();
    _forceNewOnNextRegister = true;
    setState(() {
      _state = _PurchaseState.none;
      _pendingPaymentSessionId = null;
      _actionError = null;
    });
  }

  Future<void> _register() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() { _submitting = true; _actionError = null; });
    final forceNew = _forceNewOnNextRegister;
    _forceNewOnNextRegister = false;
    try {
      final result = await ApiService.registerForModule(widget.module.id,
          name: _nameCtrl.text.trim(), phone: _phoneCtrl.text.trim(), email: _emailCtrl.text.trim(),
          couponCode: _appliedCouponCode ?? '', forceNew: forceNew,
          returnUrl: Uri.base.origin);
      if (!mounted) return;
      _enrolledName = _nameCtrl.text.trim();
      if (result['status'] == 'pending') {
        setState(() {
          _state = _PurchaseState.pending;
          _pendingPaymentSessionId = result['payment_session_id'] as String?;
          _pendingCashfreeMode = (result['cashfree_mode'] as String?) ?? 'production';
          _submitting = false;
        });
        _startPolling();
        _openPaymentPage();
      } else {
        setState(() { _state = _PurchaseState.paid; _submitting = false; });
        _showSuccessCard();
        widget.onUnlocked();
      }
    } catch (e) {
      if (!mounted) return;
      if (e is ApiException && e.statusCode == 401) {
        setState(() => _submitting = false);
        await _promptSignInThenRetry();
        return;
      }
      setState(() { _submitting = false; _actionError = e.toString(); });
    }
  }

  Future<void> _promptSignInThenRetry() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sign in to continue'),
        content: const Text(
            'Please sign in with Google to enroll — this keeps your enrollment and payment linked to you.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sign in with Google')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await GoogleAuthService.signIn();
      if (!mounted) return;
      await _register();
    } catch (e) {
      if (!mounted) return;
      setState(() => _actionError = 'Sign-in failed: $e');
    }
  }

  void _showSuccessCard() {
    showRegistrationSuccessDialog(context,
        typeLabel: 'COURSE',
        title: widget.module.title,
        studentName: _enrolledName ?? '');
  }

  void _openPaymentPage() {
    final sessionId = _pendingPaymentSessionId;
    if (sessionId != null && sessionId.isNotEmpty) {
      CashfreeCheckout.open(paymentSessionId: sessionId, mode: _pendingCashfreeMode);
    }
  }

  Future<void> _checkPayment() async {
    setState(() { _submitting = true; _actionError = null; });
    try {
      final result = await ApiService.verifyModulePayment(widget.module.id);
      if (!mounted) return;
      if (result['status'] == 'paid') {
        setState(() { _state = _PurchaseState.paid; _submitting = false; });
        _showSuccessCard();
        widget.onUnlocked();
      } else {
        setState(() {
          _submitting = false;
          _actionError = "Payment not confirmed yet — if you've paid, try again in a moment.";
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() { _submitting = false; _actionError = e.toString(); });
    }
  }

  InputDecoration _fieldDecoration(String label) => InputDecoration(
        labelText: label,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      );

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final price = widget.module.price;
    final tax = widget.module.taxPercent;
    final showSignInPrompt = widget.module.loginRequired && _state == _PurchaseState.none;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.lock_rounded, color: AppColors.accent, size: 20),
          const SizedBox(width: 8),
          Text('This course is locked', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 4),
        Text('Unlock all topics, notes, videos and quizzes in "${widget.module.title}".',
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary, height: 1.4)),
        const SizedBox(height: 20),
        if (showSignInPrompt)
          ..._buildSignInPrompt()
        else if (_state == _PurchaseState.pending)
          ..._buildPendingSection()
        else
          _buildForm(price, tax),
        if (_actionError != null) ...[
          const SizedBox(height: 10),
          Text(_actionError!, style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.error)),
        ],
      ]),
    );
  }

  List<Widget> _buildSignInPrompt() {
    return [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.login_rounded, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Sign in to check your access',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14)),
            ),
          ]),
          const SizedBox(height: 8),
          Text(
            widget.module.linkedSession != null
                ? 'This course is a free bonus for students who registered for "${widget.module.linkedSession!.title}". Sign in to confirm your access.'
                : 'Sign in to confirm your access to this course.',
            style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textSecondary, height: 1.4),
          ),
        ]),
      ),
      const SizedBox(height: 14),
      SizedBox(
        width: double.infinity,
        height: 48,
        child: FilledButton.icon(
          onPressed: _submitting ? null : _signInNow,
          icon: _submitting
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.login_rounded, size: 18),
          label: const Text('Sign in with Google'),
        ),
      ),
    ];
  }

  Future<void> _signInNow() async {
    setState(() { _submitting = true; _actionError = null; });
    try {
      await GoogleAuthService.signIn();
      if (!mounted) return;
      setState(() => _submitting = false);
      // Reloads the parent's module detail with the now-real student
      // token — this widget's `module.loginRequired`/`locked` props come
      // from the parent, not from here, so it must refetch there.
      widget.onUnlocked();
    } catch (e) {
      if (!mounted) return;
      setState(() { _submitting = false; _actionError = 'Sign-in failed: $e'; });
    }
  }

  List<Widget> _buildPendingSection() {
    return [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.hourglass_top_rounded, color: AppColors.warning, size: 20),
            const SizedBox(width: 8),
            Text('Payment pending', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14)),
          ]),
          const SizedBox(height: 8),
          Text('Checking automatically every few seconds — no need to keep refreshing.',
              style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textSecondary)),
        ]),
      ),
      const SizedBox(height: 14),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: _submitting ? null : _checkPayment,
          child: _submitting
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Check payment status'),
        ),
      ),
      if ((_pendingPaymentSessionId ?? '').isNotEmpty) ...[
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.accent, padding: const EdgeInsets.symmetric(vertical: 13)),
            onPressed: _openPaymentPage,
            child: const Text('Reopen payment page'),
          ),
        ),
      ],
      const SizedBox(height: 10),
      Center(
        child: TextButton(
          onPressed: _submitting ? null : _startOver,
          child: const Text("Didn't work? Start over with a fresh payment link"),
        ),
      ),
    ];
  }

  Widget _buildForm(double price, double tax) {
    final originalPrice = widget.module.originalPrice;
    final discountAmount = _appliedDiscountAmount ?? 0;
    final discountPercent = _appliedDiscountPercent ?? 0;
    final priceAfterCoupon = price > 0
        ? (discountAmount > 0 ? (price - discountAmount).clamp(0, price) : price * (1 - discountPercent / 100))
        : price;
    final taxAmount = priceAfterCoupon > 0 ? (priceAfterCoupon * tax / 100) : 0;
    final total = priceAfterCoupon + taxAmount;

    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (price <= 0) ...[
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
              child: Text('FREE', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.success)),
            ),
          ]),
          const SizedBox(height: 18),
        ] else ...[
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Price', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
          Row(children: [
            if (originalPrice != null && originalPrice > price) ...[
              Text('₹${originalPrice.toStringAsFixed(0)}',
                  style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary, decoration: TextDecoration.lineThrough)),
              const SizedBox(width: 6),
            ],
            Text('₹${price.toStringAsFixed(0)}', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
          ]),
        ]),
        if (_appliedCouponCode != null) ...[
          const SizedBox(height: 6),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Coupon ($_appliedCouponCode)', style: GoogleFonts.inter(fontSize: 13, color: AppColors.success)),
            Text('- ₹${(price - priceAfterCoupon).toStringAsFixed(0)}',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.success)),
          ]),
        ],
        if (tax > 0) ...[
          const SizedBox(height: 6),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Tax ($tax%)', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
            Text('₹${taxAmount.toStringAsFixed(0)}', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
          ]),
        ],
        const SizedBox(height: 10),
        if (_appliedCouponCode == null) ...[
          const FomoCountdown(),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _couponCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: 'Coupon code', isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 48,
              child: OutlinedButton(
                onPressed: _couponChecking ? null : _applyCoupon,
                child: _couponChecking
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Apply'),
              ),
            ),
          ]),
          if (_couponError != null) ...[
            const SizedBox(height: 6),
            Text(_couponError!, style: GoogleFonts.inter(fontSize: 12, color: AppColors.error)),
          ] else ...[
            const SizedBox(height: 6),
            Text('Tap Apply for ₹100 off — limited to the first 10 developers',
                style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
          ],
        ] else
          Row(children: [
            const Icon(Icons.local_offer_rounded, size: 16, color: AppColors.success),
            const SizedBox(width: 6),
            Expanded(
              child: Text("'$_appliedCouponCode' applied",
                  style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.success)),
            ),
            TextButton(onPressed: _removeCoupon, child: const Text('Remove')),
          ]),
        const SizedBox(height: 10),
        const Divider(height: 1),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Total', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700)),
          Text('₹${total.toStringAsFixed(0)}',
              style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.accent)),
        ]),
        const SizedBox(height: 18),
        ],
        Text('Enter your details', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14)),
        const SizedBox(height: 14),
        TextFormField(
          controller: _nameCtrl,
          decoration: _fieldDecoration('Full name *'),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _phoneCtrl,
          keyboardType: TextInputType.phone,
          decoration: _fieldDecoration('Phone number *'),
          validator: (v) {
            final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
            if (digits.isEmpty) return 'Phone is required';
            if (digits.length != 10) return 'Enter a valid 10-digit phone number';
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: _fieldDecoration('Email *'),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Email is required' : null,
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
            onPressed: _submitting ? null : _register,
            child: _submitting
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(price > 0 ? 'Pay ₹${total.toStringAsFixed(0)} & Unlock' : 'Enroll for free',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15)),
          ),
        ),
      ]),
    );
  }
}
