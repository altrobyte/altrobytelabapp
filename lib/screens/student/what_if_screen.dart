import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/api_service.dart';
import '../../widgets/mind_map.dart';

/// WHAT IF? — the map of a student's possible engineering futures.
///
/// A roadmap handed over is a claim, and a list of careers underneath it is a
/// catalogue. Neither lets a student ask the only question they actually have:
/// what happens to me if I choose differently.
///
/// So the futures are drawn around them instead. Distance from the centre is
/// how well something currently fits, weight is how much evidence we hold,
/// and asking a "what if" rearranges the map in front of them — the steps that
/// still count staying exactly where they were. That last part is the product:
/// nothing written down convinces somebody their existing work survives a
/// change of direction, but watching it stay put does.
///
/// Two rules the whole screen is built around. The map is drawn from data we
/// already have, before any model is asked, because something that takes six
/// seconds to appear reads as a form rather than a mind. And a signal is only
/// ever shown where one can honestly be counted — everywhere else the map says
/// it does not know yet, which is the sentence that makes the rest credible.
class WhatIfScreen extends StatefulWidget {
  const WhatIfScreen({super.key});

  @override
  State<WhatIfScreen> createState() => _WhatIfScreenState();
}

class _WhatIfScreenState extends State<WhatIfScreen> {
  Map<String, dynamic>? _universe;
  Map<String, dynamic>? _result;
  Map<String, dynamic>? _signal;

  bool _loading = true;
  bool _thinking = false;
  bool _savingProfile = false;
  String _error = '';
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final u = await ApiService.whatIfUniverse();
      if (!mounted) return;
      setState(() {
        _universe = u;
        _loading = false;
      });
      if (u['you']?['signed_in'] == true) {
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
      _error = '';
      _selectedId = null;
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

  // ── The map ───────────────────────────────────────────────────────────────

  List get _directions => (_universe?['directions'] as List?) ?? const [];

  /// What to draw right now.
  ///
  /// Before any question: the student at the centre and their possible
  /// directions around them, ordered by evidence. After one: the capabilities
  /// that future is made of, with the shared ones marked — the same centre,
  /// so it reads as the same map rearranged rather than a different page.
  (List<MindNode>, List<MindEdge>) get _graph {
    final you = Map<String, dynamic>.from(_universe?['you'] ?? const {});
    final name = '${you['name'] ?? ''}'.trim();
    final centre = MindNode(
      id: 'you',
      label: name.isEmpty ? 'YOU' : name.split(' ').first.toUpperCase(),
      state: MindState.you,
      note: '${you['subtitle'] ?? ''}',
    );

    if (_result == null) {
      final nodes = <MindNode>[centre];
      final edges = <MindEdge>[];
      for (var i = 0; i < _directions.length; i++) {
        final d = Map<String, dynamic>.from(_directions[i]);
        final sig = Map<String, dynamic>.from(d['signal'] ?? const {});
        final value = (sig['value'] as num?)?.toInt();
        nodes.add(MindNode(
          id: '${d['id']}',
          label: '${d['label']}',
          state: value == null ? MindState.faint : MindState.current,
          signal: value,
          // The strongest few sit on the inner ring. Everything else stays on
          // the map, just further out — hiding a direction would quietly
          // narrow the student's world without telling them.
          ring: i < 4 ? 1 : 2,
        ));
        edges.add(MindEdge('you', '${d['id']}'));
      }
      return (nodes, edges);
    }

    final raw = (_result!['nodes'] as List?) ?? const [];
    final nodes = <MindNode>[centre];
    final edges = <MindEdge>[];
    var previous = 'you';
    for (var i = 0; i < raw.length; i++) {
      final n = Map<String, dynamic>.from(raw[i] as Map);
      final state = switch ('${n['state']}') {
        'shared' => MindState.shared,
        'grown' => MindState.grown,
        'fading' => MindState.fading,
        _ => MindState.current,
      };
      final id = '${n['id']}';
      nodes.add(MindNode(
        id: id,
        label: '${n['label']}',
        state: state,
        note: '${n['note'] ?? ''}',
        // Fading steps drift outward. They are still reachable, just no
        // longer on the direct route, and the map should say that without a
        // caption.
        ring: state == MindState.fading ? 2 : (i < 4 ? 1 : 2),
      ));
      edges.add(MindEdge(state == MindState.fading ? 'you' : previous, id));
      if (state != MindState.fading) previous = id;
    }
    return (nodes, edges);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 900;
    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A1628),
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        title: Text('What if?',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700, fontSize: 17, color: Colors.white)),
        actions: [
          if (_result != null)
            TextButton(
              onPressed: () => setState(() {
                _result = null;
                _selectedId = null;
              }),
              child: Text('Reset',
                  style: GoogleFonts.inter(
                      fontSize: 12.5, color: Colors.white70)),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty && _universe == null
              ? _errorState()
              : wide
                  ? Row(children: [
                      Expanded(flex: 5, child: _mapPane()),
                      SizedBox(
                        width: 400,
                        child: Container(
                          color: const Color(0xFF0D1D34),
                          child: _sidePanel(),
                        ),
                      ),
                    ])
                  : Column(children: [
                      Expanded(child: _mapPane()),
                      _bottomPane(),
                    ]),
    );
  }

