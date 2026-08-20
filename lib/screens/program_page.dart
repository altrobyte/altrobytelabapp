// The Product Engineering Program page.
//
// Deliberately not linked from anywhere. It lives at its own URL and is shared
// directly — the public pricing page still quotes programmes on request, and
// this is the page you send to someone who asked.
//
// Everything on it is content, so it reads top to bottom as one argument:
// what the programme is, which mode fits you, what you build, what it costs,
// and how to start. The two prices and the group table are the only numbers,
// and they are defined once at the top so they cannot drift between the fee
// section and the final call to action.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_colors.dart';
import '../services/api_service.dart';
import '../widgets/showcase_widgets.dart';
import 'student/showcase_screens.dart';

const _navy = Color(0xFF0B2450);
const _blue = Color(0xFF1565C0);
const _amber = Color(0xFFFFC107);
const _ink = Color(0xFF16202E);

/// One source for every number on the page. A price repeated in three places
/// is a price that will disagree with itself the first time one changes.
class _Plan {
  final String name;
  final String tagline;
  final String schedule;
  final String duration;
  final String hours;
  final int fee;
  /// The standard fee this mode is normally sold at. Struck through beside the
  /// current price, so it must be a price actually charged — an invented
  /// "before" figure is a misleading advertisement under the CCPA guidelines,
  /// and one complaint is enough. Set it to the same value as `fee` to hide
  /// the strike entirely.
  final int listFee;
  final List<String> bestFor;
  final String outcome;
  const _Plan({
    required this.name,
    required this.tagline,
    required this.schedule,
    required this.duration,
    required this.hours,
    required this.fee,
    required this.listFee,
    required this.bestFor,
    required this.outcome,
  });

  int get saving => listFee - fee;
  bool get discounted => saving > 0;
}

const _fastTrack = _Plan(
  name: 'Product Engineering Fast Track',
  tagline: 'Complete the programme in just 4–5 weeks.',
  schedule: 'Monday – Friday · 3 hours a day',
  duration: '4–5 weeks',
  hours: '~60–70 hours of hands-on learning',
  fee: 19000,
  listFee: 25000,
  bestFor: [
    'Engineering students',
    'Freshers',
    'Students with dedicated time',
    'Learners who want an intensive experience',
    'Anyone who wants to build their first serious embedded/IoT product quickly',
  ],
  outcome: 'One complete Product Engineering project that you can '
      'demonstrate, explain and showcase.',
);

const _weekend = _Plan(
  name: 'Professional Product Engineering',
  tagline: 'Build your product while continuing college or work.',
  schedule: 'Saturday + Sunday · 3 hours a day',
  duration: '3 months',
  hours: '~72 hours of guided product engineering',
  fee: 29000,
  listFee: 36000,
  bestFor: [
    'College students',
    'Working professionals',
    'Engineers',
    'Students who prefer weekend learning',
    'Learners who want more time between sessions to implement and debug',
  ],
  outcome: 'A portfolio-ready Product Engineering project, practical '
      'engineering experience, and the ability to explain how the product '
      'was designed and built.',
);

const _labFee = 6000;

/// Group slabs. Stated against the Fast Track fee, which is what they are
/// derived from — a weekend group would need its own row and does not have one.
const _groupSlabs = [
  ('1–2 students', 19000),
  ('3–4 students', 18500),
  ('5–6 students', 18000),
  ('7–8 students', 17500),
  ('9–10 students', 17000),
];

String _rs(int n) {
  final s = n.toString();
  if (s.length <= 3) return '₹$s';
  final head = s.substring(0, s.length - 3);
  return '₹$head,${s.substring(s.length - 3)}';
}

class ProgramPage extends StatefulWidget {
  const ProgramPage({super.key});

  @override
  State<ProgramPage> createState() => _ProgramPageState();
}

class _ProgramPageState extends State<ProgramPage> {
  String _waNumber = '';
  String _seatsLeft = '';
  List<dynamic> _placements = [];
  List<dynamic> _reviews = [];

  @override
  void initState() {
    super.initState();
    _loadNumber();
    _loadResults();
  }

  /// The page asks for money four screens down. What it owes a reader before
  /// that is evidence that anyone who paid it got anything back.
  Future<void> _loadResults() async {
    for (final entry in {'placement': 0, 'review': 1}.entries) {
      try {
        final items = await ApiService.getShowcase(entry.key);
        if (!mounted) continue;
        setState(() {
          if (entry.key == 'placement') {
            _placements = items;
          } else {
            _reviews = items;
          }
        });
      } catch (_) {}
    }
  }

