import 'dart:async';
import 'dart:html' as html;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../constants/app_colors.dart';
import '../../models/training_module_model.dart';
import '../../services/api_service.dart';
import '../../services/cashfree_checkout.dart';
import '../../services/google_auth_service.dart';
import '../../widgets/fomo_countdown.dart';
import '../../widgets/html_view.dart';
import '../../widgets/registration_success_card.dart';
import '../student/student_module_detail_screen.dart';

enum _RegState { none, pending, registered }

class LiveSessionDetailScreen extends StatefulWidget {
  final int sessionId;
  const LiveSessionDetailScreen({super.key, required this.sessionId});

  @override
  State<LiveSessionDetailScreen> createState() => _LiveSessionDetailScreenState();
}

class _LiveSessionDetailScreenState extends State<LiveSessionDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  Map<String, dynamic>? _session;
  bool _loading = true;
  _RegState _regState = _RegState.none;
  bool _submitting = false;
  String? _error;
  String? _actionError;
  String? _pendingLinkUrl;
  String? _pendingPaymentSessionId;
  String _pendingCashfreeMode = 'production';
  String? _registeredName;
  Timer? _paymentPollTimer;
  bool _forceNewOnNextRegister = false;

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _collegeCtrl = TextEditingController();
  final _branchCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _couponCtrl = TextEditingController(text: 'DEV100');
  bool _couponChecking = false;
  String? _couponError;
  String? _appliedCouponCode;
  double? _appliedDiscountPercent;
  double? _appliedDiscountAmount;

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
      if (html.document.visibilityState == 'visible' && _regState == _RegState.pending) {
        _silentCheckPayment();
      }
    });
    // Fires the instant the Cashfree modal closes (paid, failed, or
    // dismissed) — the modal never navigates away from this page, so this
    // is the primary signal now; visibilitychange above stays as a
    // fallback for any edge case that still leaves the page.
    _cashfreeDoneSub = html.window.on['altrobyte-cashfree-done'].listen((_) {
      if (_regState == _RegState.pending) _silentCheckPayment();
    });
  }

  Future<void> _silentCheckPayment() async {
    try {
      final result = await ApiService.verifyLiveSessionPayment(widget.sessionId);
      if (!mounted || _regState != _RegState.pending) return;
      if (result['status'] == 'paid') {
        _paymentPollTimer?.cancel();
        _registeredName ??= _nameCtrl.text.trim();
        setState(() { _regState = _RegState.registered; _submitting = false; });
        _showSuccessCard();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _paymentPollTimer?.cancel();
    _visibilitySub?.cancel();
    _cashfreeDoneSub?.cancel();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _collegeCtrl.dispose();
    _branchCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _couponCtrl.dispose();
    super.dispose();
  }

  /// Polls payment status automatically every 5s (up to 3 min) so the
  /// student never has to keep tapping "Check payment status" or
  /// refreshing themselves after paying.
  void _startPaymentPolling() {
    _paymentPollTimer?.cancel();
    int attempts = 0;
    const maxAttempts = 36;
    _paymentPollTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      attempts++;
      if (!mounted || _regState != _RegState.pending || attempts > maxAttempts) {
        timer.cancel();
        return;
      }
      try {
        final result = await ApiService.verifyLiveSessionPayment(widget.sessionId);
        if (!mounted) return;
        if (result['status'] == 'paid') {
          timer.cancel();
          _registeredName ??= _nameCtrl.text.trim();
          setState(() { _regState = _RegState.registered; _submitting = false; });
          _showSuccessCard();
        }
      } catch (_) {}
    });
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final session = await ApiService.getLiveSession(widget.sessionId);
      var regState = _RegState.none;
      String? linkUrl;
      String? paymentSessionId;
      String cashfreeMode = 'production';
      String? registeredName;
      try {
        final res = await ApiService.getLiveSessionMyRegistration(widget.sessionId);
        final reg = res['registration'] as Map<String, dynamic>?;
        if (reg != null) {
          registeredName = reg['name'] as String?;
          if (reg['status'] == 'pending') {
            regState = _RegState.pending;
            linkUrl = reg['link_url'] as String?;
            paymentSessionId = reg['payment_session_id'] as String?;
            cashfreeMode = (reg['cashfree_mode'] as String?) ?? 'production';
          } else {
            regState = _RegState.registered;
          }
        }
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _session = session; _regState = regState; _pendingLinkUrl = linkUrl;
        _pendingPaymentSessionId = paymentSessionId; _pendingCashfreeMode = cashfreeMode;
        _registeredName = registeredName; _loading = false;
      });
      if (regState == _RegState.pending) _startPaymentPolling();
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _applyCoupon() async {
    final code = _couponCtrl.text.trim();
    if (code.isEmpty) return;
    setState(() { _couponChecking = true; _couponError = null; });
    try {
      final result = await ApiService.validateLiveSessionCoupon(widget.sessionId, code);
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

  /// Backs out of a stuck "pending" state to the registration form (already
  /// pre-filled from the last attempt) so the student can submit again and
  /// get a brand-new Cashfree order, instead of being stuck reopening the
  /// same possibly-expired payment link forever.
  void _startOver() {
    _paymentPollTimer?.cancel();
    // Only an explicit "Start Over" should force a brand-new Cashfree order —
    // a normal resubmit (double tap, reopening the form) reuses the existing
    // pending order so an already-open/already-paid tab is never orphaned.
    _forceNewOnNextRegister = true;
    setState(() {
      _regState = _RegState.none;
      _pendingLinkUrl = null;
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
      final result = await ApiService.registerForLiveSession(widget.sessionId,
          name: _nameCtrl.text.trim(), phone: _phoneCtrl.text.trim(), email: _emailCtrl.text.trim(),
          college: _collegeCtrl.text.trim(), branch: _branchCtrl.text.trim(),
          address: _addressCtrl.text.trim(), city: _cityCtrl.text.trim(),
          couponCode: _appliedCouponCode ?? '', forceNew: forceNew,
          returnUrl: '${Uri.base.origin}/live-sessions/${widget.sessionId}');
      if (!mounted) return;
      _registeredName = _nameCtrl.text.trim();
      if (result['status'] == 'pending') {
        setState(() {
          _regState = _RegState.pending;
          _pendingLinkUrl = result['link_url'] as String?;
          _pendingPaymentSessionId = result['payment_session_id'] as String?;
          _pendingCashfreeMode = (result['cashfree_mode'] as String?) ?? 'production';
          _submitting = false;
        });
        _startPaymentPolling();
        _openPaymentPage();
      } else {
        setState(() { _regState = _RegState.registered; _submitting = false; });
        _showSuccessCard();
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

  // Registration is tied to one real person — anonymous browsing is fine,
  // but the backend now rejects the shared pre-launch guest identity for
  // /register (401), so prompt a real sign-in and retry once done.
  Future<void> _promptSignInThenRetry() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sign in to register'),
        content: const Text(
            'Please sign in with Google to register — this keeps your registration and payment linked to you.'),
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
        typeLabel: 'WORKSHOP',
        title: _session!['title'] ?? '',
        studentName: _registeredName ?? '',
        extraLine: (_session!['host_name'] ?? '').isNotEmpty ? 'Hosted by ${_session!['host_name']}' : null);
  }

  Future<void> _openLinkedModule(int moduleId) async {
    try {
      final data = await ApiService.getStudentTrainingModule(moduleId);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StudentModuleDetailScreen(
            module: TrainingModule.fromJson(data),
            completedIds: const {},
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open course: $e')));
    }
  }

  Future<void> _openExternalLink(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// Cashfree's payment_session_id must go through their JS Checkout SDK
  /// (CashfreeCheckout) — a raw link_url redirect is rejected as "client
  /// session is invalid" on this account's Orders API. Falls back to
  /// opening link_url directly only in the (currently unused) case where
  /// a genuine standalone Payment Link was issued instead.
  void _openPaymentPage() {
    final sessionId = _pendingPaymentSessionId;
    if (sessionId != null && sessionId.isNotEmpty) {
      CashfreeCheckout.open(paymentSessionId: sessionId, mode: _pendingCashfreeMode);
    } else if (_pendingLinkUrl != null && _pendingLinkUrl!.isNotEmpty) {
      _openExternalLink(_pendingLinkUrl!);
    }
  }

  Future<void> _checkPayment() async {
    setState(() { _submitting = true; _actionError = null; });
    try {
      final result = await ApiService.verifyLiveSessionPayment(widget.sessionId);
      if (!mounted) return;
      if (result['status'] == 'paid') {
        _registeredName ??= _nameCtrl.text.trim();
        setState(() { _regState = _RegState.registered; _submitting = false; });
        _showSuccessCard();
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null || _session == null) {
      return Scaffold(
        appBar: AppBar(leading: const BackButton()),
        body: Center(child: Text(_error ?? 'Session not found')),
      );
    }
    final session = _session!;
    DateTime? date;
    try {
      date = session['session_date'] != null ? DateTime.parse(session['session_date']) : null;
    } catch (_) {}
    final isPast = date != null && date.isBefore(DateTime.now());
    final hasRecording = (session['recording_url'] ?? '').toString().isNotEmpty;
    final price = (session['price'] as num?) ?? 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: AppColors.primary,
            iconTheme: const IconThemeData(color: Colors.white),
            expandedHeight: 260,
            actions: [
              IconButton(
                icon: const Icon(Icons.share_rounded),
                tooltip: 'Share',
                onPressed: () => _shareSession(session),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              background: _HeroBanner(session: session, isFeatured: session['is_featured'] == true),
            ),
          ),
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 800;
                      final info = _InfoSection(
                        session: session, date: date, isPast: isPast, hasRecording: hasRecording,
                        onRecording: () => _openLink(session['recording_url']),
                        onOpenModule: _openLinkedModule,
                      );
                      final regCard = isPast
                          ? const SizedBox.shrink()
                          : _buildRegistrationCard(price);

                      if (isWide) {
                        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Expanded(flex: 3, child: info),
                          const SizedBox(width: 24),
                          SizedBox(width: 360, child: regCard),
                        ]);
                      }
                      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        info,
                        const SizedBox(height: 20),
                        regCard,
                      ]);
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _shareSession(Map<String, dynamic> session) {
    final link = 'https://altrobytelab.com/live-sessions/${widget.sessionId}';
    final title = session['title'] ?? 'this workshop';
    final text = "Join me for \"$title\" on AltrobyteLab!\nRegister here: $link";
    if (kIsWeb) {
      Clipboard.setData(ClipboardData(text: text));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link copied to clipboard!')),
      );
    } else {
      Share.share(text);
    }
  }

  void _shareToSocial(String platform, Map<String, dynamic> session) {
    final link = 'https://altrobytelab.com/live-sessions/${widget.sessionId}';
    final title = session['title'] ?? 'this workshop';
    final caption = '🚀 Just started my learning journey into tech with "$title" on AltrobyteLab! '
        'Excited to keep building and growing. Join me:';
    switch (platform) {
      case 'whatsapp':
        _openExternalLink('https://wa.me/?text=${Uri.encodeComponent('$caption $link')}');
        break;
      case 'linkedin':
        _openExternalLink('https://www.linkedin.com/sharing/share-offsite/?url=${Uri.encodeComponent(link)}');
        break;
      case 'instagram':
        Clipboard.setData(ClipboardData(text: '$caption $link'));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Caption copied! Paste it into your Instagram post or story.')),
        );
        _openExternalLink('https://www.instagram.com/');
        break;
    }
  }

  Widget _socialIconButton({required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: 42, height: 42,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }

  Future<void> _openLink(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Widget _buildRegistrationCard(num price) {
    if (_regState == _RegState.registered) return _buildRegisteredPremiumCard(price);
    return _CardShell(child: _buildRegistrationContent(price));
  }

  Widget _buildRegisteredPremiumCard(num price) {
    final session = _session!;
    final title = (session['title'] ?? '').toString();
    final host = (session['host_name'] ?? '').toString();
    String dateStr = '';
    try {
      final d = DateTime.parse(session['session_date'].toString());
      dateStr = DateFormat('EEE, MMM d · h:mm a').format(d);
    } catch (_) {}

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.10), blurRadius: 28, offset: const Offset(0, 12))],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primary, AppColors.primaryLight, AppColors.accent],
            ),
          ),
          child: Stack(clipBehavior: Clip.none, children: [
            Positioned(right: -36, top: -36, child: _decorCircle(100, 0.10)),
            Positioned(left: -28, bottom: -46, child: _decorCircle(120, 0.08)),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.bolt_rounded, size: 13, color: Colors.amber.shade300),
                  const SizedBox(width: 4),
                  Text('ALTROBYTELAB', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.8)),
                ]),
              ),
              const SizedBox(height: 18),
              Container(
                width: 54, height: 54,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 12, offset: const Offset(0, 5))],
                ),
                child: const Icon(Icons.celebration_rounded, color: AppColors.accent, size: 30),
              ),
              const SizedBox(height: 14),
              Text(price > 0 ? "You're in! 🎉" : "You're registered! 🎉",
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 21, color: Colors.white)),
              const SizedBox(height: 6),
              Text(title,
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 13.5, color: Colors.white.withValues(alpha: 0.92), height: 1.4)),
              if (dateStr.isNotEmpty || host.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(spacing: 14, runSpacing: 6, children: [
                  if (dateStr.isNotEmpty) _chipInfo(Icons.calendar_today_rounded, dateStr),
                  if (host.isNotEmpty) _chipInfo(Icons.person_rounded, host),
                ]),
              ],
            ]),
          ]),
        ),
        Container(
          width: double.infinity,
          color: Colors.white,
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: const Border(left: BorderSide(color: AppColors.accent, width: 3)),
              ),
              child: Text(
                '"🚀 Every expert was once a beginner. Your journey into technology starts today — keep learning, keep building, keep growing!"',
                style: GoogleFonts.poppins(fontSize: 13, fontStyle: FontStyle.italic, fontWeight: FontWeight.w600, color: AppColors.textPrimary, height: 1.5),
              ),
            ),
            const SizedBox(height: 14),
            Text('Share your journey', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 12.5, color: AppColors.textSecondary)),
            const SizedBox(height: 10),
            Row(children: [
              _socialIconButton(icon: FontAwesomeIcons.whatsapp, color: AppColors.whatsapp, onTap: () => _shareToSocial('whatsapp', session)),
              const SizedBox(width: 12),
              _socialIconButton(icon: FontAwesomeIcons.linkedinIn, color: const Color(0xFF0A66C2), onTap: () => _shareToSocial('linkedin', session)),
              const SizedBox(width: 12),
              _socialIconButton(icon: FontAwesomeIcons.instagram, color: const Color(0xFFC13584), onTap: () => _shareToSocial('instagram', session)),
              const SizedBox(width: 12),
              _socialIconButton(icon: Icons.link_rounded, color: AppColors.textSecondary, onTap: () => _shareSession(session)),
            ]),
            if ((session['redirect_link'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: FilledButton.icon(
                  onPressed: () => _openExternalLink(session['redirect_link']),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.whatsapp,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.chat_rounded, size: 18),
                  label: Text('Join WhatsApp Group', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13.5)),
                ),
              ),
            ],
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: FilledButton.icon(
                onPressed: _showSuccessCard,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.download_rounded, size: 18),
                label: Text('Download to Post', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13.5)),
              ),
            ),
            const SizedBox(height: 14),
            _referralBanner(session),
          ]),
        ),
      ]),
    );
  }

  Widget _decorCircle(double size, double opacity) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: opacity)),
    );
  }

  Widget _chipInfo(IconData icon, String text) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: Colors.white.withValues(alpha: 0.85)),
      const SizedBox(width: 5),
      Text(text, style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withValues(alpha: 0.9))),
    ]);
  }

  Widget _referralBanner(Map<String, dynamic> session) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.35)),
      ),
      child: Row(children: [
        const Icon(Icons.card_giftcard_rounded, color: AppColors.accent, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Text('Refer your friends & get 10% cashback!',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 12.5, color: AppColors.accent)),
        ),
        TextButton(
          onPressed: () => _shareSession(session),
          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10)),
          child: Text('Share', style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 12.5, color: AppColors.accent)),
        ),
      ]),
    );
  }

  Widget _buildRegistrationContent(num price) {
    if (_regState == _RegState.pending) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: const Icon(Icons.hourglass_top_rounded, color: Colors.orange),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text('Payment pending', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15))),
        ]),
        const SizedBox(height: 8),
        Text('Checking automatically every few seconds — no need to keep refreshing.',
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 14),
        if (_actionError != null) ...[
          Text(_actionError!, style: GoogleFonts.inter(fontSize: 12, color: AppColors.error)),
          const SizedBox(height: 10),
        ],
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 13)),
            onPressed: _submitting ? null : _checkPayment,
            child: _submitting
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Check payment status'),
          ),
        ),
        if ((_pendingPaymentSessionId ?? '').isNotEmpty || (_pendingLinkUrl ?? '').isNotEmpty) ...[
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
      ]);
    }

    final tax = (_session?['tax_percent'] as num?) ?? 0;
    final originalPrice = (_session?['original_price'] as num?)?.toDouble();
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
        if (price > 0) ...[
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
        ] else ...[
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
              child: Text('FREE', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.success)),
            ),
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
        const SizedBox(height: 12),
        TextFormField(
          controller: _collegeCtrl,
          decoration: _fieldDecoration('College / Company name *'),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'This field is required' : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _branchCtrl,
          decoration: _fieldDecoration('Branch / Field *'),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'This field is required' : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _addressCtrl,
          decoration: _fieldDecoration('Address *'),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Address is required' : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _cityCtrl,
          decoration: _fieldDecoration('City *'),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'City is required' : null,
        ),
        if (_actionError != null) ...[
          const SizedBox(height: 10),
          Text(_actionError!, style: GoogleFonts.inter(fontSize: 12, color: AppColors.error)),
        ],
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton(
            onPressed: _submitting ? null : _register,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: _submitting
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(total > 0 ? 'Proceed to Pay ₹${total.toStringAsFixed(0)}' : 'Register — it\'s free',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14)),
          ),
        ),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.lock_outline_rounded, size: 13, color: AppColors.textSecondary),
          const SizedBox(width: 5),
          Text('Secure registration', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
        ]),
      ]),
    );
  }

  InputDecoration _fieldDecoration(String label) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.accent, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      );
}

