import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'visual_page.dart' show openExternal;

/// Industrial training, the second product on the trainer's home (29 Oct 2026, founder: technical training and industrial
/// training side by side; the industrial one is sold to plants in lakhs, so it must feel premium). A plant's workforce is
/// taught in their language by Altron, tested, certified, and the plant gets records its auditors accept.
class IndustrialHome extends StatelessWidget {
  const IndustrialHome({super.key});

  static const ink = Color(0xFF0B1424);
  static const panel = Color(0xFF13203A);
  static const gold = Color(0xFFD9A441);
  static const goldSoft = Color(0xFFF3D99B);
  static const line = Color(0xFF243656);

  static const _programmes = [
    _Programme(Icons.health_and_safety_rounded, 'Safety Induction',
        'PPE, lockout-tagout, fire, work at height, first aid. For every new joiner and contract worker.', '6 lessons · 90 min', 'Statutory'),
    _Programme(Icons.description_rounded, 'Plant SOP Training',
        'Your own SOPs and work instructions, turned into spoken lessons and checks. Approved by your safety head.', 'Built from your SOPs', 'Custom'),
    _Programme(Icons.precision_manufacturing_rounded, 'Machine & Maintenance',
        'PLC basics, motors and drives, pneumatics, preventive maintenance, fault finding on the shop floor.', '12 lessons · hands-on', 'Skill'),
    _Programme(Icons.verified_rounded, 'Quality, 5S & Kaizen',
        'Defects and their causes, 5S audits, kaizen thinking. What a line leader needs every day.', '8 lessons', 'Skill'),
    _Programme(Icons.sensors_rounded, 'Industry 4.0 for Supervisors',
        'Sensors, machine data, dashboards and predictive maintenance, explained for the people who run the line.', '10 lessons', 'Upskill'),
  ];

