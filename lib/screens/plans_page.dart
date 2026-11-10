// The programme's three plans, as a page to send to a student: altrobytelab.com/plans
//
// Everything that sells here is something true. The countdown runs to a date an admin sets (and the offer price disappears by
// itself when that date passes); the seats figure is the one the admin keeps; the struck-through prices are the standard fees.
// The numbers live once, at the top, so the cards, the comparison and the final call to action can never disagree.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';

const _navy = Color(0xFF0B1B3A);
const _navy2 = Color(0xFF12284F);
const _yellow = Color(0xFFFFD21F);
const _ink = Color(0xFF111827);
const _muted = Color(0xFF5B6475);
const _green = Color(0xFF12A150);

class ProgramPlan {
  final String key; // the name the server knows the plan by
  final String name;
  final String tag; // what makes this plan different, in three words
  final int offer; // the offer price, rupees
  final int standard; // the standard fee (struck through while the offer runs)
  final int months;
  final String period; // how the price is quoted
  final bool recommended;
  final List<String> features;
  const ProgramPlan(this.key, this.name, this.tag, this.offer, this.standard, this.months, this.period, this.features, {this.recommended = false});

  /// A plan as the server describes it. Null when something is missing, so a half-read answer never replaces good numbers.
  static ProgramPlan? fromJson(Map j) {
    final offer = j['offer'], standard = j['standard'], months = j['months'];
    if (j['key'] is! String || j['name'] is! String || offer is! num || standard is! num || months is! num || months < 1 || standard < offer) return null;
    return ProgramPlan('${j['key']}', '${j['name']}', '${j['tag'] ?? ''}', offer.round(), standard.round(), months.round(), '${j['period'] ?? ''}',
        [for (final f in (j['features'] as List? ?? const [])) '$f'],
        recommended: j['recommended'] == true);
  }

  int get saving => standard - offer;
  int get percentOff => ((saving * 100) / standard).round();
  int get perMonth => (offer / months).round();
}

const _base = ['Live classes (online / offline)', 'Live projects', 'Doubt support', 'Learning resources', 'Certificate', 'Access to recorded lectures'];

// The same two offers as the server (program_plans.py): monthly leads; three months together costs less than three
// monthly payments, and that saving is the only struck-out price.
const programPlans = [
  ProgramPlan('plan1', 'Monthly', 'Pay one month at a time', 9999, 9999, 1, 'per month', ['Mini lab set-up kit', ..._base], recommended: true),
  ProgramPlan('plan3', '3 months together', 'Kit + placement, pay once', 27999, 29997, 3, 'for 3 months', ['Mini lab set-up kit', 'Placement assistance', ..._base]),
];

/// ₹18,000 in the Indian style.
String inr(int n) {
  final s = n.toString();
  if (s.length <= 3) return '₹$s';
  var head = s.substring(0, s.length - 3);
  final tail = s.substring(s.length - 3);
  final parts = <String>[];
  while (head.length > 2) {
    parts.insert(0, head.substring(head.length - 2));
    head = head.substring(0, head.length - 2);
  }
  if (head.isNotEmpty) parts.insert(0, head);
  return '₹${parts.join(',')},$tail';
}

/// The moment an offer ends: the end of that day in India. Null when no date is set or it cannot be read.
DateTime? offerEnd(String? setting) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch((setting ?? '').trim());
  if (m == null) return null;
  final y = int.parse(m.group(1)!), mo = int.parse(m.group(2)!), d = int.parse(m.group(3)!);
  if (mo < 1 || mo > 12 || d < 1 || d > 31) return null;
  // 23:59:59 India time is 18:29:59 UTC the same day.
  return DateTime.utc(y, mo, d, 18, 29, 59);
}

/// How long is left, or null when there is no offer running (no date, or it has passed).
Duration? offerLeft(String? setting, DateTime now) {
  final end = offerEnd(setting);
  if (end == null) return null;
  final left = end.difference(now.toUtc());
  return left.isNegative ? null : left;
}

/// Is the offer price the price right now? Yes while the countdown runs, and also when no end date is set (an offer with no
/// announced end). Once a set date has passed, the standard fee is the price again, with nothing for anyone to remember to edit.
bool offerRunning(String? setting, DateTime now) => offerEnd(setting) == null || offerLeft(setting, now) != null;

