import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:shared_preferences/shared_preferences.dart';

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
  String _error = '';
  String? _selectedId;

  /// The node the map is arranged around. Tapping a direction focuses it
  /// rather than opening a card over it — the map is the thing being
  /// explored, so it should be what responds.
  String? _focusId;

  /// The AI's answer for whichever node is focused, and the children it grew
  /// out of that node. Kept per node id so tapping back and forth does not
  /// re-ask a question we have already paid for.
  Map<String, dynamic>? _node;
  final Map<String, List<dynamic>> _grown = {};
  final Map<String, Map<String, dynamic>> _answers = {};
  bool _asking = false;

  /// Branch and year, remembered locally. A visitor who has not signed in can
  /// still say which branch they are in, and without it every direction on
  /// the map reads "not enough evidence yet" — which is true, and useless.
  String _branch = '';
  String _year = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _branch = prefs.getString('what_if_branch') ?? '';
      _year = prefs.getString('what_if_year') ?? '';
      final u = await ApiService.whatIfUniverse(branch: _branch, year: _year);
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
      _focusId = null;
      _node = null;
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

      // Whatever the model grew out of a node, at whatever depth. This used
      // to be written out twice by hand, which meant it only ever reached
      // two levels — tapping anything the model had itself produced asked
      // the question, got an answer, and drew nothing.
      void expand(String parentId, String parentLabel) {
        for (final g in _grown[parentId] ?? const []) {
          final gm = Map<String, dynamic>.from(g as Map);
          final id = '$parentId/${gm['label']}';
          nodes.add(MindNode(
            id: id,
            label: '${gm['label']}',
            note: '${gm['note'] ?? ''}',
            state: MindState.grown,
          ));
          edges.add(MindEdge(parentId, id, relation: 'Grew from $parentLabel'));
          expand(id, '${gm['label']}');
        }
      }

      for (var i = 0; i < _directions.length; i++) {
        final d = Map<String, dynamic>.from(_directions[i]);
        final sig = Map<String, dynamic>.from(d['signal'] ?? const {});
        final value = (sig['value'] as num?)?.toInt();
        final dirId = '${d['id']}';
        nodes.add(MindNode(
          id: dirId,
          label: '${d['label']}',
          state: value == null ? MindState.faint : MindState.current,
          signal: value,
          tier: '${sig['tier'] ?? ''}',
        ));
        edges.add(MindEdge('you', dirId, relation: '${d['relation'] ?? ''}'));

        // What the direction is built out of, hanging off it. Without this
        // the map is seven labels in a fan, which is a menu; with it the
        // shape says these are one body of work that forks.
        for (final c in (d['built_from'] as List?) ?? const []) {
          final childId = '$dirId/$c';
          nodes.add(MindNode(
            id: childId,
            label: '$c',
            state: value == null ? MindState.faint : MindState.current,
          ));
          edges.add(MindEdge(dirId, childId, relation: 'Part of ${d['label']}'));
          expand(childId, '$c');
        }
        expand(dirId, '${d['label']}');
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
      ));
      edges.add(MindEdge(state == MindState.fading ? 'you' : previous, id,
          relation: switch (state) {
            MindState.shared => 'You already have this — it still counts',
            MindState.grown => 'New on this route',
            MindState.fading => 'Still reachable, no longer on the direct path',
            _ => '',
          }));
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
                _focusId = null;
                _node = null;
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
          focusId: _focusId,
          onTap: _onNodeTap,
          onEdgeTap: _onEdgeTap,
        ),
      ),
      Positioned(
        left: 20,
        right: 20,
        bottom: 12,
        child: IgnorePointer(child: _status()),
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
    if (node.id == 'you') {
      setState(() { _focusId = null; _selectedId = null; });
      return;
    }
    // First tap rearranges the map around it; the detail follows. Opening a
    // card straight over the graph would make the graph a picture of the
    // answer rather than the answer.
    setState(() {
      _selectedId = node.id;
      _focusId = node.id;
    });

    _askNode(node);
  }

  /// A tap is a question, and the answer arrives on the map.
  ///
  /// This used to open a sheet of text we had written in advance, which is
  /// why the page could be looked at and no AI found in it. Now the node is
  /// put to the model with whatever we honestly know about the student, and
  /// what comes back grows out of the node itself.
  Future<void> _askNode(MindNode node) async {
    // Answered before: show it again rather than paying for the same
    // question twice, and never leave the panel blank on a second tap.
    final cached = _answers[node.id];
    setState(() {
      _asking = cached == null;
      _node = cached;
      _error = '';
    });
    if (cached != null) return;

    // Which direction this node hangs off, so the answer knows whether it is
    // looking at a whole direction or one step inside one.
    final parentId = _parentOf(node.id);
    final parent = _directions.cast<Map?>().firstWhere(
        (e) => '${e?['id']}' == parentId,
        orElse: () => null);

    try {
      final r = await ApiService.whatIfNode(
        node: node.label,
        kind: parent == null ? 'direction' : 'capability',
        parent: parent == null ? '' : '${parent['label']}',
        branch: _branch,
        year: _year,
      );
      if (!mounted) return;
      setState(() {
        _node = r;
        _asking = false;
        _answers[node.id] = r;
        _grown[node.id] = (r['children'] as List?) ?? const [];
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _asking = false;
          _error = e is ApiException ? e.message : '$e';
        });
      }
    }
  }

  /// The direction a node belongs to, however deep it sits. Ids are built by
  /// appending, so the first segment is always the direction.
  String? _parentOf(String id) {
    final cut = id.indexOf('/');
    return cut <= 0 ? null : id.substring(0, cut);
  }

  /// A tap on a connection answers what the line means.
  void _onEdgeTap(MindEdge edge) {
    if (edge.relation.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: const Color(0xFF12326B),
      duration: const Duration(seconds: 4),
      content: Text(edge.relation,
          style: GoogleFonts.inter(fontSize: 12.5, color: Colors.white)),
    ));
  }

  /// What the map is currently weighing, said plainly.
  ///
  /// Not a fake activity indicator: the sentence names real counted things,
  /// so a student who reads it twice gets a consistent answer.
  Widget _status() {
    final text = _result != null
        ? 'Here is what changes if you take that route.'
        : '${_universe?['status'] ?? 'Your engineering future is not one fixed path.'}';
    final emerging = _universe?['emerging'] as Map?;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      if (_result == null && emerging != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
              'Emerging: ${emerging['name']} — ${emerging['why']}',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 11.5,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF6FA8F5))),
        ),
      Text(text,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
              fontSize: 11.5,
              height: 1.5,
              color: Colors.white.withValues(alpha: 0.42))),
    ]);
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
        if (_error.isNotEmpty) _errorCard(),
        // The branch question first, always, until it is answered. Every
        // direction on the map reads "not enough evidence yet" without it.
        _branchCard(),
        if (_signal != null && _result == null && _node == null) _signalCard(),
        if (_asking)
          ..._askingState()
        else if (_node != null)
          ..._nodeAnswer()
        else if (_result != null)
          ..._answer()
        else
          ..._prompts(),
      ];

  List<Widget> _askingState() => [
        Row(children: [
          const SizedBox(
              width: 15,
              height: 15,
              child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 10),
          Text('Working out what this means for you…',
              style: GoogleFonts.inter(fontSize: 12.5, color: Colors.white70)),
        ]),
      ];

  /// The model's answer for one node, and the map has already grown to match.
  List<Widget> _nodeAnswer() {
    final n = _node!;
    final sig = Map<String, dynamic>.from(n['signal'] ?? const {});
    final exp = Map<String, dynamic>.from(n['experiment'] ?? const {});
    final uncertainty = '${n['uncertainty'] ?? ''}'.trim();
    return [
      Text('${n['node']}',
          style: GoogleFonts.poppins(
              fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
      const SizedBox(height: 5),
      Text('${n['headline'] ?? ''}',
          style: GoogleFonts.inter(
              fontSize: 12.5, height: 1.55, color: Colors.white70)),
      if (sig.isNotEmpty) ...[
        const SizedBox(height: 12),
        _signalRow(sig),
      ],
      const SizedBox(height: 16),
      if ('${n['why'] ?? ''}'.trim().isNotEmpty)
        _block('WHY THIS MATTERS FOR YOU', '${n['why']}'),
      _list('LEADS ON TO', n['leads_to'], const Color(0xFF5B9BEA)),
      if (uncertainty.isNotEmpty)
        _block('WHAT WE STILL CANNOT TELL', uncertainty),
      if (exp.isNotEmpty) _experiment(exp),
      const SizedBox(height: 16),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: () => setState(() {
            _node = null;
            _focusId = null;
            _selectedId = null;
          }),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          child: Text('Back to the whole map',
              style: GoogleFonts.poppins(
                  fontSize: 13, fontWeight: FontWeight.w600)),
        ),
      ),
    ];
  }

  /// Asked without a login, because the alternative was telling a visitor the
  /// map sharpens once we know their branch and giving them no way to say it.
  Widget _branchCard() {
    if (_branch.isNotEmpty) return const SizedBox.shrink();
    final branches = (_universe?['branches'] as List?) ?? const [];
    if (branches.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF5B9BEA).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFF5B9BEA).withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Which branch are you in?',
            style: GoogleFonts.poppins(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: Colors.white)),
        const SizedBox(height: 3),
        Text('One tap. The whole map is generic until it knows.',
            style: GoogleFonts.inter(
                fontSize: 12, height: 1.5, color: Colors.white60)),
        const SizedBox(height: 11),
        Wrap(spacing: 7, runSpacing: 7, children: [
          for (final b in branches)
            _pill('${(b as Map)['label']}', () => _setBranch('${b['id']}')),
        ]),
      ]),
    );
  }

  Future<void> _setBranch(String id) async {
    setState(() {
      _branch = id;
      _loading = true;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('what_if_branch', id);
    // Signed-in students get it saved on the account too, so the next feature
    // that needs a branch does not have to ask again.
    try {
      if (_universe?['you']?['signed_in'] == true) {
        await ApiService.whatIfSaveProfile(branch: id);
      }
    } catch (_) {}
    try {
      final u = await ApiService.whatIfUniverse(branch: id, year: _year);
      if (mounted) setState(() { _universe = u; _loading = false; });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e is ApiException ? e.message : '$e';
        });
      }
    }
  }

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
      if (r['changed'] != null)
        _changed(Map<String, dynamic>.from(r['changed'] as Map)),
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
          onPressed: () => setState(() { _result = null; _selectedId = null; _focusId = null; _node = null; }),
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

  /// What actually moved, in three lines a student can check against the map.
  ///
  /// The middle group is the one that matters. A student changing direction
  /// assumes the work behind them is wasted, and no amount of encouragement
  /// fixes that — a list of what still counts, next to a graph where those
  /// same nodes stayed put, does.
  Widget _changed(Map<String, dynamic> c) {
    Widget group(String mark, String title, dynamic items, Color colour) {
      final list = (items as List?) ?? const [];
      if (list.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: GoogleFonts.inter(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: colour)),
          const SizedBox(height: 4),
          for (final item in list)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text('$mark  $item',
                  style: GoogleFonts.inter(
                      fontSize: 12.5, height: 1.5, color: Colors.white70)),
            ),
        ]),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('WHAT CHANGED',
            style: GoogleFonts.inter(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.9,
                color: Colors.white.withValues(alpha: 0.45))),
        const SizedBox(height: 9),
        group('+', 'NEW', c['added'], const Color(0xFF6FA8F5)),
        group('✓', 'STILL COUNTS', c['still_useful'], const Color(0xFF4CAF50)),
        group('↓', 'LESS DIRECT', c['less_direct'], const Color(0xFFE07A1F)),
      ]),
    );
  }

  /// The number, and immediately what it is made of.
  ///
  /// A bare percentage on a career page is the thing students have learned to
  /// distrust, and rightly. Showing the evidence next to it is the only reason
  /// it deserves to be there at all.
  Widget _signalRow(Map<String, dynamic> sig) {
    final value = (sig['value'] as num?)?.toInt();
    final tier = '${sig['tier'] ?? ''}';
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
            child: Text(
                tier.isEmpty ? '${sig['label'] ?? ''}'
                             : '$tier · ${sig['label'] ?? ''}',
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

}
