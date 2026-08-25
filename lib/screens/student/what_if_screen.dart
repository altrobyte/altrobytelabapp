import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/api_service.dart';
import '../../widgets/pathway_graph.dart';

/// WHAT IF? — the page where a recommendation stops being a claim.
///
/// A student is handed a roadmap and has no way to argue with it. This is the
/// argument: pick another direction and watch the path rearrange, with the
/// steps that still count staying exactly where they were.
///
/// The graph is the product. Everything written underneath it is a caption —
/// which is why the answer arrives as structure rather than an essay, and why
/// there is no chat box on this screen.
class WhatIfScreen extends StatefulWidget {
  const WhatIfScreen({super.key});

  @override
  State<WhatIfScreen> createState() => _WhatIfScreenState();
}

class _WhatIfScreenState extends State<WhatIfScreen> {
  Map<String, dynamic>? _options;
  Map<String, dynamic>? _result;
  Map<String, dynamic>? _signal;
  bool _loading = true;
  bool _thinking = false;
  bool _choosing = false;
  bool _savingProfile = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final o = await ApiService.whatIfOptions();
      if (!mounted) return;
      setState(() {
        _options = o;
        _loading = false;
      });
      if (o['signed_in'] == true) {
        try {
          final s = await ApiService.whatIfSignal();
          if (mounted && s['signal'] == true) setState(() => _signal = s);
        } catch (_) {}
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

  Future<void> _explore(String kind, String choice) async {
    setState(() {
      _thinking = true;
      _choosing = false;
      _error = '';
    });
    try {
      final r = await ApiService.whatIfExplore(kind: kind, choice: choice);
      if (mounted) setState(() { _result = r; _thinking = false; });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e is ApiException ? e.message : '$e';
          _thinking = false;
        });
      }
    }
  }

  // ── The graph, before and after ──────────────────────────────────────────

  /// Which nodes to draw and what each one means now.
  ///
  /// Before an alternative there is one path and no story. After one, the
  /// shared steps keep their place — that is the whole point, so they are
  /// found by label rather than reordered.
  List<PathNode> get _nodes {
    final current = ((_result ?? _options)?['current_path'] as List?) ??
        _defaultPath;
    if (_result == null) {
      return [
        for (final n in current)
          PathNode(id: '${(n as Map)['id']}', label: '${n['label']}'),
      ];
    }

    final shared = ((_result!['shared'] as List?) ?? [])
        .map((e) => '$e'.toLowerCase())
        .toSet();
    final alt = (_result!['alternative_path'] as List?) ?? [];

    bool isShared(String label) =>
        shared.any((s) => s.contains(label.toLowerCase()) ||
            label.toLowerCase().contains(s));

    // Three groups, in the order a student reads them: what they already did
    // that still counts, then what is new, then what this choice sets aside.
    final out = <PathNode>[];
    final altLabels = alt
        .map((n) => '${(n as Map)['label']}'.toLowerCase())
        .toSet();

    // The model names the overlap but usually starts its path after it. Left
    // out, the shared steps would simply vanish — the opposite of the point.
    for (final n in current) {
      final label = '${(n as Map)['label']}';
      if (isShared(label) && !altLabels.contains(label.toLowerCase())) {
        out.add(PathNode(
            id: '${n['id']}', label: label, state: NodeState.shared));
      }
    }
    for (final n in alt) {
      final label = '${(n as Map)['label']}';
      out.add(PathNode(
        id: '${n['id']}',
        label: label,
        state: isShared(label) ? NodeState.shared : NodeState.grown,
      ));
    }
    // Steps from the old path that the new one leaves behind, kept visible
    // and dimmed: gone would say you lost them.
    for (final n in current) {
      final label = '${(n as Map)['label']}';
      final already =
          out.any((e) => e.label.toLowerCase() == label.toLowerCase());
      if (!already) {
        out.add(PathNode(
            id: '${n['id']}', label: label, state: NodeState.fading));
      }
    }
    return out;
  }

  static const _defaultPath = [
    {"id": "c", "label": "Embedded C"},
    {"id": "mcu", "label": "Microcontrollers"},
    {"id": "firmware", "label": "Firmware & RTOS"},
    {"id": "pcb", "label": "PCB Design"},
    {"id": "cloud", "label": "IoT & Cloud"},
    {"id": "edge_ai", "label": "Edge AI"},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0B2450),
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        title: Text('What if?',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700, fontSize: 17)),
        actions: [
          if (_result != null)
            TextButton(
              onPressed: () => setState(() => _result = null),
              child: Text('Reset',
                  style: GoogleFonts.inter(fontSize: 12.5)),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              children: [
                if (_result == null) _intro(),
                if (_signal != null && _result == null) _signalCard(),
                const SizedBox(height: 4),
                _graphCard(),
                if (_error.isNotEmpty) _errorCard(),
                if (_result != null) ..._answer(),
                if (_result != null) _needsCard(),
                const SizedBox(height: 18),
                if (!_thinking) _cta(),
              ],
            ),
    );
  }

  Widget _intro() => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Don\'t just follow a roadmap.',
              style: GoogleFonts.poppins(
                  fontSize: 21,
                  height: 1.3,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0B2450))),
          const SizedBox(height: 4),
          Text('Explore where each choice can take you.',
              style: GoogleFonts.inter(
                  fontSize: 14, height: 1.5, color: const Color(0xFF5A6B82))),
        ]),
      );

  Widget _signalCard() => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: const Color(0xFFE65100).withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.auto_graph_rounded, size: 17, color: Color(0xFFE65100)),
          const SizedBox(width: 9),
          Expanded(
            child: Text('${_signal!['message']}',
                style: GoogleFonts.inter(
                    fontSize: 12.5,
                    height: 1.5,
                    color: const Color(0xFF0B2450))),
          ),
        ]),
      );

  Widget _graphCard() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE6EBF3)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_result == null ? 'YOUR PATH RIGHT NOW' : 'IF YOU CHOOSE THAT',
              style: GoogleFonts.inter(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.9,
                  color: const Color(0xFF9AA5B5))),
          const SizedBox(height: 12),
          if (_thinking)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            PathwayGraph(nodes: _nodes, onTap: _skipSheet),
        ]),
      );

  /// Tapping a step asks the other half of the question.
  ///
  /// "What if I choose something else" is about direction; this is about the
  /// step in front of them, which is the one they are actually tempted to
  /// skip. Same endpoint, same structure back — no second kind of answer.
  void _skipSheet(PathNode node) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: const Color(0xFFE1E7F0),
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text(node.label,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0B2450))),
          const SizedBox(height: 6),
          Text('Every step on a path should be able to justify itself.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 12.5, height: 1.5, color: const Color(0xFF5A6B82))),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                Navigator.of(sheetContext).pop();
                _explore('skip', node.label);
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF12326B),
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('What if I skip this?',
                  style: GoogleFonts.poppins(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.white)),
            ),
          ),
        ]),
      ),
    );
  }


  Widget _errorCard() => Container(
        margin: const EdgeInsets.only(top: 14),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: const Color(0xFFC62828).withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Text(_error,
            style: GoogleFonts.inter(
                fontSize: 12.5, height: 1.5, color: const Color(0xFFC62828))),
      );

  // ── What the model said, as sections rather than an essay ────────────────

  List<Widget> _answer() {
    final r = _result!;
    final effort = (r['effort'] as Map?) ?? {};
    return [
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0B2450), Color(0xFF16407F)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text('${r['headline'] ?? ''}',
            style: GoogleFonts.poppins(
                fontSize: 16.5,
                height: 1.45,
                fontWeight: FontWeight.w600,
                color: Colors.white)),
      ),
      _list('YOU GAIN', r['gain'], const Color(0xFF2E7D32)),
      _list('YOU GIVE UP', r['give_up'], const Color(0xFFE65100)),
      _list('STAYS OPEN', r['stays_open'], const Color(0xFF12326B)),
      _list('GETS HARDER', r['harder'], const Color(0xFFE65100)),
      _list('GETS EASIER', r['easier'], const Color(0xFF2E7D32)),
      _list('YOU WOULD NEED TO LEARN', r['new_to_learn'],
          const Color(0xFF12326B)),
      if (effort.isNotEmpty) ...[
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE6EBF3)),
          ),
          child: Column(children: [
            for (final e in effort.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(children: [
                  Expanded(
                    child: Text(
                        '${e.key}'.replaceAll('_', ' '),
                        style: GoogleFonts.inter(
                            fontSize: 12, color: const Color(0xFF5A6B82))),
                  ),
                  Text('${e.value}',
                      style: GoogleFonts.poppins(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF0B2450))),
                ]),
              ),
          ]),
        ),
      ],
      // The reason for the original, after the alternative rather than
      // before it: it only lands once somebody has seen what they would be
      // trading.
      _list('WHY WE SUGGESTED YOUR CURRENT PATH', r['why_original'],
          const Color(0xFF12326B), numbered: true),
      if ('${r['next_action'] ?? ''}'.isNotEmpty) ...[
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF2E7D32).withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.play_circle_outline_rounded,
                size: 18, color: Color(0xFF2E7D32)),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('DO THIS WEEK',
                        style: GoogleFonts.inter(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.9,
                            color: const Color(0xFF2E7D32))),
                    const SizedBox(height: 4),
                    Text('${r['next_action']}',
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            height: 1.5,
                            color: const Color(0xFF0B2450))),
                  ]),
            ),
          ]),
        ),
      ],
      if ('${r['uncertainty'] ?? ''}'.isNotEmpty) ...[
        const SizedBox(height: 12),
        // Said out loud rather than smoothed over. A guess dressed as a fact
        // is the thing that would make all of this untrustworthy.
        Text('What we could not judge: ${r['uncertainty']}',
            style: GoogleFonts.inter(
                fontSize: 11.5,
                height: 1.5,
                fontStyle: FontStyle.italic,
                color: const Color(0xFF9AA5B5))),
      ],
    ];
  }

  Widget _list(String title, dynamic items, Color colour,
      {bool numbered = false}) {
    final list = (items as List?) ?? [];
    if (list.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: GoogleFonts.inter(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.9,
                color: colour)),
        const SizedBox(height: 8),
        for (var i = 0; i < list.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (numbered)
                Text('${i + 1}. ',
                    style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: colour))
              else
                Padding(
                  padding: const EdgeInsets.only(top: 6, right: 8),
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration:
                        BoxDecoration(color: colour, shape: BoxShape.circle),
                  ),
                ),
              Expanded(
                child: Text('${list[i]}',
                    style: GoogleFonts.inter(
                        fontSize: 12.5,
                        height: 1.55,
                        color: const Color(0xFF0B2450))),
              ),
            ]),
          ),
      ]),
    );
  }

  // ── Choosing ─────────────────────────────────────────────────────────────

  /// The one thing we ask for, and only once we have earned it.
  ///
  /// Asked up front this would be a form standing between a student and the
  /// idea. Asked here it answers a question they have just watched us fail to
  /// answer — the `uncertainty` line above says what we could not judge.
  Widget _needsCard() {
    final needs = ((_options?['needs'] as List?) ?? []).map((e) => '$e').toList();
    if (needs.isEmpty || _options?['signed_in'] != true) {
      return const SizedBox.shrink();
    }

    // One question at a time, in the order that makes the next answer better:
    // branch decides what they can reach, year decides how soon, goal decides
    // what "better" even means.
    final ask = needs.contains('branch')
        ? 'branch'
        : needs.contains('study_year')
            ? 'years'
            : 'goals';
    final copy = {
      'branch': (
        'Make this about you',
        'Tell us your branch and the next answer is written for you, not for a generic student.',
      ),
      'years': ('Which year are you in?', 'How soon this has to pay off changes the order.'),
      'goals': ('What are you actually aiming at?', 'The trade-offs read differently depending on it.'),
    }[ask]!;
    final items = (_options?[ask == 'branch' ? 'branches' : ask] as List?) ?? const [];

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6EBF3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(copy.$1,
            style: GoogleFonts.poppins(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF0B2450))),
        const SizedBox(height: 3),
        Text(copy.$2,
            style: GoogleFonts.inter(
                fontSize: 12.5, height: 1.5, color: const Color(0xFF5A6B82))),
        const SizedBox(height: 12),
        if (_savingProfile)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in items)
                _pill('${(item as Map)['label']}', () {
                  final id = '${item['id']}';
                  _saveProfile(
                    branch: ask == 'branch' ? id : '',
                    studyYear: ask == 'years' ? id : '',
                    goal: ask == 'goals' ? id : '',
                  );
                }),
            ],
          ),
      ]),
    );
  }

  Widget _pill(String label, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF4F7FB),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE1E7F0)),
          ),
          child: Text(label,
              style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF12326B))),
        ),
      );

  Future<void> _saveProfile(
      {String branch = '', String studyYear = '', String goal = ''}) async {
    setState(() => _savingProfile = true);
    try {
      await ApiService.whatIfSaveProfile(
          branch: branch, studyYear: studyYear, goal: goal);
      final o = await ApiService.whatIfOptions();
      if (mounted) setState(() { _options = o; _savingProfile = false; });
    } catch (e) {
      if (mounted) {
        setState(() {
          _savingProfile = false;
          _error = e is ApiException ? e.message : '$e';
        });
      }
    }
  }

  Widget _cta() {
    if (_choosing) return _chooser();
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: () => setState(() => _choosing = true),
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF12326B),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        icon: const Icon(Icons.alt_route_rounded, size: 19, color: Colors.white),
        label: Text(
            _result == null
                ? 'What if I choose something else?'
                : 'Explore another future',
            style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.white)),
      ),
    );
  }

  Widget _chooser() {
    final directions = (_options?['directions'] as List?) ?? [];
    final goals = (_options?['goals'] as List?) ?? [];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6EBF3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Okay. Let\'s explore another future.',
            style: GoogleFonts.poppins(
                fontSize: 15.5,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF0B2450))),
        const SizedBox(height: 14),
        Text('AIM SOMEWHERE ELSE',
            style: GoogleFonts.inter(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.9,
                color: const Color(0xFF9AA5B5))),
        const SizedBox(height: 8),
        for (final d in directions)
          _choice('${(d as Map)['label']}', '${d['blurb']}',
              () => _explore('direction', '${d['id']}')),
        const SizedBox(height: 14),
        Text('OR SOMETHING CHANGED',
            style: GoogleFonts.inter(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.9,
                color: const Color(0xFF9AA5B5))),
        const SizedBox(height: 8),
        Wrap(spacing: 7, runSpacing: 7, children: [
          for (final g in goals)
            GestureDetector(
              onTap: () => _explore('goal', '${(g as Map)['id']}'),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F4F9),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: const Color(0xFFE1E7F0)),
                ),
                child: Text('${g['label']}',
                    style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF5A6B82))),
              ),
            ),
        ]),
        const SizedBox(height: 10),
        Center(
          child: TextButton(
            onPressed: () => setState(() => _choosing = false),
            child: Text('Not now',
                style: GoogleFonts.inter(
                    fontSize: 12.5, color: const Color(0xFF5A6B82))),
          ),
        ),
      ]),
    );
  }

  Widget _choice(String label, String blurb, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: GoogleFonts.poppins(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF0B2450))),
                    const SizedBox(height: 1),
                    Text(blurb,
                        style: GoogleFonts.inter(
                            fontSize: 11.5,
                            height: 1.4,
                            color: const Color(0xFF9AA5B5))),
                  ]),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 20, color: Color(0xFF9AA5B5)),
          ]),
        ),
      );
}