/// Where the Enrol button of a plan goes: the enrolment form, with the plan carried along. Null when no form is open.
/// What a student actually pays: the fee with 18% GST, to the rupee.
int withGst(num fee) => (fee * 1.18).round();

String? enrolPath(String slug, ProgramPlan p) => slug.trim().isEmpty ? null : '/enroll/${Uri.encodeComponent(slug.trim())}?plan=${p.key}';

/// The message a plan's button opens WhatsApp with.
String enrolMessage(ProgramPlan p, bool offerOn) =>
    'Hi! I want to enrol in ${p.name} (${p.tag}) at Altrobyte: ${inr(offerOn ? p.offer : p.standard)} ${p.period} + GST. '
    'Please share the next batch and how to pay.';

class PlansPage extends StatefulWidget {
  const PlansPage({super.key});

  @override
  State<PlansPage> createState() => _PlansPageState();
}

class _PlansPageState extends State<PlansPage> {
  String _wa = '';
  String _slug = ''; // the enrolment form a student fills
  // 10 Nov 2026 (founder): the live programme's fee is 'contact for pricing'; the server says so (contact_pricing).
  bool _contact = true;
  List<ProgramPlan> _plans = programPlans; // the poster's numbers until the server answers
  String _seats = '';
  String _startLabel = '';
  String? _ends;
  Timer? _tick;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _load();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  // The plans, the number, the seats and the offer date all come from the server, where an admin keeps them true.
  Future<void> _load() async {
    try {
      final r = await ApiService.programPlans();
      if (!mounted) return;
      final plans = [for (final j in (r['plans'] as List? ?? const [])) ProgramPlan.fromJson(j as Map)];
      setState(() {
        if (plans.isNotEmpty && plans.every((p) => p != null)) _plans = plans.cast<ProgramPlan>();
        _wa = r['whatsapp_number'] as String? ?? '';
        _slug = '${r['enrol_slug'] ?? ''}';
        _seats = '${r['seats_left'] ?? ''}'.trim();
        _startLabel = '${r['start_label'] ?? ''}'.trim();
        _ends = r['offer_ends'] as String?;
        _contact = r['contact_pricing'] != false;
      });
    } catch (_) {}
  }

  Duration? get _left => offerLeft(_ends, _now);
  bool get _offerOn => offerRunning(_ends, _now);

