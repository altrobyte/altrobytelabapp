import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../constants/app_colors.dart';
import '../../services/api_service.dart';
import '../../widgets/auth_sheet.dart';
import '../../widgets/scholarship_form_sheet.dart';

/// The page the poster's QR code points at.
///
/// Everything else about the scholarship existed — the bands, the coupon, the
/// result card — and a candidate had no way to reach any of it. This is the
/// missing half: what it is, what each score is worth in rupees, and one
/// button that starts the test.
///
/// The ladder is the argument. A discount is a number somebody has to take on
/// trust; a table that says "score 90 and you pay 5,000" is a thing they can
/// decide to go and earn.
class ScholarshipScreen extends StatefulWidget {
  const ScholarshipScreen({super.key});

  @override
  State<ScholarshipScreen> createState() => _ScholarshipScreenState();
}

class _ScholarshipScreenState extends State<ScholarshipScreen> {
  Map<String, dynamic>? _config;
  Map<String, dynamic>? _mine;
  bool _loading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final cfg = await ApiService.getScholarship();
      if (!mounted) return;
      setState(() {
        _config = cfg;
        _loading = false;
      });

      // If they have already sat it, the result is the page — not the pitch.
      try {
        final mine = await ApiService.claimScholarship();
        if (mounted) setState(() => _mine = mine);
      } catch (_) {
        // Not signed in, or has not taken it. Either way the pitch stands.
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e is ApiException ? e.message : 'Could not load. $e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _start() async {
    final test = _config?['test'] as Map?;
    if (test == null) return;

    // Sat once. The server refuses a second attempt anyway; saying so here
    // means nobody answers twenty questions to be told at the end.
    if (_config?['attempted'] == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('You have already taken the scholarship test.')));
        _load();
      }
      return;
    }

    // WhatsApp only, no Google. The award has to reach a real person we can
    // ring, and a Google account arrives with no number at all.
    final ok = await showAuthSheet(context,
        phoneOnly: true,
        reason: 'to take the scholarship test and keep your result');
    if (!ok || !mounted) return;

    // Details before the paper, never after: a form between somebody and
    // the score they just earned is a form that does not get filled.
    await _load();
    if (!mounted) return;
    if (_config?['registration'] == null) {
      final saved = await showScholarshipFormSheet(context);
      if (!saved || !mounted) return;
      await _load();
      if (!mounted) return;
    }
    if (_config?['attempted'] == true) return;

    await context.push('/test/${test['id']}');
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _config?['enabled'] == true;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primary,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        title: Text('Scholarship Test',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700, fontSize: 17)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                  children: [
                    if (_error.isNotEmpty) _errorCard(),
                    if (!enabled && _error.isEmpty) _closedCard(),
                    if (enabled) ...[
                      _hero(),
                      const SizedBox(height: 16),
                      if (_mine != null) ...[
                        _result(),
                        const SizedBox(height: 16),
                      ],
                      _ladder(),
                      const SizedBox(height: 16),
                      _rules(),
                      const SizedBox(height: 20),
                      if (_mine == null) _cta(),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _errorCard() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Text(_error,
            style: GoogleFonts.inter(fontSize: 13, height: 1.5)),
      );

  /// Said plainly rather than left as an empty page.
  Widget _closedCard() => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE6EBF3)),
        ),
        child: Column(children: [
          const Icon(Icons.schedule_rounded,
              size: 38, color: AppColors.textSecondary),
          const SizedBox(height: 12),
          Text('No scholarship test is running right now',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(
              'The next one is announced with the batch. Ask us on WhatsApp '
              'and we will tell you when it opens.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 13, height: 1.55, color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 13)),
            onPressed: () => context.push('/roadmap/product-engineering'),
            child: const Text('See the programme'),
          ),
        ]),
      );

  Widget _hero() {
    final test = Map<String, dynamic>.from(_config!['test'] as Map);
    final base = (_config!['base_amount'] as num?)?.toDouble() ?? 0;
    final slabs = (_config!['slabs'] as List?) ?? const [];
    final best = slabs.isEmpty
        ? 0
        : (slabs.first as Map)['discount_percent'] as int? ?? 0;
    final secs = (test['duration_seconds'] as num?)?.toInt() ?? 0;
    final mins = (test['duration_mins'] as num?)?.toInt() ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0B2450), Color(0xFF1D4E9B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Scholarship Test',
            style: GoogleFonts.poppins(
                fontSize: 24,
                height: 1.2,
                fontWeight: FontWeight.w800,
                color: Colors.white)),
        const SizedBox(height: 8),
        Text(
            'One short test. Your score decides your scholarship — up to '
            '$best% off the Rs ${base.toStringAsFixed(0)} programme fee.',
            style: GoogleFonts.inter(
                fontSize: 14,
                height: 1.55,
                color: Colors.white.withValues(alpha: 0.88))),
        const SizedBox(height: 16),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _chip(Icons.quiz_outlined, '${test['questions'] ?? 0} questions'),
          _chip(Icons.timer_outlined,
              secs > 0 ? _readable(secs) : '$mins min'),
          _chip(Icons.bolt_rounded, 'Result instantly'),
          _chip(Icons.looks_one_rounded, 'One attempt'),
        ]),
      ]),
    );
  }

  Widget _chip(IconData icon, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 6),
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
        ]),
      );

  /// What they already earned, when they have been here before.
  Widget _result() {
    final m = _mine!;
    final awarded = m['awarded'] == true;
    final percent = (m['percent'] as num?)?.toDouble() ?? 0;
    final base = (m['base_amount'] as num?)?.toDouble() ?? 0;
    final slabs = (_config?['slabs'] as List?) ?? const [];
    final lowest = slabs.isEmpty
        ? 50
        : (slabs.last as Map)['min_percent'] as int? ?? 50;

    if (!awarded) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('You scored ${percent.toStringAsFixed(0)}%',
              style: GoogleFonts.poppins(
                  fontSize: 15.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 5),
          Text(
              'The lowest band starts at $lowest%, and the test is sat once, '
              'so this score stands. The programme fee is unchanged at '
              'Rs ${base.toStringAsFixed(0)} — and it is still the same '
              'programme.',
              style: GoogleFonts.inter(
                  fontSize: 12.5, height: 1.55, color: Colors.black87)),
          const SizedBox(height: 12),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => context.push('/roadmap/product-engineering'),
            child: const Text('See the programme'),
          ),
        ]),
      );
    }

    final off = (m['discount_percent'] as num?)?.toInt() ?? 0;
    final pay = (m['you_pay'] as num?)?.toDouble() ?? 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('You have $off% off',
            style: GoogleFonts.poppins(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.success)),
        const SizedBox(height: 4),
        Text('Scored ${percent.toStringAsFixed(0)}%. You pay '
            'Rs ${pay.toStringAsFixed(0)}.',
            style: GoogleFonts.inter(fontSize: 13, color: Colors.black87)),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
          ),
          child: Text('${m['coupon_code'] ?? ''}',
              style: GoogleFonts.poppins(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.6,
                  color: AppColors.primary)),
        ),
        const SizedBox(height: 10),
        if ('${m['whatsapp_number'] ?? ''}'.isNotEmpty)
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              onPressed: _redeemOnWhatsApp,
              icon: const Icon(Icons.chat_rounded, size: 18),
              label: Text('Send my score to the team',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600, fontSize: 14)),
            ),
          ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(vertical: 13)),
            onPressed: () => context.push('/roadmap/product-engineering'),
            child: Text('See the programme',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600, fontSize: 14)),
          ),
        ),
      ]),
    );
  }

  /// Opens WhatsApp with the claim already written out.
  ///
  /// The code alone puts the work on the team: who is this, what did they
  /// score, is it real. All of that is already known here, so it goes in the
  /// message and the reply can just be "congratulations, you're booked".
  Future<void> _redeemOnWhatsApp() async {
    final m = _mine ?? const {};
    final number = '${m['whatsapp_number'] ?? ''}';
    if (number.isEmpty) return;
    final name = '${m['name'] ?? ''}'.trim();
    final percent = (m['percent'] as num?)?.toDouble() ?? 0;
    final off = (m['discount_percent'] as num?)?.toInt() ?? 0;
    final pay = (m['you_pay'] as num?)?.toDouble() ?? 0;

    final text = Uri.encodeComponent(
        "Hi Altrobyte team! ${name.isEmpty ? '' : "I'm $name. "}"
        "I took the Scholarship Test and scored "
        "${percent.toStringAsFixed(0)}%, which earns $off% off — "
        "Rs ${pay.toStringAsFixed(0)} for the programme.\n\n"
        "My scholarship code is ${m['coupon_code'] ?? ''}.\n\n"
        "I'd like to claim it and book my seat.");
    final uri = Uri.parse('https://wa.me/$number?text=$text');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open WhatsApp')));
    }
  }

  /// The ladder, in rupees rather than percentages.
  ///
  /// "35% off" is a number somebody has to work out. "You pay Rs 6,500" is the
  /// number they actually care about, and putting both side by side is what
  /// makes the test worth sitting.
  Widget _ladder() {
    final slabs = (_config!['slabs'] as List?) ?? const [];
    final base = (_config!['base_amount'] as num?)?.toDouble() ?? 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6EBF3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('What your score is worth',
            style: GoogleFonts.poppins(
                fontSize: 15.5, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        for (final raw in slabs) ...[
          Builder(builder: (_) {
            final s = Map<String, dynamic>.from(raw as Map);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                SizedBox(
                  width: 62,
                  child: Text('${s['min_percent']}%+',
                      style: GoogleFonts.poppins(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary)),
                ),
                Expanded(
                  child: Text('${s['label'] ?? ''}',
                      style: GoogleFonts.inter(
                          fontSize: 13, color: AppColors.textSecondary)),
                ),
                Text('Rs ${s['you_pay']}',
                    style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.success)),
              ]),
            );
          }),
        ],
        const Divider(height: 20),
        Row(children: [
          const SizedBox(
              width: 62,
              child: Text('Below',
                  style: TextStyle(
                      fontSize: 13.5, color: AppColors.textSecondary))),
          const Expanded(
            child: Text('No scholarship — full fee',
                style: TextStyle(
                    fontSize: 13, color: AppColors.textSecondary)),
          ),
          Text('Rs ${base.toStringAsFixed(0)}',
              style: GoogleFonts.inter(
                  fontSize: 13.5, color: AppColors.textSecondary)),
        ]),
      ]),
    );
  }

  Widget _rules() {
    final days = (_config!['valid_days'] as num?)?.toInt() ?? 14;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6EBF3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('How it works',
            style: GoogleFonts.poppins(
                fontSize: 15.5, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        for (final line in [
          'Sign in, then take the test. The clock starts when you begin.',
          'One attempt each. Your score stands, so sit it when you are ready.',
          'You get your score the moment you submit.',
          'A code is issued in your name. It is yours alone and cannot be '
              'passed on.',
          'The code is valid for $days days. Enter it when you register.',
          'Send your score to the team on WhatsApp and they confirm your '
              'scholarship and hold your seat.',
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                margin: const EdgeInsets.only(top: 6, right: 9),
                width: 5,
                height: 5,
                decoration: const BoxDecoration(
                    color: AppColors.accent, shape: BoxShape.circle),
              ),
              Expanded(
                child: Text(line,
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        height: 1.55,
                        color: AppColors.textPrimary)),
              ),
            ]),
          ),
      ]),
    );
  }

  Widget _cta() => SizedBox(
        width: double.infinity,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.accent,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _start,
          child: Text('Start the test',
              style: GoogleFonts.poppins(
                  fontSize: 15.5, fontWeight: FontWeight.w700)),
        ),
      );

  static String _readable(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final m = seconds ~/ 60, s = seconds % 60;
    return s == 0 ? '$m min' : '$m min ${s}s';
  }
}