class _HeroBanner extends StatelessWidget {
  final Map<String, dynamic> session;
  final bool isFeatured;
  const _HeroBanner({required this.session, required this.isFeatured});

  @override
  Widget build(BuildContext context) {
    final banner = (session['banner_url'] ?? '').toString();
    return Stack(fit: StackFit.expand, children: [
      if (banner.isNotEmpty)
        Image.network(banner, fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) => progress == null ? child : Container(color: AppColors.primary),
            errorBuilder: (_, __, ___) => const _HeroFallback())
      else
        const _HeroFallback(),
      // Scrim for text legibility, regardless of image content.
      Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black54, Colors.black87],
            stops: [0.0, 0.6, 1.0],
          ),
        ),
      ),
      Positioned(
        left: 0, right: 0, bottom: 0,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (isFeatured) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(20)),
                    child: Text('FEATURED WORKSHOP',
                        style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5)),
                  ),
                  const SizedBox(height: 10),
                ],
                Text(session['title'] ?? '',
                    style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 24, height: 1.25),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                if ((session['host_name'] ?? '').isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(children: [
                    const Icon(Icons.person_rounded, size: 14, color: Colors.white70),
                    const SizedBox(width: 6),
                    Text('Hosted by ${session['host_name']}', style: GoogleFonts.inter(color: Colors.white70, fontSize: 13)),
                  ]),
                ],
              ]),
            ),
          ),
        ),
      ),
    ]);
  }
}

