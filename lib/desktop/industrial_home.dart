import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import 'industrial_flow.dart';
import 'visual_page.dart' show openExternal;

/// Industrial training, the second product on the trainer's home (29 Oct 2026, founder: technical training and industrial
/// training side by side; the industrial one is sold to plants in lakhs, so it must feel premium). A plant's workforce is
/// taught in their language by Altron, tested, certified, and the plant gets records its auditors accept.
///
/// On a team login it is live (30 Oct 2026): workers are trained here and the plant head's view is the real record. On any
/// other login it shows what a plant gets, with an example plant said to be one.
class IndustrialHome extends StatefulWidget {
  const IndustrialHome({super.key});

  static const ink = indInk;
  static const gold = indGold;

  @override
  State<IndustrialHome> createState() => _IndustrialHomeState();
}

class _IndustrialHomeState extends State<IndustrialHome> {
  static const panel = indPanel, gold = indGold, goldSoft = indGoldSoft, line = indLine, ink = indInk;

  List<Map<String, dynamic>> _plants = [];
  int? _plantId;
  bool _live = false, _loading = true;
  String _programme = 'safety_induction';
  Map<String, dynamic>? _view;
  bool _viewLoading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await ApiService.industrialGet('plants');
      _plants = [for (final p in (r['plants'] as List? ?? const [])) Map<String, dynamic>.from(p as Map)];
      _plantId ??= _plants.isEmpty ? null : _plants.first['id'] as int;
      _live = _plantId != null;
    } catch (_) {
      _live = false;           // not the team, or offline: the page shows what a plant gets
    }
    if (mounted) setState(() => _loading = false);
    if (_live) await _loadView();
  }

  Future<void> _loadView() async {
    if (_plantId == null) return;
    setState(() => _viewLoading = true);
    try {
      final v = await ApiService.industrialGet('plants/$_plantId?programme=$_programme');
      if (mounted) setState(() => _view = v);
    } catch (_) {
      // keep what is shown
    } finally {
      if (mounted) setState(() => _viewLoading = false);
    }
  }

  void _talk(String about) => openExternal('https://wa.me/917222977927?text=${Uri.encodeComponent(
      'Hello Altrobyte, I would like to know about industrial training for our plant ($about).')}');

  Future<void> _train(IndProgramme p) async {
    if (!_live || _plantId == null) {
      _talk(p.title);
      return;
    }
    final done = await runIndustrialTraining(context, _plantId!, p);
    if (done && mounted) {
      setState(() => _programme = p.key);
      await _loadView();
    }
  }

  Future<void> _report() async {
    if (_plantId == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final csv = await ApiService.industrialReport(_plantId!);
      final home = Platform.environment['USERPROFILE'] ?? Directory.systemTemp.path;
      final dir = Directory('$home\\Downloads');
      await dir.create(recursive: true);
      final name = ((_view?['plant'] as Map?)?['name'] ?? 'plant').toString().replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-');
      final now = DateTime.now();
      final f = File('${dir.path}\\$name-training-record-${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}.csv');
      await f.writeAsString(csv);
      await Process.run('cmd', ['/c', 'start', '', f.path]);
      messenger.showSnackBar(SnackBar(content: Text('Saved to Downloads: ${f.uri.pathSegments.last}')));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('The report could not be downloaded. Check the internet and try again.')));
    }
  }

  Future<void> _newPlant() async {
    final name = TextEditingController(), city = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Add a plant'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, autofocus: true, decoration: const InputDecoration(labelText: 'Plant or company name')),
          TextField(controller: city, decoration: const InputDecoration(labelText: 'City')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Add')),
        ],
      ),
    );
    if (ok != true || name.text.trim().length < 2) return;
    try {
      final p = await ApiService.industrialPost('plants', {'name': name.text.trim(), 'city': city.text.trim()});
      _plantId = p['id'] as int;
      await _load();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('The plant could not be added.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: ink, borderRadius: BorderRadius.circular(18)),
      padding: const EdgeInsets.fromLTRB(32, 30, 32, 34),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _hero(),
        const SizedBox(height: 34),
        _heading('Programmes', 'Each one taught by Altron in Hinglish, with drills, a test and a certificate for every worker.'),
        const SizedBox(height: 16),
        LayoutBuilder(builder: (_, box) {
          final cols = box.maxWidth > 1100 ? 3 : (box.maxWidth > 700 ? 2 : 1);
          final w = (box.maxWidth - 16 * (cols - 1)) / cols;
          return Wrap(spacing: 16, runSpacing: 16, children: [
            for (final p in indProgrammes) SizedBox(width: w, child: _programmeCard(p)),
            SizedBox(
                width: w,
                child: _customCard(Icons.description_rounded, 'Your Plant SOPs',
                    'Your own SOPs and work instructions, turned into spoken lessons, drills and tests. Approved by your safety head.')),
            SizedBox(
                width: w,
                child: _customCard(Icons.precision_manufacturing_rounded, 'Machine & Maintenance',
                    'PLC basics, motors and drives, pneumatics, preventive maintenance and fault finding, built around your machines.')),
          ]);
        }),
        const SizedBox(height: 36),
        _heading("What the plant head sees", 'Who is trained, who is due, who failed, by department. One click for the audit file.'),
        const SizedBox(height: 16),
        if (_loading)
          const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator(color: indGold)))
        else if (_live)
          _liveDashboard()
        else
          _sampleDashboard(),
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
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1B2D4F), indInk]),
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
            Text('Every worker taught in their own language by Altron, drilled, tested, certified, and on record. No classroom to book, '
                'no trainer to wait for, no register to fill.',
                style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.75), fontSize: 15, height: 1.5)),
            const SizedBox(height: 22),
            Wrap(spacing: 12, runSpacing: 10, children: [
              FilledButton.icon(
                onPressed: () => _live ? _train(indProgrammes.first) : _talk('plant demo'),
                style: FilledButton.styleFrom(backgroundColor: gold, foregroundColor: ink, padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16)),
                icon: Icon(_live ? Icons.play_arrow_rounded : Icons.event_available_rounded),
                label: Text(_live ? 'Train a worker now' : 'Book a plant demo', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
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
          _proof(Icons.record_voice_over_rounded, 'Hinglish-first', 'spoken lessons'),
          _proof(Icons.touch_app_rounded, 'Hands-on drills', 'not slides'),
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

  Widget _card({required IconData icon, required String title, required String about, required String size, required String tag,
      required String action, required VoidCallback onTap, bool strong = false}) {
    return Container(
      height: 226,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: panel, borderRadius: BorderRadius.circular(14), border: Border.all(color: strong ? gold.withValues(alpha: 0.45) : line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: gold, size: 28),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(color: gold.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(99)),
            child: Text(tag, style: GoogleFonts.inter(color: goldSoft, fontSize: 11, fontWeight: FontWeight.w600)),
          ),
        ]),
        const SizedBox(height: 14),
        Text(title, style: GoogleFonts.poppins(color: Colors.white, fontSize: 16.5, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Expanded(
          child: Text(about, maxLines: 3, overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.68), fontSize: 13, height: 1.45)),
        ),
        Row(children: [
          Expanded(child: Text(size, style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.5), fontSize: 12))),
          strong
              ? FilledButton(
                  onPressed: onTap,
                  style: FilledButton.styleFrom(backgroundColor: gold, foregroundColor: ink, visualDensity: VisualDensity.compact),
                  child: Text(action, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12.5)))
              : TextButton(
                  onPressed: onTap,
                  style: TextButton.styleFrom(foregroundColor: gold),
                  child: Text(action, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12.5))),
        ]),
      ]),
    );
  }

  Widget _programmeCard(IndProgramme p) => _card(
      icon: p.icon,
      title: p.title,
      about: p.line,
      size: '${p.size} · test',
      tag: 'Ready',
      action: _live ? 'Start training' : 'See it for my plant  →',
      strong: _live,
      onTap: () => _train(p));

  Widget _customCard(IconData icon, String title, String about) =>
      _card(icon: icon, title: title, about: about, size: 'Built for your plant', tag: 'Custom', action: 'Plan it with us  →', onTap: () => _talk(title));

  Widget _stat(String n, String l, Color c) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: ink, borderRadius: BorderRadius.circular(12), border: Border.all(color: line)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(n, style: GoogleFonts.poppins(color: c, fontSize: 26, fontWeight: FontWeight.w700)),
            Text(l, style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.6), fontSize: 12.5)),
          ]),
        ),
      );

  Widget _bar(String name, double value, String right) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(children: [
          SizedBox(width: 170, child: Text(name, style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.8), fontSize: 13))),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(value: value, minHeight: 8, backgroundColor: ink, color: value >= 0.75 ? gold : const Color(0xFFF2B35B)),
            ),
          ),
          SizedBox(width: 80, child: Text(right, textAlign: TextAlign.right, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13))),
        ]),
      );

  Widget _liveDashboard() {
    final v = _view;
    final t = (v?['totals'] as Map?) ?? const {};
    final depts = (v?['departments'] as List?) ?? const [];
    final workers = (v?['workers'] as List?) ?? const [];
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(14), border: Border.all(color: line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.factory_rounded, color: gold.withValues(alpha: 0.9)),
          const SizedBox(width: 10),
          DropdownButton<int>(
            value: _plantId,
            dropdownColor: panel,
            underline: const SizedBox.shrink(),
            style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
            items: [
              for (final p in _plants)
                DropdownMenuItem(value: p['id'] as int, child: Text('${p['name']}${(p['city'] ?? '').toString().isEmpty ? '' : ' · ${p['city']}'}')),
            ],
            onChanged: (id) {
              setState(() => _plantId = id);
              _loadView();
            },
          ),
          IconButton(tooltip: 'Add a plant', onPressed: _newPlant, icon: const Icon(Icons.add_business_rounded, color: Colors.white54)),
          const Spacer(),
          if (_viewLoading) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: indGold)),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            onPressed: _report,
            style: OutlinedButton.styleFrom(foregroundColor: goldSoft, side: BorderSide(color: gold.withValues(alpha: 0.5))),
            icon: const Icon(Icons.download_rounded, size: 18),
            label: const Text('Audit report (Excel)'),
          ),
        ]),
        const SizedBox(height: 12),
        Wrap(spacing: 8, children: [
          for (final p in indProgrammes)
            ChoiceChip(
              label: Text(p.title),
              selected: _programme == p.key,
              selectedColor: gold,
              backgroundColor: ink,
              labelStyle: GoogleFonts.inter(color: _programme == p.key ? ink : Colors.white70, fontWeight: FontWeight.w600, fontSize: 12.5),
              side: BorderSide(color: _programme == p.key ? gold : line),
              onSelected: (_) {
                setState(() => _programme = p.key);
                _loadView();
              },
            ),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          _stat('${t['percent'] ?? 0}%', 'trained and certified', goldSoft),
          const SizedBox(width: 12),
          _stat('${t['workers'] ?? 0}', 'workers registered', Colors.white),
          const SizedBox(width: 12),
          _stat('${t['pending'] ?? 0}', 'not trained yet', const Color(0xFFF2B35B)),
          const SizedBox(width: 12),
          _stat('${t['failed'] ?? 0}', 'failed, re-test due', indBad),
          const SizedBox(width: 12),
          _stat(t['average'] == null ? '-' : '${t['average']}%', 'average score', Colors.white),
        ]),
        const SizedBox(height: 20),
        if (workers.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(color: ink, borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              Text('No worker trained here yet.', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text('Press "Start training" on a programme: the first result appears here at once.',
                  style: GoogleFonts.inter(color: Colors.white60, fontSize: 13)),
            ]),
          )
        else ...[
          for (final d in depts)
            _bar('${d['department']}', (d['workers'] as num) == 0 ? 0 : (d['certified'] as num) / (d['workers'] as num),
                '${d['certified']} / ${d['workers']}'),
          const SizedBox(height: 10),
          _workerTable(workers),
        ],
      ]),
    );
  }

  Widget _workerTable(List workers) {
    Widget cell(String s, {double w = 0, Color c = Colors.white, FontWeight f = FontWeight.w400}) {
      final t = Text(s, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(color: c, fontSize: 13, fontWeight: f));
      return w == 0 ? Expanded(child: t) : SizedBox(width: w, child: t);
    }

    return Container(
      decoration: BoxDecoration(color: ink, borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(children: [
            cell('Employee', c: Colors.white54, f: FontWeight.w600),
            cell('ID', w: 110, c: Colors.white54, f: FontWeight.w600),
            cell('Department', w: 170, c: Colors.white54, f: FontWeight.w600),
            cell('Score', w: 70, c: Colors.white54, f: FontWeight.w600),
            cell('Status', w: 150, c: Colors.white54, f: FontWeight.w600),
            const SizedBox(width: 120),
          ]),
        ),
        for (final w in workers.take(12)) ...[
          const Divider(height: 1, color: indLine),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(children: [
              cell('${w['name']}', f: FontWeight.w600),
              cell('${w['emp_id']}', w: 110, c: Colors.white70),
              cell('${w['department']}', w: 170, c: Colors.white70),
              cell(w['score'] == null ? '-' : '${w['score']}/${w['total']}', w: 70),
              SizedBox(width: 150, child: _status('${w['status']}')),
              SizedBox(
                width: 120,
                child: w['cert_no'] != null
                    ? TextButton(
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => IndustrialCertificateScreen(result: {
                                  ...Map<String, dynamic>.from(w as Map),
                                  'plant': (_view?['plant'] as Map?)?['name'],
                                  'city': (_view?['plant'] as Map?)?['city'],
                                  'programme': _view?['programme'],
                                }))),
                        style: TextButton.styleFrom(foregroundColor: gold),
                        child: const Text('Certificate'))
                    : const SizedBox.shrink(),
              ),
            ]),
          ),
        ],
        if (workers.length > 12)
          Padding(
            padding: const EdgeInsets.all(10),
            child: Text('and ${workers.length - 12} more in the audit report', style: GoogleFonts.inter(color: Colors.white54, fontSize: 12.5)),
          ),
      ]),
    );
  }

  Widget _status(String s) {
    final (label, color) = switch (s) {
      'certified' => ('Certified', indGood),
      'failed' => ('Re-test due', indBad),
      _ => ('Not trained yet', const Color(0xFFF2B35B)),
    };
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(99)),
        child: Text(label, style: GoogleFonts.inter(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
      ),
    );
  }

  /// What a plant head gets, for a login that is not the team's: an example plant, said to be one.
  Widget _sampleDashboard() {
    const depts = [('Production', 0.92), ('Maintenance', 0.78), ('Stores & logistics', 0.64), ('Contract workforce', 0.51)];
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
          _stat('76%', 'trained and certified', goldSoft),
          const SizedBox(width: 12),
          _stat('312', 'workers on the programme', Colors.white),
          const SizedBox(width: 12),
          _stat('41', 'due this week', const Color(0xFFF2B35B)),
          const SizedBox(width: 12),
          _stat('9', 'failed, re-test booked', indBad),
        ]),
        const SizedBox(height: 20),
        for (final d in depts) _bar(d.$1, d.$2, '${(d.$2 * 100).round()}%'),
      ]),
    );
  }

  Widget _steps() {
    const steps = [
      (Icons.upload_file_rounded, 'Your SOPs in', 'We take your SOPs, safety rules and machine manuals.'),
      (Icons.auto_awesome_rounded, 'Lessons made', 'Altron turns them into spoken lessons, drills and tests; your safety head approves.'),
      (Icons.badge_rounded, 'Workers learn', 'On a training-room screen or a phone, in their language, with hands-on drills.'),
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