  Widget _errorState() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(_error,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 13.5, height: 1.5, color: Colors.white70)),
        ),
      );

  /// The map itself, on the dark field it needs to glow against.
  Widget _mapPane() {
    final (nodes, edges) = _graph;
    return Stack(children: [
      const Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 0.95,
              colors: [Color(0xFF12294A), Color(0xFF0A1628)],
            ),
          ),
        ),
      ),
      Positioned.fill(
        child: MindMap(
          nodes: nodes,
          edges: edges,
          selectedId: _selectedId,
          onTap: _onNodeTap,
        ),
      ),
      if (_result == null)
        Positioned(
          left: 20,
          right: 20,
          bottom: 14,
          child: IgnorePointer(
            child: Text('Your engineering future is not one fixed path.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    fontSize: 12,
                    height: 1.5,
                    color: Colors.white.withValues(alpha: 0.42))),
          ),
        ),
      if (_thinking) _thinkingOverlay(),
    ]);
  }

  /// Not "Loading…". The wait is part of the idea, so it should say what is
  /// being done rather than that something is happening.
  Widget _thinkingOverlay() => Positioned.fill(
        child: Container(
          color: const Color(0xFF0A1628).withValues(alpha: 0.72),
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(strokeWidth: 2.2)),
                const SizedBox(height: 16),
                Text('Exploring possible futures…',
                    style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white)),
              ]),
        ),
      );

  void _onNodeTap(MindNode node) {
    if (node.id == 'you') return;
    setState(() => _selectedId = node.id);

    // Before a question, tapping a direction is the question. After one, the
    // map is capabilities rather than futures, so a tap asks the other half:
    // what happens if this step is skipped.
    if (_result == null) {
      final d = _directions.cast<Map?>().firstWhere(
          (e) => '${e?['id']}' == node.id,
          orElse: () => null);
      if (d != null) _showDirectionSheet(Map<String, dynamic>.from(d));
    } else {
      _showSkipSheet(node);
    }
  }

  // ── Panels ────────────────────────────────────────────────────────────────

  Widget _sidePanel() => ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        children: _panelChildren(),
      );

  Widget _bottomPane() => Container(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.42),
        decoration: const BoxDecoration(
          color: Color(0xFF0D1D34),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 26),
          shrinkWrap: true,
          children: _panelChildren(),
        ),
      );

  List<Widget> _panelChildren() => [
        if (_signal != null && _result == null) _signalCard(),
        if (_error.isNotEmpty) _errorCard(),
        if (_result == null) ..._prompts() else ..._answer(),
        if (_result == null) _needsCard(),
      ];

  List<Widget> _prompts() {
    final prompts = (_universe?['prompts'] as List?) ?? const [];
    final ev = Map<String, dynamic>.from(_universe?['evidence'] ?? const {});
    final thin = (ev['completed_steps'] ?? 0) == 0 && ev['has_branch'] != true;
    return [
      Text('WHAT IF…',
          style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              color: Colors.white.withValues(alpha: 0.45))),
      const SizedBox(height: 4),
      Text(
          thin
              ? 'Ask one, and the map redraws. It gets sharper once we know your branch.'
              : 'Ask one, and the map redraws around the answer.',
          style: GoogleFonts.inter(
              fontSize: 12.5, height: 1.5, color: Colors.white60)),
      const SizedBox(height: 14),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final raw in prompts)
            _chip(Map<String, dynamic>.from(raw as Map)),
        ],
      ),
      const SizedBox(height: 18),
    ];
  }

  Widget _chip(Map<String, dynamic> p) => InkWell(
        onTap: () => _explore('${p['kind']}', '${p['id']}'),
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: Text('${p['label']}',
              style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.92))),
        ),
      );

  List<Widget> _answer() {
    final r = _result!;
    final sig = Map<String, dynamic>.from(r['signal'] ?? const {});
    final exp = Map<String, dynamic>.from(r['next_experiment'] ?? const {});
    final sim = (r['simulation'] as List?) ?? const [];
    final futures = (r['next_futures'] as List?) ?? const [];
    final uncertainty = '${r['uncertainty'] ?? ''}'.trim();

    return [
      Text('${r['headline'] ?? ''}',
          style: GoogleFonts.poppins(
              fontSize: 16,
              height: 1.35,
              fontWeight: FontWeight.w700,
              color: Colors.white)),
      if (sig.isNotEmpty) ...[
        const SizedBox(height: 10),
        _signalRow(sig),
      ],
      const SizedBox(height: 16),
      if ('${r['why_emerging'] ?? ''}'.trim().isNotEmpty)
        _block('WHY IS THIS EMERGING?', '${r['why_emerging']}'),
      _list('YOU GAIN', r['gain'], const Color(0xFF4CAF50)),
      _list('YOU GIVE UP OR DELAY', r['give_up'], const Color(0xFFE07A1F)),
      _list('STAYS OPEN EITHER WAY', r['stays_open'], const Color(0xFF3E7BD6)),
      _list('LIKELY HARDER', r['harder'], const Color(0xFFE07A1F)),
      _list('LIKELY EASIER', r['easier'], const Color(0xFF4CAF50)),
      if (r['why_original'] != null)
        _list('WHY WE RECOMMENDED THE OTHER ONE', r['why_original'],
            Colors.white70),
      if (sim.isNotEmpty) _simulation(sim),
      if (futures.isNotEmpty)
        _list('OPENS ONTO', futures, const Color(0xFF3E7BD6)),
      // Said before the next action, not after: an admission that arrives
      // after the instruction reads as a disclaimer.
      if (uncertainty.isNotEmpty) _block('WHAT WE STILL DO NOT KNOW', uncertainty),
      if (exp.isNotEmpty) _experiment(exp),
      const SizedBox(height: 18),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => setState(() { _result = null; _selectedId = null; }),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
            padding: const EdgeInsets.symmetric(vertical: 13),
          ),
          icon: const Icon(Icons.alt_route_rounded, size: 17),
          label: Text('Ask another what if',
              style: GoogleFonts.poppins(
                  fontSize: 13.5, fontWeight: FontWeight.w600)),
        ),
      ),
    ];
  }

  /// The number, and immediately what it is made of.
  ///
  /// A bare percentage on a career page is the thing students have learned to
  /// distrust, and rightly. Showing the evidence next to it is the only reason
  /// it deserves to be there at all.
  Widget _signalRow(Map<String, dynamic> sig) {
    final value = (sig['value'] as num?)?.toInt();
    final because = (sig['because'] as List?) ?? const [];
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          if (value != null)
            Text('$value%',
                style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF6FA8F5))),
          if (value != null) const SizedBox(width: 9),
          Expanded(
            child: Text('${sig['label'] ?? ''}',
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70)),
          ),
        ]),
        if (because.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text('Based on ${because.join(', ')}.',
              style: GoogleFonts.inter(
                  fontSize: 11.5, height: 1.45, color: Colors.white54)),
        ],
      ]),
    );
  }

  Widget _block(String title, String body) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: GoogleFonts.inter(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.9,
                  color: Colors.white.withValues(alpha: 0.4))),
          const SizedBox(height: 6),
          Text(body,
              style: GoogleFonts.inter(
                  fontSize: 12.5, height: 1.6, color: Colors.white70)),
        ]),
      );

  Widget _list(String title, dynamic items, Color colour) {
    final list = (items as List?) ?? const [];
    if (list.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: GoogleFonts.inter(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.9,
                color: colour.withValues(alpha: 0.75))),
        const SizedBox(height: 7),
        for (final item in list)
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                margin: const EdgeInsets.only(top: 6, right: 8),
                width: 4,
                height: 4,
                decoration:
                    BoxDecoration(color: colour, shape: BoxShape.circle),
              ),
              Expanded(
                child: Text('$item',
                    style: GoogleFonts.inter(
                        fontSize: 12.5, height: 1.55, color: Colors.white70)),
              ),
            ]),
          ),
      ]),
    );
  }

  Widget _simulation(List months) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('NEXT 6 MONTHS',
              style: GoogleFonts.inter(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.9,
                  color: Colors.white.withValues(alpha: 0.4))),
          const SizedBox(height: 9),
          for (final raw in months)
            Builder(builder: (_) {
              final m = Map<String, dynamic>.from(raw as Map);
              return Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(children: [
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.07),
                      shape: BoxShape.circle,
                    ),
                    child: Text('${m['month']}',
                        style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white70)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('${m['focus']}',
                        style: GoogleFonts.inter(
                            fontSize: 12.5, color: Colors.white70)),
                  ),
                ]),
              );
            }),
        ]),
      );

  /// The one thing to actually do, and why that one.
  ///
  /// Every exploration has to end here. A student who leaves with five
  /// interesting futures and nothing to do on Monday has been entertained,
  /// not helped — and the point of a small experiment is that it settles a
  /// question about them that no amount of reading can.
  Widget _experiment(Map<String, dynamic> exp) => Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF3E7BD6).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(13),
          border:
              Border.all(color: const Color(0xFF3E7BD6).withValues(alpha: 0.3)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('TRY THIS NEXT',
              style: GoogleFonts.inter(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.9,
                  color: const Color(0xFF6FA8F5))),
          const SizedBox(height: 6),
          Text('${exp['what'] ?? ''}',
              style: GoogleFonts.poppins(
                  fontSize: 13.5,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                  color: Colors.white)),
          if ('${exp['why'] ?? ''}'.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('${exp['why']}',
                style: GoogleFonts.inter(
                    fontSize: 12, height: 1.5, color: Colors.white60)),
          ],
        ]),
      );

  Widget _signalCard() => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: const Color(0xFFE07A1F).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.auto_graph_rounded,
              size: 17, color: Color(0xFFE9A25E)),
          const SizedBox(width: 9),
          Expanded(
            child: Text('${_signal!['message']}',
                style: GoogleFonts.inter(
                    fontSize: 12.5, height: 1.5, color: Colors.white70)),
          ),
        ]),
      );

  Widget _errorCard() => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Text(_error,
            style: GoogleFonts.inter(
                fontSize: 12, height: 1.5, color: Colors.white70)),
      );

  // ── The one-time ask ──────────────────────────────────────────────────────

  /// Asked here rather than at the door.
  ///
  /// A form standing between a student and the idea is a form they close. Once
  /// the map is on screen and visibly generic, the same question reads as an
  /// offer to make it theirs.
  Widget _needsCard() {
    final needs = ((_universe?['needs'] as List?) ?? const [])
        .map((e) => '$e')
        .toList();
    if (needs.isEmpty || _universe?['you']?['signed_in'] != true) {
      return const SizedBox.shrink();
    }
    final ask = needs.contains('branch')
        ? 'branches'
        : needs.contains('study_year')
            ? 'years'
            : 'goals';
    final copy = {
      'branches': (
        'Make this map yours',
        'Your branch decides which of these are actually close to you.'
      ),
      'years': (
        'Which year are you in?',
        'How soon this has to pay off changes the order.'
      ),
      'goals': (
        'What are you aiming at?',
        'The trade-offs read differently depending on it.'
      ),
    }[ask]!;
    final items = (_universe?[ask] as List?) ?? const [];

    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(copy.$1,
            style: GoogleFonts.poppins(
                fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
        const SizedBox(height: 3),
        Text(copy.$2,
            style: GoogleFonts.inter(
                fontSize: 12, height: 1.5, color: Colors.white60)),
        const SizedBox(height: 11),
        if (_savingProfile)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else
          Wrap(spacing: 7, runSpacing: 7, children: [
            for (final item in items)
              _pill('${(item as Map)['label']}', () {
                final id = '${item['id']}';
                _saveProfile(
                  branch: ask == 'branches' ? id : '',
                  studyYear: ask == 'years' ? id : '',
                  goal: ask == 'goals' ? id : '',
                );
              }),
          ]),
      ]),
    );
  }

  Widget _pill(String label, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
          ),
          child: Text(label,
              style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white)),
        ),
      );

  Future<void> _saveProfile(
      {String branch = '', String studyYear = '', String goal = ''}) async {
    setState(() => _savingProfile = true);
    try {
      await ApiService.whatIfSaveProfile(
          branch: branch, studyYear: studyYear, goal: goal);
      // Reload rather than patch: the signals are recomputed server-side, and
      // the whole point is watching the map tighten around the new fact.
      final u = await ApiService.whatIfUniverse();
      if (mounted) setState(() { _universe = u; _savingProfile = false; });
    } catch (e) {
      if (mounted) {
        setState(() {
          _savingProfile = false;
          _error = e is ApiException ? e.message : '$e';
        });
      }
    }
  }

  // ── Sheets ────────────────────────────────────────────────────────────────

  void _showDirectionSheet(Map<String, dynamic> d) {
    final sig = Map<String, dynamic>.from(d['signal'] ?? const {});
    final built = (d['built_from'] as List?) ?? const [];
    _sheet(children: [
      Text('${d['label']}',
          style: GoogleFonts.poppins(
              fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
      const SizedBox(height: 5),
      Text('${d['blurb'] ?? ''}',
          style: GoogleFonts.inter(
              fontSize: 12.5, height: 1.5, color: Colors.white60)),
      const SizedBox(height: 14),
      _signalRow(sig),
      if (built.isNotEmpty) ...[
        const SizedBox(height: 14),
        _list('BUILT OUT OF', built, const Color(0xFF3E7BD6)),
      ],
      const SizedBox(height: 6),
      SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: () {
            Navigator.of(context).pop();
            _explore('direction', '${d['id']}');
          },
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF3E7BD6),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text('What if I choose this?',
              style: GoogleFonts.poppins(
                  fontSize: 14, fontWeight: FontWeight.w600)),
        ),
      ),
    ]);
  }

  void _showSkipSheet(MindNode node) {
    _sheet(children: [
      Text(node.label,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
              fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
      const SizedBox(height: 5),
      Text('Every step on a path should be able to justify itself.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
              fontSize: 12.5, height: 1.5, color: Colors.white60)),
      const SizedBox(height: 16),
      SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: () {
            Navigator.of(context).pop();
            _explore('skip', node.label);
          },
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF3E7BD6),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text('What if I skip this?',
              style: GoogleFonts.poppins(
                  fontSize: 14, fontWeight: FontWeight.w600)),
        ),
      ),
    ]);
  }

  void _sheet({required List<Widget> children}) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0D1D34),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.75),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 26),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(2))),
                  ),
                  ...children,
                ]),
          ),
        ),
      ),
    ).whenComplete(() {
      if (mounted) setState(() => _selectedId = null);
    });
  }
}