  /// A question, on WhatsApp. (Never the college-partnership form: that page is for institutions, not students.)
  Future<void> _open(String text) async {
    if (_wa.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Our WhatsApp number is loading. Please try again in a moment.')));
      _load();
      return;
    }
    final uri = Uri.parse('https://wa.me/$_wa?text=${Uri.encodeComponent(text)}');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open WhatsApp')));
    }
  }

  /// Enrol: the enrolment form for this plan, then payment. WhatsApp only if no form is open.
  Future<void> _enrol(ProgramPlan p) async {
    if (_slug.isEmpty) await _load(); // tapped before the page finished loading: ask once more
    if (!mounted) return;
    final path = enrolPath(_slug, p);
    if (path != null) {
      context.go(path);
    } else {
      await _open(enrolMessage(p, _offerOn));
    }
  }

  /// Seat booking (9 Nov 2026, founder: ₹999 is fine): ₹847 + GST holds a seat and is adjusted in the fee.
  Future<void> _bookSeat() async {
    if (_slug.isEmpty) await _load();
    if (!mounted) return;
    if (_slug.trim().isNotEmpty) {
      context.go('/enroll/${Uri.encodeComponent(_slug.trim())}?plan=token');
    } else {
      await _open('Hi! I want to book my seat for ₹999 in the next batch.');
    }
  }

  // ── pieces ─────────────────────────────────────────────────────────────────

  Widget _unit(int value, String label) => Container(
        width: 52,
        padding: const EdgeInsets.symmetric(vertical: 6),
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(color: _navy, borderRadius: BorderRadius.circular(8)),
        child: Column(children: [
          Text(value.toString().padLeft(2, '0'), style: GoogleFonts.poppins(color: _yellow, fontWeight: FontWeight.w700, fontSize: 18, height: 1.1)),
          Text(label, style: GoogleFonts.inter(color: Colors.white70, fontSize: 9.5, letterSpacing: 0.6)),
        ]),
      );

  Widget _countdown() {
    final left = _left;
    if (left == null) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      color: _yellow,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, spacing: 12, runSpacing: 8, children: [
        Text('Offer price ends in', style: GoogleFonts.poppins(color: _navy, fontWeight: FontWeight.w700, fontSize: 14)),
        Row(mainAxisSize: MainAxisSize.min, children: [
          _unit(left.inDays, 'DAYS'),
          _unit(left.inHours % 24, 'HRS'),
          _unit(left.inMinutes % 60, 'MIN'),
          _unit(left.inSeconds % 60, 'SEC'),
        ]),
      ]),
    );
  }

  Widget _chip(IconData icon, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(99), border: Border.all(color: Colors.white24)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: _yellow),
          const SizedBox(width: 6),
          Text(text, style: GoogleFonts.inter(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600)),
        ]),
      );

  Widget _hero(bool wide) => Container(
        width: double.infinity,
        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_navy, _navy2])),
        padding: EdgeInsets.fromLTRB(20, wide ? 56 : 36, 20, wide ? 110 : 90),
        child: Column(children: [
          Text('ALTROBYTE AUTOMATION PVT. LTD.', style: GoogleFonts.poppins(color: _yellow, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 2)),
          const SizedBox(height: 14),
          Text('Become a product engineer.\nNot just a certificate holder.',
              textAlign: TextAlign.center, style: GoogleFonts.poppins(color: Colors.white, fontSize: wide ? 40 : 27, fontWeight: FontWeight.w800, height: 1.15)),
          const SizedBox(height: 14),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Text('Live classes, real projects and a lab kit on your own desk. Pick the plan that fits how far you want to go.',
                textAlign: TextAlign.center, style: GoogleFonts.inter(color: Colors.white70, fontSize: wide ? 16.5 : 14.5, height: 1.55)),
          ),
          const SizedBox(height: 20),
          Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
            _chip(Icons.memory_rounded, 'Embedded Systems'),
            _chip(Icons.cloud_outlined, 'IoT'),
            _chip(Icons.psychology_outlined, 'AI'),
            _chip(Icons.settings_suggest_outlined, 'Product Engineering'),
          ]),
          if (_seats.isNotEmpty || _startLabel.isNotEmpty) ...[
            const SizedBox(height: 18),
            Wrap(alignment: WrapAlignment.center, spacing: 10, runSpacing: 8, children: [
              if (_startLabel.isNotEmpty) _fact(Icons.event_available_rounded, _startLabel),
              if (_seats.isNotEmpty && _seats != '0') _fact(Icons.local_fire_department_rounded, '$_seats seats left in this batch'),
            ]),
          ],
        ]),
      );

  Widget _fact(IconData icon, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(color: _yellow, borderRadius: BorderRadius.circular(99)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: _navy),
          const SizedBox(width: 6),
          Text(text, style: GoogleFonts.inter(color: _navy, fontSize: 12.5, fontWeight: FontWeight.w700)),
        ]),
      );

  Widget _planCard(ProgramPlan p) {
    final on = _offerOn;
    final price = on ? p.offer : p.standard;
    final hot = p.recommended;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: hot ? _yellow : const Color(0xFFE5E8EE), width: hot ? 2.5 : 1),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: hot ? 0.18 : 0.08), blurRadius: hot ? 34 : 20, offset: const Offset(0, 12))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          decoration: BoxDecoration(color: hot ? _navy : const Color(0xFFF4F6FA), borderRadius: const BorderRadius.vertical(top: Radius.circular(18))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(p.name, style: GoogleFonts.poppins(color: hot ? Colors.white : _ink, fontWeight: FontWeight.w800, fontSize: 22)),
              const Spacer(),
              if (hot)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: _yellow, borderRadius: BorderRadius.circular(99)),
                  child: Text('RECOMMENDED', style: GoogleFonts.inter(color: _navy, fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
                ),
            ]),
            Text(p.tag, style: GoogleFonts.inter(color: hot ? Colors.white70 : _muted, fontSize: 13.5, fontWeight: FontWeight.w600)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (_contact) ...[
              Text('Contact for pricing', style: GoogleFonts.poppins(color: _ink, fontSize: 26, fontWeight: FontWeight.w800, height: 1.1)),
              const SizedBox(height: 4),
              Text('The fee depends on the batch and the mode. Hold your seat for ₹999, adjusted in your fee.',
                  style: GoogleFonts.inter(color: _muted, fontSize: 12.5, height: 1.4)),
            ],
            if (!_contact && on && p.saving > 0)
              Text(inr(p.standard), style: GoogleFonts.inter(color: _muted, fontSize: 15, decoration: TextDecoration.lineThrough)),
            if (!_contact) const SizedBox(height: 4),
            if (!_contact) Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(inr(price), style: GoogleFonts.poppins(color: _ink, fontSize: 36, fontWeight: FontWeight.w800, height: 1.05)),
              const SizedBox(width: 8),
              Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(p.months == 1 ? '+ GST / month' : '+ GST', style: GoogleFonts.inter(color: _muted, fontSize: 13))),
            ]),
            if (!_contact) Text('${inr(withGst(price))} including 18% GST · ${p.period}', style: GoogleFonts.inter(color: _muted, fontSize: 12.5)),
            const SizedBox(height: 6),
            if (!_contact && on && p.saving > 0) Text('You save ${inr(p.saving)} against paying monthly', style: GoogleFonts.inter(color: _green, fontSize: 13, fontWeight: FontWeight.w700)),
            if (p.months == 1) Text('Stop or carry on each month', style: GoogleFonts.inter(color: _muted, fontSize: 12.5)),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(color: const Color(0xFFEFF5FF), borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                const Icon(Icons.calendar_month_rounded, size: 17, color: Color(0xFF1D4ED8)),
                const SizedBox(width: 8),
                Expanded(child: Text('Classes on weekdays and weekends', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: _ink))),
              ]),
            ),
            const SizedBox(height: 12),
            for (final f in p.features)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.check_circle_rounded, size: 18, color: f.startsWith('Mini lab') || f.startsWith('Placement') ? _green : _navy),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(f,
                        style: GoogleFonts.inter(fontSize: 13.5, height: 1.35, color: _ink, fontWeight: f.startsWith('Mini lab') || f.startsWith('Placement') ? FontWeight.w700 : FontWeight.w400)),
                  ),
                ]),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _contact ? _bookSeat() : _enrol(p),
                style: ElevatedButton.styleFrom(
                  backgroundColor: hot ? _yellow : _navy,
                  foregroundColor: hot ? _navy : Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(_contact ? 'Book my seat · ₹999' : 'Enrol in ${p.name}', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ),
            const SizedBox(height: 6),
            Center(child: Text('Two steps: your details, then payment by UPI.', style: GoogleFonts.inter(color: _muted, fontSize: 11.5))),
            Center(
              child: TextButton(
                onPressed: _contact ? () => _open('Hi! What is the fee for ${p.name} (${p.tag}) at Altrobyte, and when does the next batch start?') : _bookSeat,
                child: Text(_contact ? 'Ask the fee on WhatsApp' : 'Not ready? Book your seat for ₹999 (adjusted in your fee)',
                    textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: _navy)),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _emi() => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE5E8EE))),
        child: Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 20, runSpacing: 14, children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: _navy, borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.credit_card_rounded, color: _yellow, size: 26),
            ),
            const SizedBox(width: 14),
            Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text('Pay month by month', style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 17, color: _ink)),
              Text('Month 1 your first device and its PCB design; month 2 it goes online', style: GoogleFonts.inter(color: _muted, fontSize: 13)),
            ]),
          ]),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(color: const Color(0xFFFFF6CC), borderRadius: BorderRadius.circular(12)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(_contact ? 'Contact for pricing' : inr(9999), style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 22, color: _ink, height: 1.1)),
              Text(_contact ? 'Seat booking ₹999, adjusted in your fee' : '+ GST a month (3 months together: ₹27,999 + GST)', style: GoogleFonts.inter(fontSize: 12, color: _muted)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            for (final t in const ['No high upfront cost', 'Lab kit from day one', 'Stop or carry on each month'])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.check_circle_rounded, size: 16, color: _green),
                  const SizedBox(width: 7),
                  Text(t, style: GoogleFonts.inter(fontSize: 13, color: _ink)),
                ]),
              ),
          ]),
        ]),
      );

  Widget _title(String text, [String? sub]) => Padding(
        padding: const EdgeInsets.only(top: 44, bottom: 18),
        child: Column(children: [
          Text(text, textAlign: TextAlign.center, style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 24, color: _ink)),
          if (sub != null) ...[
            const SizedBox(height: 6),
            Text(sub, textAlign: TextAlign.center, style: GoogleFonts.inter(color: _muted, fontSize: 14.5, height: 1.5)),
          ],
        ]),
      );

  Widget _compare() {
    // One tick per plan shown, from that plan's own features, so the table always matches the cards.
    const rows = <(String, String?)>[
      ('Live classes (online / offline)', null),
      ('Live projects', null),
      ('Doubt support', null),
      ('Learning resources and recorded lectures', null),
      ('Certificate', null),
      ('Mini lab set-up kit', 'Mini lab set-up kit'),
      ('Placement assistance', 'Placement assistance'),
    ];
    Widget cell(Widget c, {int flex = 1, bool head = false}) =>
        Expanded(flex: flex, child: Padding(padding: EdgeInsets.symmetric(vertical: head ? 12 : 11, horizontal: 8), child: c));
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE5E8EE))),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        Container(
          color: _navy,
          child: Row(children: [
            cell(Text('What you get', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)), flex: 3, head: true),
            for (final p in _plans)
              cell(Center(child: Text(p.name, style: GoogleFonts.inter(color: p.recommended ? _yellow : Colors.white, fontWeight: FontWeight.w700, fontSize: 13))), head: true),
          ]),
        ),
        for (var i = 0; i < rows.length; i++)
          Container(
            color: i.isEven ? Colors.white : const Color(0xFFF8FAFC),
            child: Row(children: [
              cell(Text(rows[i].$1, style: GoogleFonts.inter(fontSize: 13.5, color: _ink)), flex: 3),
              for (final has in [for (final p in _plans) rows[i].$2 == null || p.features.contains(rows[i].$2)])
                cell(Center(child: Icon(has ? Icons.check_circle_rounded : Icons.remove_rounded, size: 19, color: has ? _green : const Color(0xFFCBD2DC)))),
            ]),
          ),
      ]),
    );
  }

  Widget _why() {
    const items = <(IconData, String, String)>[
      (Icons.memory_rounded, 'Hands-on learning', 'You build on real boards from the first week, not on slides.'),
      (Icons.lightbulb_outline_rounded, 'Real world projects', 'Projects shaped like the products the industry actually ships.'),
      (Icons.code_rounded, 'Expert mentorship', 'Engineers who build these systems answer your doubts.'),
      (Icons.trending_up_rounded, 'Career and placement support', 'Help turning what you built into a job (3-month plan).'),
    ];
    return Wrap(spacing: 14, runSpacing: 14, alignment: WrapAlignment.center, children: [
      for (final it in items)
        Container(
          width: 250,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE5E8EE))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: _yellow, borderRadius: BorderRadius.circular(10)),
              child: Icon(it.$1, color: _navy, size: 22),
            ),
            const SizedBox(height: 12),
            Text(it.$2, style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15, color: _ink)),
            const SizedBox(height: 4),
            Text(it.$3, style: GoogleFonts.inter(color: _muted, fontSize: 13, height: 1.5)),
          ]),
        ),
    ]);
  }

  Widget _faq() {
    const qa = <(String, String)>[
      ('What is the fee?', 'It depends on the batch and the mode (online or in Indore). Message us on WhatsApp and a mentor shares the exact fee. Your seat is held for ₹999, adjusted in the fee.'),
      ('Can I start monthly and switch to 3 months?', 'Yes. Within 30 days of starting, move to the 3-month plan by paying only the difference.'),
      ('Is there a scholarship?', 'Yes. The free scholarship test can take up to ₹3,000 off your first month.'),
      ('Can I pay monthly?', 'Yes. Pay one month at a time, one stage a month, and decide each month whether to carry on. Or pay for 3 months together and save.'),
      ('What are the class timings?', 'Weekday batch: Monday to Friday, 1.5 hours a day. Weekend batch: Saturday and Sunday, 3 hours a day.'),
      ('Are classes online or offline?', 'Both. Live classes run online and offline at our Indore centre (5th Floor, Gravity Mall, Mechanic Nagar).'),
      ('What is the mini lab set-up kit?', 'A hardware kit for your own desk, included in every plan, so you can practise outside class.'),
      ('What if I miss a class?', 'Every plan includes access to the recorded lectures, and doubt support to catch up.'),
      ('Which plan should I choose?', 'Monthly if you want to start now and decide as you go. 3 months together if you are sure you want the whole journey and placement assistance; it costs less.'),
    ];
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE5E8EE))),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: Column(children: [
          for (final x in qa)
            ExpansionTile(
              title: Text(x.$1, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14.5, color: _ink)),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              expandedAlignment: Alignment.centerLeft,
              children: [Text(x.$2, style: GoogleFonts.inter(color: _muted, fontSize: 13.5, height: 1.55))],
            ),
        ]),
      ),
    );
  }

  Widget _closing() {
    final best = _plans.last;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 44),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 34),
      decoration: BoxDecoration(gradient: const LinearGradient(colors: [_navy, _navy2]), borderRadius: BorderRadius.circular(22)),
      child: Column(children: [
        Text('Learn. Build. Grow.', style: GoogleFonts.poppins(color: _yellow, fontWeight: FontWeight.w800, fontSize: 26)),
        const SizedBox(height: 8),
        Text(
            _left != null
                ? 'The offer price is open until the timer above runs out. A two-minute chat is enough to hold your seat.'
                : 'A two-minute chat is enough to hold your seat in the next batch.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: Colors.white70, fontSize: 14.5, height: 1.55)),
        const SizedBox(height: 18),
        Wrap(alignment: WrapAlignment.center, spacing: 10, runSpacing: 10, children: [
          ElevatedButton.icon(
            onPressed: () => _contact ? _open('Hi! What is the fee for the Altrobyte live programme, and when does the next batch start?') : _enrol(best),
            icon: const Icon(Icons.send_rounded, size: 18),
            label: Text(_contact ? 'Ask the fee on WhatsApp' : 'Enrol in ${best.name}', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(backgroundColor: _yellow, foregroundColor: _navy, elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16)),
          ),
          OutlinedButton(
            onPressed: _bookSeat,
            style: OutlinedButton.styleFrom(foregroundColor: _yellow, side: const BorderSide(color: _yellow), padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16)),
            child: Text('Book my seat · ₹999', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
          ),
          OutlinedButton(
            onPressed: () => _open('Hi! I have a question about the Altrobyte programme plans (IOT).'),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54), padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16)),
            child: Text('Ask a question first', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ]),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final wide = w >= 980;
    final cards = [for (final p in _plans) _planCard(p)];
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      bottomNavigationBar: wide
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, -2))]),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Text(_contact ? 'Seat ₹999' : 'From ${inr(_offerOn ? _plans.first.offer : _plans.first.standard)}', style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 15, color: _ink)),
                      Text(_contact ? 'adjusted in your fee' : '+ GST a month', style: GoogleFonts.inter(fontSize: 11.5, color: _muted)),
                    ]),
                  ),
                  ElevatedButton(
                    onPressed: () => _contact ? _bookSeat() : _enrol(_plans.firstWhere((p) => p.recommended, orElse: () => _plans.first)),
                    style: ElevatedButton.styleFrom(backgroundColor: _yellow, foregroundColor: _navy, elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13)),
                    child: Text(_contact ? 'Book my seat' : 'Enrol now', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
                  ),
                ]),
              ),
            ),
      body: Column(children: [
        _countdown(),
        Expanded(
          child: SingleChildScrollView(
            child: Column(children: [
              _hero(wide),
              Transform.translate(
                offset: const Offset(0, -64),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1120),
                    child: Column(children: [
                      if (wide)
                        IntrinsicHeight(
                          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                            for (var i = 0; i < cards.length; i++) ...[if (i > 0) const SizedBox(width: 18), Expanded(child: cards[i])],
                          ]),
                        )
                      else
                        for (final c in cards) Padding(padding: const EdgeInsets.only(bottom: 16), child: c),
                      const SizedBox(height: 22),
                      _emi(),
                      _title('Compare the plans', 'Every plan has the full teaching. The kit and placement are what change.'),
                      _compare(),
                      _title('Why students choose Altrobyte'),
                      _why(),
                      _title('Questions, answered'),
                      _faq(),
                      _closing(),
                      const SizedBox(height: 28),
                      Text('Prices are in Indian rupees; 18% GST is added. © Altrobyte Automation Pvt. Ltd.', textAlign: TextAlign.center, style: GoogleFonts.inter(color: _muted, fontSize: 12)),
                    ]),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}