  /// The enquiry number is a setting, so this page cannot be the one place it
  /// is hardcoded and then forgotten.
  Future<void> _loadNumber() async {
    try {
      final r = await ApiService.getRoadmap('product-engineering');
      final n = r['whatsapp_number'] as String? ?? '';
      final seats = '${r['seats_left'] ?? ''}';
      if (mounted) {
        setState(() {
          _waNumber = n;
          _seatsLeft = seats;
        });
      }
    } catch (_) {}
  }

  Future<void> _enquire(String about) async {
    final text = Uri.encodeComponent(
        "Hi! I want to join the $about at Altrobyte. Could you tell me about "
        "the next batch and how to enrol?");
    final uri = _waNumber.isEmpty
        ? Uri.parse('https://lab.altrobyte.com/partner')
        : Uri.parse('https://wa.me/$_waNumber?text=$text');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open WhatsApp')));
    }
  }

  Future<void> _share() async {
    const url = 'https://lab.altrobyte.com/program';
    await Clipboard.setData(const ClipboardData(text: url));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Page link copied')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width > 900;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _ink,
        elevation: 0,
        title: Text('Product Engineering Program',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16)),
        actions: [
          IconButton(
              tooltip: 'Copy link',
              onPressed: _share,
              icon: const Icon(Icons.link_rounded, size: 21)),
        ],
      ),
      body: ListView(children: [
        _hero(wide),
        _section(child: _modes(wide)),
        _section(color: const Color(0xFFF7F9FC), child: _lab(wide)),
        _section(child: _whatYouBuild(wide)),
        _section(color: const Color(0xFFF7F9FC), child: _stack(wide)),
        _section(child: _portfolio(wide)),
        _section(color: const Color(0xFFF7F9FC), child: _career(wide)),
        _section(child: _forWhom(wide)),
        if (_placements.isNotEmpty || _reviews.isNotEmpty)
          _section(color: const Color(0xFFF7F9FC), child: _results(wide)),
        _section(color: _navy, child: _fees(wide)),
        _section(child: _groupUnlock(wide)),
        _section(color: const Color(0xFFF7F9FC), child: _whyHandsOn(wide)),
        _finalCta(wide),
        _footer(),
      ]),
    );
  }

  // ── Layout helpers ─────────────────────────────────────────────────────────

  Widget _section({required Widget child, Color? color}) => Container(
        width: double.infinity,
        color: color ?? Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1080),
            child: child,
          ),
        ),
      );

  Widget _h2(String text, {Color color = _ink}) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: GoogleFonts.poppins(
                fontSize: 26, fontWeight: FontWeight.w700, height: 1.25, color: color)),
      );

  Widget _lead(String text, {Color? color}) => Padding(
        padding: const EdgeInsets.only(bottom: 22),
        child: Text(text,
            style: GoogleFonts.inter(
                fontSize: 15, height: 1.65, color: color ?? AppColors.textSecondary)),
      );

  Widget _bullets(List<String> items, {Color? color}) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final b in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(
                  padding: const EdgeInsets.only(top: 7, right: 10),
                  child: Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                          color: color ?? _blue, shape: BoxShape.circle)),
                ),
                Expanded(
                  child: Text(b,
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          height: 1.55,
                          color: color ?? AppColors.textPrimary)),
                ),
              ]),
            ),
        ],
      );

  // ── Sections ───────────────────────────────────────────────────────────────

  Widget _hero(bool wide) => Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: wide ? 64 : 40, horizontal: 20),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_navy, Color(0xFF16407F), _blue],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1080),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                decoration: BoxDecoration(
                    color: _amber, borderRadius: BorderRadius.circular(20)),
                child: Text('ALTROBYTE',
                    style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                        color: const Color(0xFF3E2700))),
              ),
              const SizedBox(height: 18),
              Text('Build. Debug. Engineer. Ship.',
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: wide ? 42 : 30,
                      fontWeight: FontWeight.w800,
                      height: 1.15)),
              const SizedBox(height: 12),
              Text(
                  'Learn Product Engineering by building a real product — '
                  'not by watching lectures.',
                  style: GoogleFonts.inter(
                      color: _amber, fontSize: wide ? 17 : 15, height: 1.5)),
              const SizedBox(height: 20),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Text(
                    'Most courses teach technologies one by one. Here you learn how '
                    'those technologies come together to design, build, test and '
                    'present a real-world product.\n\n'
                    'You do not just learn Embedded C, ESP32, IoT or PCB design. You '
                    'learn how an engineer takes a product from an idea to a demo.',
                    style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.88),
                        fontSize: 14.5,
                        height: 1.7)),
              ),
              const SizedBox(height: 22),
              _pipeline(const [
                'Idea', 'Requirements', 'Architecture', 'Hardware', 'Firmware',
                'Connectivity', 'Testing', 'Documentation', 'Demo',
              ]),
              const SizedBox(height: 28),
              Wrap(spacing: 12, runSpacing: 12, children: [
                _cta('Talk to a mentor', () => _enquire('Product Engineering Program'),
                    filled: true),
                _cta('See the full roadmap',
                    () => context.go('/roadmap/product-engineering')),
              ]),
            ]),
          ),
        ),
      );

  Widget _pipeline(List<String> steps) => Wrap(
        spacing: 6,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(steps[i],
                  style: GoogleFonts.inter(
                      color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600)),
            ),
            if (i != steps.length - 1)
              Icon(Icons.arrow_forward_rounded,
                  size: 13, color: Colors.white.withValues(alpha: 0.45)),
          ],
        ],
      );

  Widget _cta(String label, VoidCallback onTap, {bool filled = false}) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
          decoration: BoxDecoration(
            color: filled ? _amber : Colors.transparent,
            border: filled ? null : Border.all(color: Colors.white54),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: filled ? const Color(0xFF3E2700) : Colors.white)),
        ),
      );

  Widget _modes(bool wide) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _h2('Choose your learning mode'),
          _lead('Same programme, same product, same workflow. The only thing '
              'that changes is the pace — and which one you can actually fit '
              'around your week.'),
          _seatsBanner(),
          if (wide)
            IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Expanded(child: _planCard(_fastTrack, '⚡')),
                const SizedBox(width: 18),
                Expanded(child: _planCard(_weekend, '🏭')),
              ]),
            )
          else
            Column(children: [
              _planCard(_fastTrack, '⚡'),
              const SizedBox(height: 16),
              _planCard(_weekend, '🏭'),
            ]),
        ],
      );

  Widget _planCard(_Plan p, String emoji) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black.withValues(alpha: 0.09)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 14,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$emoji  ${p.name}',
              style: GoogleFonts.poppins(
                  fontSize: 18, fontWeight: FontWeight.w700, height: 1.3)),
          const SizedBox(height: 6),
          Text(p.tagline,
              style: GoogleFonts.inter(
                  fontSize: 13.5, height: 1.5, color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          _fact(Icons.calendar_month_rounded, p.schedule),
          _fact(Icons.schedule_rounded, p.duration),
          _fact(Icons.timelapse_rounded, p.hours),
          const SizedBox(height: 16),
          _price(p),
          const SizedBox(height: 4),
          Text('Optional Mini Product Lab: ${_rs(_labFee)} + GST',
              style: GoogleFonts.inter(
                  fontSize: 12.5, color: AppColors.textSecondary)),
          // Right here, not four screens down. Someone who reads the price and
          // decides it is too much never reaches a discount further along.
          if (p.fee == _fastTrack.fee) ...[
            const SizedBox(height: 10),
            InkWell(
              onTap: () => _enquire('${p.name} (group booking)'),
              child: Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32).withValues(alpha: 0.08),
                  border: Border.all(
                      color: const Color(0xFF2E7D32).withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Row(children: [
                  const Icon(Icons.groups_rounded,
                      size: 17, color: Color(0xFF2E7D32)),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                        'Coming with friends? From ${_rs(16000)} each — '
                        'see group pricing',
                        style: GoogleFonts.inter(
                            fontSize: 12.5,
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1B5E20))),
                  ),
                ]),
              ),
            ),
          ],
          const SizedBox(height: 18),
          Text('BEST FOR',
              style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.7,
                  color: _blue)),
          const SizedBox(height: 8),
          _bullets(p.bestFor),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: _blue.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('WHAT YOU WALK AWAY WITH',
                  style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.7,
                      color: _blue)),
              const SizedBox(height: 5),
              Text(p.outcome,
                  style: GoogleFonts.inter(fontSize: 13, height: 1.55)),
            ]),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => _enquire(p.name),
              style: FilledButton.styleFrom(
                backgroundColor: _navy,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
              ),
              child: Text('Join ${p.name.split(' ').last == 'Track' ? 'Fast Track' : 'Weekend Program'}',
                  style: GoogleFonts.poppins(
                      fontSize: 14.5, fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      );

  /// Current price against the standard one. Reading 18,000 alone gives a
  /// reader nothing to weigh it against; reading it beside 25,000 does the
  /// weighing for them.
  Widget _price(_Plan p, {bool onDark = false}) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (p.discounted)
            Row(children: [
              Text(_rs(p.listFee),
                  style: GoogleFonts.inter(
                      fontSize: 15,
                      color: onDark
                          ? Colors.white.withValues(alpha: 0.55)
                          : AppColors.textSecondary,
                      decoration: TextDecoration.lineThrough,
                      decorationThickness: 2)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFD32F2F),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text('SAVE ${_rs(p.saving)}',
                    style: GoogleFonts.inter(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                        color: Colors.white)),
              ),
            ]),
          const SizedBox(height: 2),
          Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(_rs(p.fee),
                    style: GoogleFonts.poppins(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: onDark ? _amber : _navy)),
                const SizedBox(width: 6),
                Text('+ GST',
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        color: onDark
                            ? Colors.white.withValues(alpha: 0.75)
                            : AppColors.textSecondary)),
              ]),
        ],
      );

  /// Red, specific, and true because the number comes from a setting an admin
  /// keeps current. A permanent "10 seats left" is just decoration.
  Widget _seatsBanner() {
    final n = int.tryParse(_seatsLeft);
    if (n == null || n <= 0) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFD32F2F).withValues(alpha: 0.08),
        border: Border.all(color: const Color(0xFFD32F2F).withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(children: [
        const Icon(Icons.local_fire_department_rounded,
            size: 18, color: Color(0xFFD32F2F)),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
              n == 1
                  ? 'Only 1 seat left in this batch — batches are capped at 10 '
                      'so everyone gets bench time.'
                  : 'Only $n seats left in this batch — batches are capped at 10 '
                      'so everyone gets bench time.',
              style: GoogleFonts.inter(
                  fontSize: 13,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFB71C1C))),
        ),
      ]),
    );
  }

  Widget _fact(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [
          Icon(icon, size: 15, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: GoogleFonts.inter(fontSize: 13, height: 1.4)),
          ),
        ]),
      );

  Widget _lab(bool wide) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _h2('🧰  Mini Product Lab'),
          _lead('Build with your own engineering lab. ${_rs(_labFee)} + GST, optional.'),
          Text(
              'The Mini Product Lab provides the hardware and tools needed for '
              'hands-on product development during the programme. Depending on the '
              'project, it includes components such as:',
              style: GoogleFonts.inter(
                  fontSize: 14, height: 1.65, color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final c in const [
              'ESP32 / STM32 boards', 'Sensors', 'OLED display', 'Relay', 'Servo',
              'Connectivity components', 'Prototyping accessories',
              'Soldering equipment', 'Multimeter', 'Enclosure components',
            ])
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.black.withValues(alpha: 0.09)),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(c,
                    style: GoogleFonts.inter(
                        fontSize: 12.5, fontWeight: FontWeight.w500)),
              ),
          ]),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _navy,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text("Don't just watch the product being built. Build it yourself.",
                style: GoogleFonts.poppins(
                    color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
          ),
        ],
      );

  Widget _whatYouBuild(bool wide) {
    const stages = [
      ('Understand', 'Product requirement', 'What problem are we solving?'),
      ('Design', 'System architecture', 'How will the product work?'),
      ('Build', 'Hardware + firmware',
          'Microcontroller, sensors, peripherals and embedded software.'),
      ('Connect', 'IoT / communication', 'Connect the product to the outside world.'),
      ('Debug', 'Test → find → fix → improve', 'The part no tutorial covers.'),
      ('Productize', 'Documentation + BOM', 'Make it explainable to someone else.'),
      ('Ship', 'Final product demonstration', 'Present the working product.'),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _h2('🚀  What you will build'),
      _lead('The programme follows a product-development approach, in this order.'),
      for (var i = 0; i < stages.length; i++)
        _stageRow(i + 1, stages[i].$1, stages[i].$2, stages[i].$3,
            last: i == stages.length - 1),
    ]);
  }

  Widget _stageRow(int n, String title, String subtitle, String body,
          {bool last = false}) =>
      IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Column(children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(color: _blue, shape: BoxShape.circle),
              child: Center(
                child: Text('$n',
                    style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700)),
              ),
            ),
            if (!last)
              Expanded(
                child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: _blue.withValues(alpha: 0.22)),
              ),
          ]),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('$title — $subtitle',
                    style: GoogleFonts.poppins(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(body,
                    style: GoogleFonts.inter(
                        fontSize: 13.5,
                        height: 1.55,
                        color: AppColors.textSecondary)),
              ]),
            ),
          ),
        ]),
      );

  Widget _stack(bool wide) {
    const groups = [
      ('Embedded', [
        'Embedded C/C++', 'ESP32', 'STM32', 'GPIO', 'ADC', 'PWM',
        'UART', 'I²C', 'SPI', 'Interrupts', 'Timers', 'DMA',
      ]),
      ('Real-time systems', [
        'FreeRTOS', 'Tasks', 'Scheduling', 'Queues', 'Synchronization',
        'Embedded debugging',
      ]),
      ('IoT', [
        'MQTT', 'HTTP', 'REST APIs', 'Device connectivity', 'Cloud integration',
        'IoT dashboards',
      ]),
      ('Hardware', [
        'Circuit design', 'PCB fundamentals', 'KiCad', 'BOM', 'Prototyping',
        'Testing',
      ]),
      ('Engineering tools', [
        'Git', 'GitHub', 'Debugging tools', 'Technical documentation',
      ]),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _h2('🧠  Technology stack'),
      _lead('You work with these because the product needs them — not as a list '
          'of topics to get through.'),
      Wrap(
        spacing: 18,
        runSpacing: 18,
        children: [
          for (final g in groups)
            SizedBox(
              width: wide ? 320 : double.infinity,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(g.$1,
                    style: GoogleFonts.poppins(
                        fontSize: 14.5, fontWeight: FontWeight.w700, color: _navy)),
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final t in g.$2)
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border:
                            Border.all(color: Colors.black.withValues(alpha: 0.09)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(t,
                          style: GoogleFonts.inter(
                              fontSize: 12, fontWeight: FontWeight.w500)),
                    ),
                ]),
              ]),
            ),
        ],
      ),
    ]);
  }

  Widget _portfolio(bool wide) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _h2('💼  Build your engineering portfolio'),
          _lead('By the end you should not have only a certificate. You should '
              'have evidence of engineering capability.'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final item in const [
              'Product overview', 'Requirements', 'System architecture',
              'Block diagram', 'Circuit', 'Firmware', 'GitHub repository', 'BOM',
              'Testing', 'Documentation', 'Product photographs', 'Demo video',
              'Technical presentation',
            ])
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                decoration: BoxDecoration(
                  color: _blue.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.check_rounded, size: 14, color: _blue),
                  const SizedBox(width: 6),
                  Text(item,
                      style: GoogleFonts.inter(
                          fontSize: 12.5, fontWeight: FontWeight.w500)),
                ]),
              ),
          ]),
        ],
      );

  Widget _career(bool wide) {
    const items = [
      ('GitHub', 'Build and present your projects professionally.'),
      ('Resume', 'Turn project work into strong technical descriptions.'),
      ('LinkedIn', 'Showcase your engineering work.'),
      ('Technical interviews',
          'Practise explaining your architecture, firmware, hardware and '
              'debugging decisions.'),
      ('Career direction',
          'Embedded systems, IoT, firmware, electronics, automation, product '
              'engineering, AIoT.'),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _h2('🎓  Career and professional development'),
      _lead('Product engineering does not end with the final demo.'),
      Wrap(spacing: 16, runSpacing: 16, children: [
        for (final i in items)
          SizedBox(
            width: wide ? 330 : double.infinity,
            child: Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(i.$1,
                    style: GoogleFonts.poppins(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(i.$2,
                    style: GoogleFonts.inter(
                        fontSize: 12.5,
                        height: 1.5,
                        color: AppColors.textSecondary)),
              ]),
            ),
          ),
      ]),
    ]);
  }

  Widget _forWhom(bool wide) {
    const groups = [
      ('Engineering students',
          'ECE, EEE, Electronics, Instrumentation, Robotics, CSE/IT and related.'),
      ('Fresh graduates',
          "Build the practical experience coursework often doesn't provide."),
      ('Working professionals',
          'Develop hands-on product engineering skills alongside your job.'),
      ('Aspiring product engineers',
          'Move beyond individual technologies and start building complete products.'),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _h2('🎯  Who is this for?'),
      const SizedBox(height: 8),
      Wrap(spacing: 16, runSpacing: 16, children: [
        for (final g in groups)
          SizedBox(
            width: wide ? 500 : double.infinity,
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.person_outline_rounded, size: 18, color: _blue),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(g.$1,
                          style: GoogleFonts.poppins(
                              fontSize: 14.5, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(g.$2,
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              height: 1.5,
                              color: AppColors.textSecondary)),
                    ]),
              ),
            ]),
          ),
      ]),
    ]);
  }

  Widget _results(bool wide) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _h2('📈  What happened to people who did this'),
          _lead('The rest of this page is a description. This part is the '
              'evidence.'),
          if (_placements.isNotEmpty) ...[
            Text('WHERE THEY ARE NOW',
                style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.7,
                    color: _blue)),
            const SizedBox(height: 10),
            SizedBox(
              height: 210,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _placements.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, i) {
                  final item = _placements[i] as Map<String, dynamic>;
                  return PlacementCard(
                    item: item,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => ShowcaseDetailScreen(item: item)),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 26),
          ],
          if (_reviews.isNotEmpty) ...[
            Text('IN THEIR OWN WORDS',
                style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.7,
                    color: _blue)),
            const SizedBox(height: 10),
            SizedBox(
              height: 210,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _reviews.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, i) {
                  final item = _reviews[i] as Map<String, dynamic>;
                  return ReviewCard(
                    item: item,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => ShowcaseDetailScreen(item: item)),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      );

  Widget _fees(bool wide) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _h2('💰  Programme fees', color: Colors.white),
          _lead('Both modes cover the same programme. The Mini Product Lab is '
              'optional and charged separately.',
              color: Colors.white.withValues(alpha: 0.85)),
          if (wide)
            Row(children: [
              Expanded(child: _feeCard(_fastTrack)),
              const SizedBox(width: 16),
              Expanded(child: _feeCard(_weekend)),
            ])
          else
            Column(children: [
              _feeCard(_fastTrack),
              const SizedBox(height: 14),
              _feeCard(_weekend),
            ]),
        ],
      );

  Widget _feeCard(_Plan p) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(p.name,
              style: GoogleFonts.poppins(
                  color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          _price(p, onDark: true),
          const SizedBox(height: 8),
          Text('${p.duration} · ${p.schedule}',
              style: GoogleFonts.inter(
                  color: Colors.white.withValues(alpha: 0.82), fontSize: 12.5)),
          const SizedBox(height: 6),
          Text('Mini Product Lab: ${_rs(_labFee)} + GST',
              style: GoogleFonts.inter(
                  color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
        ]),
      );

  Widget _groupUnlock(bool wide) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _h2('🔥  Group fee unlock'),
          _lead('The more people who join together, the lower everyone\'s fee. '
              'Bring your classmates, friends or colleagues and unlock a better '
              'cohort price.'),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black.withValues(alpha: 0.09)),
            ),
            child: Column(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                decoration: BoxDecoration(
                  color: _navy,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                ),
                child: Row(children: [
                  Expanded(
                    child: Text('Group size',
                        style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700)),
                  ),
                  Text('Fee per student',
                      style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700)),
                ]),
              ),
              for (var i = 0; i < _groupSlabs.length; i++)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: i.isEven ? Colors.white : const Color(0xFFF7F9FC),
                    borderRadius: i == _groupSlabs.length - 1
                        ? const BorderRadius.vertical(bottom: Radius.circular(11))
                        : null,
                  ),
                  child: Row(children: [
                    Expanded(
                      child: Text(_groupSlabs[i].$1,
                          style: GoogleFonts.inter(fontSize: 13.5)),
                    ),
                    Text(_rs(_groupSlabs[i].$2),
                        style: GoogleFonts.poppins(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: i == _groupSlabs.length - 1
                                ? const Color(0xFF2E7D32)
                                : _ink)),
                  ]),
                ),
            ]),
          ),
          const SizedBox(height: 14),
          // Which programme these slabs price is otherwise left to be guessed,
          // and someone reading them against the ₹28,000 mode would guess wrong.
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: _amber.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
                'These slabs apply to the Fast Track (${_rs(_fastTrack.fee)}). '
                'For a group on the Professional programme, ask us for the '
                'cohort price.',
                style: GoogleFonts.inter(fontSize: 12.5, height: 1.5)),
          ),
          const SizedBox(height: 16),
          Text('How it works',
              style: GoogleFonts.poppins(
                  fontSize: 14.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(
              'If your group reaches a higher slab, the unlocked fee applies to '
              'every eligible student in that group before the batch closes. So '
              '8 students pay ${_rs(16500)} each — and if 2 more join, all 10 pay '
              '${_rs(16000)} each. Maximum batch size is 10 students.',
              style: GoogleFonts.inter(
                  fontSize: 13.5, height: 1.65, color: AppColors.textPrimary)),
          const SizedBox(height: 10),
          Text(
              'Group Fee Unlock cannot be combined with other promotional '
              'discounts or scholarships. The Mini Product Lab fee is separate.',
              style: GoogleFonts.inter(
                  fontSize: 12, height: 1.5, color: AppColors.textSecondary)),
        ],
      );

  Widget _whyHandsOn(bool wide) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _h2('🧪  Why hands-on?'),
          _lead('Because knowing a technology is different from knowing how to '
              'engineer a product.'),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('You may know:',
                  style: GoogleFonts.inter(
                      fontSize: 12.5, color: AppColors.textSecondary)),
              const SizedBox(height: 4),
              Text('"What is MQTT?"',
                  style: GoogleFonts.poppins(
                      fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              Text('A product engineer answers:',
                  style: GoogleFonts.inter(
                      fontSize: 12.5, color: AppColors.textSecondary)),
              const SizedBox(height: 4),
              Text(
                  'Where should MQTT be used in this product? How should the '
                  'device communicate? What happens when the network fails? How '
                  'do we debug it? How do we test it? How do we document it?',
                  style: GoogleFonts.poppins(
                      fontSize: 15, fontWeight: FontWeight.w600, height: 1.55)),
              const SizedBox(height: 14),
              Text(
                  "That's the difference between learning technology and "
                  'building products.',
                  style: GoogleFonts.inter(
                      fontSize: 13.5, color: AppColors.textSecondary)),
            ]),
          ),
        ],
      );

  Widget _finalCta(bool wide) => Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: wide ? 56 : 40, horizontal: 20),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_navy, Color(0xFF16407F)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1080),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Stop collecting courses.',
                  style: GoogleFonts.poppins(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: wide ? 28 : 22,
                      fontWeight: FontWeight.w600)),
              Text('Start building products.',
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: wide ? 34 : 26,
                      fontWeight: FontWeight.w800,
                      height: 1.2)),
              const SizedBox(height: 14),
              Text('Choose your mode and start your product engineering journey.',
                  style: GoogleFonts.inter(
                      color: Colors.white.withValues(alpha: 0.85), fontSize: 14.5)),
              const SizedBox(height: 26),
              Wrap(spacing: 12, runSpacing: 12, children: [
                _cta('Join Fast Track · ${_rs(_fastTrack.fee)} + GST',
                    () => _enquire(_fastTrack.name),
                    filled: true),
                _cta('Join Weekend Program · ${_rs(_weekend.fee)} + GST',
                    () => _enquire(_weekend.name)),
                _cta('Talk to a mentor', () => _enquire('Product Engineering Program')),
              ]),
              const SizedBox(height: 18),
              InkWell(
                onTap: () => context.go('/roadmap/product-engineering'),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.route_rounded, size: 16, color: _amber),
                  const SizedBox(width: 7),
                  Text('See every stage in the full roadmap',
                      style: GoogleFonts.inter(
                          color: _amber,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                          decorationColor: _amber)),
                ]),
              ),
            ]),
          ),
        ),
      );

  Widget _footer() => Container(
        width: double.infinity,
        color: const Color(0xFFF7F9FC),
        padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1080),
            child: Text(
                'Programme duration, project scope and technology coverage may '
                'vary based on the selected batch, project requirements and '
                'learner progress. Group Fee Unlock is subject to batch capacity '
                'and availability. All fees are exclusive of GST.',
                style: GoogleFonts.inter(
                    fontSize: 11.5, height: 1.6, color: AppColors.textSecondary)),
          ),
        ),
      );
}