class _HeroFallback extends StatelessWidget {
  const _HeroFallback();
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight, AppColors.accent],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
      ),
      child: const Center(child: Icon(Icons.video_camera_front_rounded, color: Colors.white24, size: 72)),
    );
  }
}

class _InfoSection extends StatelessWidget {
  final Map<String, dynamic> session;
  final DateTime? date;
  final bool isPast;
  final bool hasRecording;
  final VoidCallback onRecording;
  final void Function(int moduleId) onOpenModule;
  const _InfoSection({
    required this.session, required this.date, required this.isPast,
    required this.hasRecording, required this.onRecording, required this.onOpenModule,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _CardShell(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Session details', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 16),
          Wrap(spacing: 28, runSpacing: 16, children: [
            if (date != null) _detailTile(Icons.calendar_today_rounded, 'Date',
                DateFormat('EEE, d MMM yyyy').format(date!)),
            if (date != null) _detailTile(Icons.access_time_rounded, 'Time', DateFormat('h:mm a').format(date!)),
            if ((session['duration_minutes'] ?? 0) > 0)
              _detailTile(Icons.schedule_rounded, 'Duration', '${session['duration_minutes']} min'),
            if ((session['platform'] ?? '').isNotEmpty)
              _detailTile(Icons.videocam_outlined, 'Platform', session['platform']),
            _detailTile(Icons.people_outline_rounded, 'Registered', '${session['registration_count'] ?? 0} people'),
          ]),
          if (!isPast) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                const Icon(Icons.chat_rounded, size: 16, color: AppColors.whatsapp),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('The join link will be sent to you on WhatsApp once you register.',
                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                ),
              ]),
            ),
          ],
          if (isPast && hasRecording) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.success,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: onRecording,
                icon: const Icon(Icons.play_circle_outline_rounded, size: 18),
                label: Text('Watch recording', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ]),
      ),
      if (session['linked_module'] != null) ...[
        const SizedBox(height: 20),
        _CardShell(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => onOpenModule(session['linked_module']['id'] as int),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.card_giftcard_rounded, color: AppColors.success, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Free bonus course included', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13.5)),
                  const SizedBox(height: 2),
                  Text('Registering unlocks "${session['linked_module']['title']}" for free',
                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                ]),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textSecondary),
            ]),
          ),
        ),
      ],
      if ((session['description_html'] ?? '').isNotEmpty) ...[
        const SizedBox(height: 20),
        _CardShell(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('About this workshop', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 12),
            SizedBox(height: 320, child: HtmlView(html: session['description_html'])),
          ]),
        ),
      ],
    ]);
  }

  Widget _detailTile(IconData icon, String label, String value) {
    return SizedBox(
      width: 150,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(9)),
          child: Icon(icon, size: 17, color: AppColors.accent),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
            const SizedBox(height: 2),
            Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
        ),
      ]),
    );
  }
}

/// Shared elevated white card shell used across the page for a consistent look.
class _CardShell extends StatelessWidget {
  final Widget child;
  const _CardShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 16, offset: const Offset(0, 4)),
        ],
      ),
      child: child,
    );
  }
}