  void _talk(String about) => openExternal('https://wa.me/917222977927?text=${Uri.encodeComponent(
      'Hello Altrobyte, I would like to know about industrial training for our plant ($about).')}');

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: ink, borderRadius: BorderRadius.circular(18)),
      padding: const EdgeInsets.fromLTRB(32, 30, 32, 34),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _hero(),
        const SizedBox(height: 34),
        _heading('Programmes', 'Each one taught by Altron in Hindi or English, with a test and a certificate for every worker.'),
        const SizedBox(height: 16),
        LayoutBuilder(builder: (_, box) {
          final cols = box.maxWidth > 1100 ? 3 : (box.maxWidth > 700 ? 2 : 1);
          final w = (box.maxWidth - 16 * (cols - 1)) / cols;
          return Wrap(spacing: 16, runSpacing: 16, children: [for (final p in _programmes) SizedBox(width: w, child: _programmeCard(p))]);
        }),
        const SizedBox(height: 36),
        _heading('What the plant head sees', 'Who is trained, who is due, who failed, by department. One click for the audit file.'),
        const SizedBox(height: 16),
        _dashboard(),
        const SizedBox(height: 36),
        _heading('How it runs in your plant', ''),
        const SizedBox(height: 16),
        _steps(),
        const SizedBox(height: 34),
        _closing(),
      ]),
    );
  }

  Widget _hero() {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1B2D4F), ink]),
        border: Border.all(color: gold.withValues(alpha: 0.35)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(border: Border.all(color: gold), borderRadius: BorderRadius.circular(99)),
              child: Text('ALTROBYTE INDUSTRIAL', style: GoogleFonts.inter(color: gold, fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 16),
            Text('Workforce training\nyour auditors trust.',
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 34, height: 1.15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Text('Every worker taught in their own language by Altron, tested, certified, and on record. No classroom to book, '
                'no trainer to wait for, no register to fill.',
                style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.75), fontSize: 15, height: 1.5)),
            const SizedBox(height: 22),
            Wrap(spacing: 12, runSpacing: 10, children: [
              FilledButton.icon(
                onPressed: () => _talk('plant demo'),
                style: FilledButton.styleFrom(backgroundColor: gold, foregroundColor: ink,
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16)),
                icon: const Icon(Icons.event_available_rounded),
                label: Text('Book a plant demo', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
              ),
              OutlinedButton(
                onPressed: () => _talk('pricing'),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: BorderSide(color: Colors.white.withValues(alpha: 0.4)),
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16)),
                child: Text('Talk to our team', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              ),
            ]),
          ]),
        ),
        const SizedBox(width: 24),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _proof(Icons.record_voice_over_rounded, 'Hindi-first', 'spoken lessons'),
          _proof(Icons.fact_check_rounded, 'Test + certificate', 'for every worker'),
          _proof(Icons.folder_shared_rounded, 'Audit-ready', 'records, any day'),
        ]),
      ]),
    );
  }

  Widget _proof(IconData icon, String a, String b) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: gold.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: gold, size: 22),
          ),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(a, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
            Text(b, style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.6), fontSize: 12)),
          ]),
        ]),
      );

  Widget _heading(String title, String sub) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: GoogleFonts.poppins(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
        if (sub.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(sub, style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.6), fontSize: 13.5)),
        ],
      ]);

  Widget _programmeCard(_Programme p) {
    return Container(
      height: 214,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(14), border: Border.all(color: line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(p.icon, color: gold, size: 28),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(color: gold.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(99)),
            child: Text(p.tag, style: GoogleFonts.inter(color: goldSoft, fontSize: 11, fontWeight: FontWeight.w600)),
          ),
        ]),
        const SizedBox(height: 14),
        Text(p.title, style: GoogleFonts.poppins(color: Colors.white, fontSize: 16.5, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Expanded(
          child: Text(p.about, maxLines: 3, overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.68), fontSize: 13, height: 1.45)),
        ),
        Row(children: [
          Text(p.size, style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
          const Spacer(),
          TextButton(
            onPressed: () => _talk(p.title),
            style: TextButton.styleFrom(foregroundColor: gold),
            child: Text('See it for my plant  →', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12.5)),
          ),
        ]),
      ]),
    );
  }

  /// A sample plant, said to be one: the shape of the report a plant head gets.
  Widget _dashboard() {
    const depts = [('Production', 0.92), ('Maintenance', 0.78), ('Stores & logistics', 0.64), ('Contract workforce', 0.51)];
    Widget stat(String n, String l, Color c) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: ink, borderRadius: BorderRadius.circular(12), border: Border.all(color: line)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(n, style: GoogleFonts.poppins(color: c, fontSize: 26, fontWeight: FontWeight.w700)),
              Text(l, style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.6), fontSize: 12.5)),
            ]),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(14), border: Border.all(color: line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Sample plant · Safety Induction', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700)),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(border: Border.all(color: Colors.white24), borderRadius: BorderRadius.circular(99)),
            child: Text('example', style: GoogleFonts.inter(color: Colors.white54, fontSize: 11)),
          ),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: () => _talk('audit report sample'),
            style: OutlinedButton.styleFrom(foregroundColor: goldSoft, side: BorderSide(color: gold.withValues(alpha: 0.5))),
            icon: const Icon(Icons.download_rounded, size: 18),
            label: const Text('Audit report'),
          ),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          stat('76%', 'trained and certified', goldSoft),
          const SizedBox(width: 12),
          stat('312', 'workers on the programme', Colors.white),
          const SizedBox(width: 12),
          stat('41', 'due this week', const Color(0xFFF2B35B)),
          const SizedBox(width: 12),
          stat('9', 'failed, re-test booked', const Color(0xFFEF7D6D)),
        ]),
        const SizedBox(height: 20),
        for (final d in depts)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(children: [
              SizedBox(width: 170, child: Text(d.$1, style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.8), fontSize: 13))),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(value: d.$2, minHeight: 8, backgroundColor: ink,
                      color: d.$2 >= 0.75 ? gold : const Color(0xFFF2B35B)),
                ),
              ),
              SizedBox(
                width: 54,
                child: Text('${(d.$2 * 100).round()}%', textAlign: TextAlign.right,
                    style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
              ),
            ]),
          ),
      ]),
    );
  }

  Widget _steps() {
    const steps = [
      (Icons.upload_file_rounded, 'Your SOPs in', 'We take your SOPs, safety rules and machine manuals.'),
      (Icons.auto_awesome_rounded, 'Lessons made', 'Altron turns them into spoken lessons and checks; your safety head approves.'),
      (Icons.badge_rounded, 'Workers learn', 'On a training-room screen with an ID card, or on their phone, in their language.'),
      (Icons.insights_rounded, 'You see it all', 'Completion, scores and certificates by department, and the audit file.'),
    ];
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (var i = 0; i < steps.length; i++) ...[
        if (i > 0) const SizedBox(width: 14),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(14), border: Border.all(color: line)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text('0${i + 1}', style: GoogleFonts.poppins(color: gold, fontSize: 20, fontWeight: FontWeight.w700)),
                const Spacer(),
                Icon(steps[i].$1, color: Colors.white54, size: 22),
              ]),
              const SizedBox(height: 10),
              Text(steps[i].$2, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14.5)),
              const SizedBox(height: 4),
              Text(steps[i].$3, style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.62), fontSize: 12.5, height: 1.45)),
            ]),
          ),
        ),
      ],
    ]);
  }

  Widget _closing() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(colors: [gold.withValues(alpha: 0.18), gold.withValues(alpha: 0.05)]),
        border: Border.all(color: gold.withValues(alpha: 0.4)),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Start with a 30-day pilot on one line', style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Your SOPs, your workers, your report at the end of the month. Then the whole plant.',
                style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.7), fontSize: 13.5)),
          ]),
        ),
        const SizedBox(width: 16),
        FilledButton(
          onPressed: () => _talk('30-day pilot'),
          style: FilledButton.styleFrom(backgroundColor: gold, foregroundColor: ink, padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16)),
          child: Text('Plan a pilot', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }
}

class _Programme {
  final IconData icon;
  final String title, about, size, tag;
  const _Programme(this.icon, this.title, this.about, this.size, this.tag);
}
