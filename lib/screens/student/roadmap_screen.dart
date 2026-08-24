// The Product Engineering Program roadmap.
//
// Students say the hard part is not finding material — it is not knowing what
// to learn, in what order, or whether they are on track. So this screen answers
// three questions and nothing else:
//
//   what is the path         → months, phases, groups, every line item
//   where am I               → one "YOU ARE HERE", and progress that rolls up
//   what do I get at the end → each month's outcomes, and the programme's
//
// It is public on purpose: the path IS the pitch, and hiding it behind a login
// wastes the thing that makes someone want an account. Ticking items needs one.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import '../../constants/app_colors.dart';
import '../../services/api_service.dart';
import '../../widgets/callback_sheet.dart';

class RoadmapScreen extends StatefulWidget {
  final String slug;
  const RoadmapScreen({super.key, required this.slug});

  @override
  State<RoadmapScreen> createState() => _RoadmapScreenState();
}

class _RoadmapScreenState extends State<RoadmapScreen> {
  Map<String, dynamic>? _roadmap;
  bool _loading = true;
  String _error = '';

  /// Expanded node ids. The month containing "you are here" opens on load, so
  /// the screen arrives already answering "what do I do next".
  final Set<int> _open = {};

  /// Ids mid-request, so a tapped row can show it is saving without blocking
  /// the rest of the list.
  final Set<int> _busy = {};

  /// Which delivery plan is being viewed. The syllabus is identical across
  /// plans - only the pace changes - so this switches the header, never the
  /// steps.
  int _plan = 0;

  /// Whether the plan currently selected reaches stage [index].
  ///
  /// A plan with no limit covers the whole roadmap, which is also the right
  /// answer when a roadmap has no plans at all.
  bool _stageIncluded(Map<String, dynamic> r, int index) {
    final plans = (r['plans'] as List?) ?? [];
    if (plans.isEmpty) return true;
    final plan = plans[_plan.clamp(0, plans.length - 1)] as Map;
    final limit = plan['stage_limit'] as int?;
    return limit == null || index < limit;
  }

  /// The first plan that does reach stage [index], so the badge can name it
  /// rather than just refusing.
  String _planCovering(Map<String, dynamic> r, int index) {
    for (final p in (r['plans'] as List?) ?? []) {
      final limit = (p as Map)['stage_limit'] as int?;
      if (limit == null || index < limit) {
        final name = p['name'] as String? ?? '';
        final duration = p['duration_label'] as String? ?? '';
        if (name.isEmpty) return '';
        return duration.isEmpty ? name : '$duration $name';
      }
    }
    return '';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await ApiService.getRoadmap(widget.slug);
      _roadmap = r;
      if (_open.isEmpty) _openAll((r['steps'] as List?) ?? []);
    } catch (e) {
      // The generic line told a student nothing and told us nothing either.
      // ApiException already distinguishes "no internet" from "slow network"
      // from a real server error; passing it through is the difference
      // between a retry that helps and one that repeats.
      _error = e is ApiException
          ? e.message
          : 'Could not load the roadmap. $e';
    }
    if (mounted) setState(() => _loading = false);
  }

  /// Open every section on arrival.
  ///
  /// This page is the pitch, and a collapsed pitch asks the reader to work
  /// for it. Someone weighing the programme should see the whole syllabus by
  /// scrolling — not discover it a tap at a time, deciding at each closed
  /// heading whether it is worth opening. Sections still collapse; the
  /// default is just the other way round now.
  void _openAll(List nodes) {
    for (final n in nodes) {
      final node = n as Map<String, dynamic>;
      final children = (node['children'] as List?) ?? [];
      if (children.isEmpty) continue;
      _open.add(node['id'] as int);
      _openAll(children);
    }
  }

  Future<void> _toggle(Map<String, dynamic> step) async {
    final id = step['id'] as int;
    if (_busy.contains(id)) return;
    setState(() => _busy.add(id));
    try {
      final res = await ApiService.toggleRoadmapStep(id);
      // Reload rather than patching locally: completion rolls up through
      // groups, phases and months, and recomputing that here would be a second
      // implementation of the server's rule, free to drift from it.
      step['complete'] = res['complete'] == true;
      await _load();
    } catch (e) {
      if (!mounted) return;
      final msg = e is ApiException ? e.message : 'Could not save that';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.error,
        action: msg.toLowerCase().contains('sign in')
            ? SnackBarAction(
                label: 'Sign in',
                textColor: Colors.white,
                onPressed: () => Navigator.pushNamed(context, '/join'))
            : null,
      ));
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  /// The page is the pitch, so sharing it has to be one tap. The link is
  /// public and carries an OG card, so what lands in a WhatsApp thread is the
  /// programme poster rather than a bare URL.
  Future<void> _share() async {
    final r = _roadmap;
    if (r == null) return;
    // A direct link to this page, not the homepage. Firebase rewrites every
    // path to index.html and the app reads the path, so this opens straight on
    // the roadmap even for someone who has never been here before.
    final url = 'https://altrobytelab.com/roadmap/${widget.slug}';
    final total = '${r['step_count'] ?? ''}';
    final plans = (r['plans'] as List?) ?? [];
    final duration = plans.isEmpty
        ? (r['duration_label'] as String? ?? '')
        : plans.map((p) => (p as Map)['duration_label']).join(' or ');
    final facts = [
      if (duration.isNotEmpty) duration,
      if (total.isNotEmpty) '$total milestones',
    ].join(' · ');
    // What lands in a WhatsApp thread should say what it is without the link
    // having to be opened first.
    final text = [
      r['title'] ?? 'Roadmap',
      if (facts.isNotEmpty) facts,
      if ((r['outcome'] as String? ?? '').isNotEmpty) '\n${r['outcome']}',
      '\n$url',
    ].join('\n');
    // Copy first, always. Most desktop browsers have no Web Share API, and a
    // share sheet that silently does nothing is worse than a link on the
    // clipboard — this way the link is in hand either way.
    await Clipboard.setData(ClipboardData(text: url));
    var shared = false;
    try {
      await Share.share(text, subject: r['title'] as String?);
      shared = true;
    } catch (_) {}
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(shared ? 'Link copied' : 'Link copied to clipboard'),
        action: SnackBarAction(
          label: 'Show',
          onPressed: () => showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Roadmap link'),
              content: SelectableText(url),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Close')),
              ],
            ),
          ),
        ),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _roadmap;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(r?['title'] as String? ?? 'Roadmap',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 17)),
        backgroundColor: Colors.white,
        // The theme paints AppBar foreground white for the dark bars used
        // elsewhere; on a white bar that hides the title and every action.
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          if (r != null) ...[
            IconButton(
              tooltip: 'Share',
              icon: const Icon(Icons.share_rounded, size: 21),
              onPressed: _share,
            ),
          ],
        ],
      ),
      // The persuading happens while someone is still reading, and this page
      // is 165 milestones long: a call to action that lives only at the end is
      // one that almost nobody reaches. This bar rides along with them.
      bottomNavigationBar: (_loading || r == null)
          ? null
          : _StickyCta(roadmap: r, planIndex: _plan),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? _ErrorState(
                  message: _error,
                  onRetry: () {
                    setState(() {
                      _loading = true;
                      _error = '';
                    });
                    _load();
                  })
              : r == null
                  ? const SizedBox.shrink()
                  : RefreshIndicator(
                      onRefresh: _load,
                      // Every section is open now, which is ~210 widgets for
                      // this roadmap. Built eagerly that is a visible hitch on
                      // a cheap phone, so the list builds a stage at a time
                      // and only near the viewport — expanded stays cheap.
                      child: Builder(builder: (context) {
                        final stages = (r['steps'] as List?) ?? [];
                        return ListView.builder(
                          padding: const EdgeInsets.fromLTRB(14, 14, 14, 48),
                          // header + stages + closing CTA
                          itemCount: stages.length + 2,
                          itemBuilder: (context, index) {
                            if (index == 0) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 18),
                                child: _Header(
                                  roadmap: r,
                                  planIndex: _plan,
                                  onPlanChanged: (i) =>
                                      setState(() => _plan = i),
                                ),
                              );
                            }
                            if (index == stages.length + 1) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: _EnrollCta(roadmap: r, planIndex: _plan),
                              );
                            }
                            final i = index - 1;
                            final m = stages[i] as Map<String, dynamic>;
                            return _Node(
                              step: m,
                              depth: 0,
                              // Stage 4 is real and worth seeing whichever
                              // track you are weighing — it is the argument
                              // for the longer one. Naming the track that
                              // includes it is the whole point of showing it.
                              includedInPlan: _stageIncluded(r, i),
                              otherPlanName: _planCovering(r, i),
                              signedIn: r['signed_in'] == true,
                              isOpen: _open.contains(m['id']),
                              openIds: _open,
                              busyIds: _busy,
                              onToggleOpen: (id) => setState(() =>
                                  _open.contains(id)
                                      ? _open.remove(id)
                                      : _open.add(id)),
                              onTick: _toggle,
                            );
                          },
                        );
                      }                      ),
                    ),
    );
  }
}

class _Header extends StatelessWidget {
  final Map<String, dynamic> roadmap;
  final int planIndex;
  final ValueChanged<int> onPlanChanged;
  const _Header({
    required this.roadmap,
    required this.planIndex,
    required this.onPlanChanged,
  });

  @override
  Widget build(BuildContext context) {
    final done = (roadmap['steps_done'] as int?) ?? 0;
    final total = (roadmap['step_count'] as int?) ?? 0;
    final plans = (roadmap['plans'] as List?) ?? [];
    final plan = plans.isEmpty
        ? null
        : plans[planIndex.clamp(0, plans.length - 1)] as Map<String, dynamic>;
    // Duration comes from the plan when there is one; the roadmap's own label
    // is the fallback for a programme with a single fixed length.
    final duration = plan?['duration_label'] as String? ??
        roadmap['duration_label'] as String? ??
        '';
    final outcome = roadmap['outcome'] as String? ?? '';
    final signedIn = roadmap['signed_in'] == true;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0B2450), Color(0xFF1565C0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if ((roadmap['subtitle'] as String? ?? '').isNotEmpty)
          Text(roadmap['subtitle'] as String,
              style: GoogleFonts.inter(
                  color: Colors.white.withValues(alpha: 0.9), fontSize: 13.5, height: 1.4)),
        if (plans.length > 1) ...[
          const SizedBox(height: 16),
          _PlanBuilder(
            plans: plans,
            planIndex: planIndex,
            onPlanChanged: onPlanChanged,
          ),
        ],
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (duration.isNotEmpty) _Chip(icon: Icons.schedule_rounded, label: duration),
          if ((plan?['schedule_label'] as String? ?? '').isNotEmpty)
            _Chip(icon: Icons.calendar_month_rounded, label: plan!['schedule_label'] as String),
          if ((plan?['hours_label'] as String? ?? '').isNotEmpty)
            _Chip(icon: Icons.timer_outlined, label: plan!['hours_label'] as String),
          if ((plan?['mode_label'] as String? ?? '').isNotEmpty)
            _Chip(icon: Icons.location_on_outlined, label: plan!['mode_label'] as String),
          // Scope, stated rather than left to be inferred from which stages
          // carry a badge further down the page.
          if (plan?['stage_limit'] is int)
            _Chip(
                icon: Icons.layers_outlined,
                label: 'Stages 1-${plan!['stage_limit']}'),
          _Chip(icon: Icons.checklist_rounded, label: '$total milestones'),
        ]),
        if ((plan?['note'] as String? ?? '').isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(plan!['note'] as String,
              style: GoogleFonts.inter(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 12,
                  height: 1.45)),
        ],
        if (outcome.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.flag_rounded, color: Colors.white, size: 17),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('WHAT YOU FINISH WITH',
                      style: GoogleFonts.inter(
                          color: Colors.white.withValues(alpha: 0.72),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6)),
                  const SizedBox(height: 4),
                  Text(outcome,
                      style: GoogleFonts.inter(
                          color: Colors.white, fontSize: 12.8, height: 1.45)),
                ]),
              ),
            ]),
          ),
        ],
        if (signedIn && total > 0) ...[
          const SizedBox(height: 18),
          Row(children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: done / total,
                  minHeight: 8,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  valueColor: const AlwaysStoppedAnimation(Color(0xFF4CAF50)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text('$done / $total',
                style: GoogleFonts.poppins(
                    color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
          ]),
        ],
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;

  /// These sit on the navy header by default. The plan card underneath is
  /// white, where white-on-white would be no chip at all.
  final bool dark;
  const _Chip({required this.icon, required this.label, this.dark = false});

  @override
  Widget build(BuildContext context) {
    final fg = dark ? const Color(0xFF12326B) : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: dark
            ? const Color(0xFF12326B).withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: fg),
        const SizedBox(width: 5),
        Text(label,
            style: GoogleFonts.inter(
                color: fg, fontSize: 11.5, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

/// One node at any depth. Months and phases are collapsible headers; topics and
/// deliverables are the rows a student actually ticks.
class _Node extends StatelessWidget {
  final Map<String, dynamic> step;
  final int depth;
  final bool signedIn;
  final bool isOpen;
  final Set<int> openIds;
  final Set<int> busyIds;
  final void Function(int id) onToggleOpen;
  final Future<void> Function(Map<String, dynamic> step) onTick;

  /// False only for a top-level stage the selected plan stops short of.
  final bool includedInPlan;

  /// The plan that does include it, named on the badge.
  final String otherPlanName;

  const _Node({
    required this.step,
    required this.depth,
    this.includedInPlan = true,
    this.otherPlanName = '',
    required this.signedIn,
    required this.isOpen,
    required this.openIds,
    required this.busyIds,
    required this.onToggleOpen,
    required this.onTick,
  });

  String get _kind => step['kind'] as String? ?? '';
  bool get _tickable => _kind == 'topic' || _kind == 'deliverable';
  bool get _complete => step['complete'] == true;
  bool get _current => step['is_current'] == true;

  /// True only for the innermost current node. The server marks the whole
  /// chain so any level can be highlighted; showing the badge on all three at
  /// once just repeats itself.
  bool get _isDeepestCurrent {
    if (!_current) return false;
    return !_children.any((c) => (c as Map)['is_current'] == true);
  }
  List get _children => (step['children'] as List?) ?? [];

  @override
  Widget build(BuildContext context) {
    if (_kind == 'note') {
      return Padding(
        padding: EdgeInsets.only(left: 12.0 * depth, bottom: 10, top: 2),
        child: Text(step['title'] as String? ?? '',
            style: GoogleFonts.inter(
                fontSize: 12.5, height: 1.45, color: AppColors.textSecondary)),
      );
    }
    if (_tickable) return _tickRow(context);
    return _section(context);
  }

  Widget _tickRow(BuildContext context) {
    final id = step['id'] as int;
    final busy = busyIds.contains(id);
    final isDeliverable = _kind == 'deliverable';
    return InkWell(
      onTap: busy ? null : () => onTick(step),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 22,
            height: 22,
            child: busy
                ? const Padding(
                    padding: EdgeInsets.all(3),
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(
                    _complete
                        ? Icons.check_circle_rounded
                        : isDeliverable
                            ? Icons.emoji_events_outlined
                            : Icons.circle_outlined,
                    size: 20,
                    color: _complete
                        ? const Color(0xFF4CAF50)
                        : AppColors.textSecondary.withValues(alpha: 0.45),
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              step['title'] as String? ?? '',
              style: GoogleFonts.inter(
                fontSize: 13,
                height: 1.4,
                fontWeight: isDeliverable ? FontWeight.w600 : FontWeight.w400,
                color: _complete ? AppColors.textSecondary : AppColors.textPrimary,
                decoration: _complete ? TextDecoration.lineThrough : null,
                decorationColor: AppColors.textSecondary,
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _section(BuildContext context) {
    final id = step['id'] as int;
    final total = (step['items_total'] as int?) ?? 0;
    final done = (step['items_done'] as int?) ?? 0;
    final isMonth = _kind == 'month';
    final isOutcome = _kind == 'outcome';

    final accent = isMonth
        ? const Color(0xFF12326B)
        : isOutcome
            ? const Color(0xFFE65100)
            : AppColors.primary;

    final header = InkWell(
      onTap: () => onToggleOpen(id),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: isMonth ? 14 : 11, horizontal: 13),
        child: Row(children: [
          Icon(
            _complete
                ? Icons.check_circle_rounded
                : isOutcome
                    ? Icons.workspace_premium_rounded
                    : isMonth
                        ? Icons.calendar_month_rounded
                        : Icons.folder_outlined,
            size: isMonth ? 20 : 17,
            color: _complete ? const Color(0xFF4CAF50) : accent,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Text(step['title'] as String? ?? '',
                      style: GoogleFonts.poppins(
                          fontSize: isMonth ? 14.5 : 13,
                          fontWeight: isMonth ? FontWeight.w600 : FontWeight.w500,
                          color: AppColors.textPrimary)),
                ),
                if ((step['level_label'] as String? ?? '').isNotEmpty) ...[
                  const SizedBox(width: 8),
                  _LevelPill(label: step['level_label'] as String, index: (step['order'] as int?) ?? 0),
                ],
              ]),
              if (!includedInPlan) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFFFCC80)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.lock_clock_rounded,
                        size: 12, color: Color(0xFFE65100)),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        otherPlanName.isEmpty
                            ? 'Not part of this track'
                            : 'Included in the $otherPlanName track',
                        style: GoogleFonts.inter(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFE65100)),
                      ),
                    ),
                  ]),
                ),
              ],
              if (signedIn && total > 0) ...[
                const SizedBox(height: 5),
                Row(children: [
                  SizedBox(
                    width: 70,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: LinearProgressIndicator(
                        value: done / total,
                        minHeight: 4,
                        backgroundColor: AppColors.textSecondary.withValues(alpha: 0.16),
                        valueColor: AlwaysStoppedAnimation(
                            _complete ? const Color(0xFF4CAF50) : accent),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('$done/$total',
                      style: GoogleFonts.inter(
                          fontSize: 10.5, color: AppColors.textSecondary)),
                ]),
              ],
            ]),
          ),
          if (_isDeepestCurrent)
            Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: accent, borderRadius: BorderRadius.circular(20)),
              child: Text('YOU ARE HERE',
                  style: GoogleFonts.inter(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: Colors.white)),
            ),
          Icon(isOpen ? Icons.expand_less_rounded : Icons.expand_more_rounded,
              size: 20, color: AppColors.textSecondary),
        ]),
      ),
    );

    final body = Padding(
      padding: EdgeInsets.only(left: isMonth ? 8 : 16, right: 4, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final c in _children)
            _Node(
              step: c as Map<String, dynamic>,
              depth: depth + 1,
              signedIn: signedIn,
              isOpen: openIds.contains(c['id']),
              openIds: openIds,
              busyIds: busyIds,
              onToggleOpen: onToggleOpen,
              onTick: onTick,
            ),
        ],
      ),
    );

    // Months are cards; everything inside them is plain, so nesting reads as
    // depth rather than as four stacked borders.
    if (isMonth) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _current
                ? accent.withValues(alpha: 0.5)
                : Colors.black.withValues(alpha: 0.07),
            width: _current ? 1.5 : 1,
          ),
        ),
        child: Column(children: [header, if (isOpen) body]),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      header,
      if (isOpen) body,
    ]);
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.route_rounded, size: 44, color: AppColors.textSecondary),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Try again')),
          ]),
        ),
      );
}

/// Foundation -> Industry-ready. Colour carries the progression as much as the
/// word does, so the jump in difficulty is legible before anything is read.
class _LevelPill extends StatelessWidget {
  final String label;
  final int index;
  const _LevelPill({required this.label, required this.index});

  static const _colors = [
    Color(0xFF2E7D32), // Foundation
    Color(0xFF0277BD), // Intermediate
    Color(0xFF6A1B9A), // Advanced
    Color(0xFFE65100), // Industry-ready
  ];

  @override
  Widget build(BuildContext context) {
    final c = _colors[index.clamp(0, _colors.length - 1)];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.11),
        border: Border.all(color: c.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label.toUpperCase(),
          style: GoogleFonts.inter(
              fontSize: 8.5, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: c)),
    );
  }
}

/// The conversion point. Everything above proves the programme is real and
/// long; this says the obvious thing out loud — you could try this alone — and
/// then names what alone does not get you.
class _EnrollCta extends StatelessWidget {
  final Map<String, dynamic> roadmap;
  final int planIndex;
  const _EnrollCta({required this.roadmap, this.planIndex = 0});

  @override
  Widget build(BuildContext context) {
    final headline = roadmap['cta_headline'] as String? ?? '';
    final body = roadmap['cta_body'] as String? ?? '';
    if (headline.isEmpty && body.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0B2450), Color(0xFF16407F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (headline.isNotEmpty)
          Text(headline,
              style: GoogleFonts.poppins(
                  color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600, height: 1.3)),
        if (body.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(body,
              style: GoogleFonts.inter(
                  color: Colors.white.withValues(alpha: 0.88), fontSize: 13.5, height: 1.6)),
        ],
        const SizedBox(height: 20),
        // Leading with the callback: after a page this long the reader is
        // persuaded but tired, and naming a time is less work than composing
        // a question.
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () =>
                askForCallback(context, roadmap, planIndex: planIndex),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF0B2450),
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.phone_in_talk_rounded, size: 19),
            label: Text('Request a callback',
                style: GoogleFonts.poppins(
                    fontSize: 15, fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => openRoadmapWhatsApp(context, roadmap,
                planIndex: planIndex, callback: false),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.45)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.chat_rounded, size: 18),
            label: Text('Message us on WhatsApp instead',
                style: GoogleFonts.poppins(
                    fontSize: 14, fontWeight: FontWeight.w500)),
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: Text('Ask about the next batch, the fees, or anything else',
              style: GoogleFonts.inter(
                  color: Colors.white.withValues(alpha: 0.6), fontSize: 11.5)),
        ),
      ]),
    );
  }
}


/// Opens WhatsApp with a message already written.
///
/// Asking someone to compose their own first message is asking them to decide
/// what they want before they know what to ask for. A callback request is a
/// smaller thing to agree to than "enquire", and it moves the conversation to
/// a channel where we can actually answer.
/// The callback ask. Opens the form; WhatsApp stays available inside it.
void askForCallback(BuildContext context, Map<String, dynamic> roadmap,
    {required int planIndex}) {
  final plans = (roadmap['plans'] as List?) ?? [];
  final planName = plans.isEmpty
      ? ''
      : ((plans[planIndex.clamp(0, plans.length - 1)] as Map)['name']
              as String? ??
          '');
  CallbackSheet.show(
    context,
    plan: planName,
    source: 'roadmap',
    onWhatsApp: () => openRoadmapWhatsApp(context, roadmap,
        planIndex: planIndex, callback: true),
  );
}

Future<void> openRoadmapWhatsApp(
  BuildContext context,
  Map<String, dynamic> roadmap, {
  required int planIndex,
  required bool callback,
}) async {
  final number = roadmap['whatsapp_number'] as String? ?? '';
  final title = roadmap['title'] as String? ?? 'the programme';
  final plans = (roadmap['plans'] as List?) ?? [];
  // Naming the plan they were looking at saves the first two messages of
  // every conversation.
  final planName = plans.isEmpty
      ? ''
      : ((plans[planIndex.clamp(0, plans.length - 1)] as Map)['name']
              as String? ??
          '');

  final text = Uri.encodeComponent(callback
      ? "Hi! Please call me back about the $title"
          "${planName.isEmpty ? '' : ' ($planName batch)'}.\n\n"
          "Name:\nCity:\nBest time to call:"
      : "Hi! I saw the $title roadmap on your site and I'd like to join"
          "${planName.isEmpty ? '' : ' ($planName batch)'}. "
          "Could you tell me about the next batch and the fees?");

  if (number.isEmpty) {
    // No number configured yet — send them somewhere real rather than
    // opening a broken link.
    if (context.mounted) Navigator.pushNamed(context, '/partner');
    return;
  }
  final uri = Uri.parse('https://wa.me/$number?text=$text');
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open WhatsApp')));
    }
  }
}

/// The bar pinned to the bottom of the roadmap.
///
/// Two actions, weighted. Requesting a callback is the smaller commitment and
/// gets the width; chatting now is for the person who has already decided and
/// does not want to wait for us.
class _StickyCta extends StatelessWidget {
  final Map<String, dynamic> roadmap;
  final int planIndex;
  const _StickyCta({required this.roadmap, required this.planIndex});

  @override
  Widget build(BuildContext context) {
    final start = (roadmap['start_label'] as String? ?? '').trim();
    final seats = (roadmap['seats_left'] as String? ?? '').trim();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 16,
              offset: const Offset(0, -3)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Only shown when there is something true to say. An empty
            // scarcity line is worse than none.
            if (start.isNotEmpty || seats.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  if (start.isNotEmpty) ...[
                    const Icon(Icons.event_rounded,
                        size: 13, color: Color(0xFF12326B)),
                    const SizedBox(width: 5),
                    Text(start,
                        style: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF12326B))),
                  ],
                  if (start.isNotEmpty && seats.isNotEmpty)
                    Container(
                      width: 3,
                      height: 3,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: const BoxDecoration(
                          color: Color(0xFF9AA5B5), shape: BoxShape.circle),
                    ),
                  if (seats.isNotEmpty)
                    Text('Only $seats seats left',
                        style: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFC62828))),
                ]),
              ),
            Row(children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () =>
                      askForCallback(context, roadmap, planIndex: planIndex),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF12326B),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.phone_in_talk_rounded,
                      size: 18, color: Colors.white),
                  label: Text('Request a callback',
                      style: GoogleFonts.poppins(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white)),
                ),
              ),
              const SizedBox(width: 9),
              SizedBox(
                width: 52,
                height: 48,
                child: FilledButton(
                  onPressed: () => openRoadmapWhatsApp(context, roadmap,
                      planIndex: planIndex, callback: false),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Icon(Icons.chat_rounded,
                      size: 21, color: Colors.white),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}


/// Lets a reader arrive at a price instead of being handed one.
///
/// People were stalling at the number. The number had not changed, but the
/// question had: shown one figure with nothing around it, someone decides
/// whether they can afford us. Asked when they are free and how long they
/// want to take, they decide which of our options fits — and every answer
/// has a price attached.
///
/// Availability comes first because it is the only hard constraint. Someone
/// in class on weekdays cannot buy a weekday track at any price, and showing
/// them one is worse than showing them nothing.
class _PlanBuilder extends StatelessWidget {
  final List plans;
  final int planIndex;
  final ValueChanged<int> onPlanChanged;
  const _PlanBuilder({
    required this.plans,
    required this.planIndex,
    required this.onPlanChanged,
  });

  String _avail(int i) => (plans[i] as Map)['availability'] as String? ?? '';

  /// Indices sharing the selected plan's availability, cheapest first, so the
  /// slider always moves through real options rather than empty stops.
  List<int> get _siblings {
    final want = _avail(planIndex);
    final out = <int>[];
    for (var i = 0; i < plans.length; i++) {
      if (_avail(i) == want) out.add(i);
    }
    out.sort((a, b) => ((plans[a] as Map)['fee'] as int? ?? 0)
        .compareTo((plans[b] as Map)['fee'] as int? ?? 0));
    return out.isEmpty ? [planIndex] : out;
  }

  /// The cheapest plan for an availability — where the slider lands when
  /// someone switches, because starting at the top of a range is the thing
  /// that made them hesitate in the first place.
  int _cheapestFor(String availability) {
    int? best;
    for (var i = 0; i < plans.length; i++) {
      if (_avail(i) != availability) continue;
      final fee = (plans[i] as Map)['fee'] as int? ?? 0;
      if (best == null || fee < ((plans[best] as Map)['fee'] as int? ?? 0)) {
        best = i;
      }
    }
    return best ?? planIndex;
  }

  static String _money(int rupees) {
    // Indian grouping: 1,49,000 rather than 149,000.
    final s = rupees.toString();
    if (s.length <= 3) return s;
    final head = s.substring(0, s.length - 3);
    final tail = s.substring(s.length - 3);
    final buf = StringBuffer();
    for (var i = 0; i < head.length; i++) {
      if (i > 0 && (head.length - i) % 2 == 0) buf.write(',');
      buf.write(head[i]);
    }
    return '$buf,$tail';
  }

  @override
  Widget build(BuildContext context) {
    final plan = plans[planIndex.clamp(0, plans.length - 1)] as Map;
    final fee = plan['fee'] as int? ?? 0;
    final listFee = plan['list_fee'] as int?;
    final sibs = _siblings;
    final slot = sibs.indexOf(planIndex).clamp(0, sibs.length - 1);

    final availabilities = <String>[];
    for (var i = 0; i < plans.length; i++) {
      final a = _avail(i);
      if (a.isNotEmpty && !availabilities.contains(a)) availabilities.add(a);
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(15, 14, 15, 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('BUILD YOUR PLAN',
            style: GoogleFonts.inter(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.9,
                color: Colors.white.withValues(alpha: 0.55))),
        const SizedBox(height: 12),

        if (availabilities.length > 1) ...[
          Text('When are you free?',
              style: GoogleFonts.inter(
                  fontSize: 12, color: Colors.white.withValues(alpha: 0.82))),
          const SizedBox(height: 7),
          Row(children: [
            for (final a in availabilities) ...[
              Expanded(
                child: GestureDetector(
                  onTap: () => onPlanChanged(_cheapestFor(a)),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: a == _avail(planIndex)
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(a == 'weekend' ? 'Weekends' : 'Weekdays',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: a == _avail(planIndex)
                                ? const Color(0xFF0B2450)
                                : Colors.white)),
                  ),
                ),
              ),
              if (a != availabilities.last) const SizedBox(width: 8),
            ],
          ]),
          const SizedBox(height: 14),
        ],

        if (sibs.length > 1) ...[
          Row(children: [
            Text('How long do you want to take?',
                style: GoogleFonts.inter(
                    fontSize: 12, color: Colors.white.withValues(alpha: 0.82))),
          ]),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: Colors.white,
              inactiveTrackColor: Colors.white.withValues(alpha: 0.22),
              thumbColor: Colors.white,
              overlayColor: Colors.white.withValues(alpha: 0.14),
              trackHeight: 3,
              tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 2.5),
              activeTickMarkColor: Colors.white,
              inactiveTickMarkColor: Colors.white.withValues(alpha: 0.35),
            ),
            child: Slider(
              value: slot.toDouble(),
              min: 0,
              max: (sibs.length - 1).toDouble(),
              divisions: sibs.length - 1,
              onChanged: (v) => onPlanChanged(sibs[v.round()]),
            ),
          ),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            for (final i in sibs)
              Text((plans[i] as Map)['duration_label'] as String? ?? '',
                  style: GoogleFonts.inter(
                      fontSize: 10.5,
                      fontWeight:
                          i == planIndex ? FontWeight.w700 : FontWeight.w400,
                      color: Colors.white.withValues(
                          alpha: i == planIndex ? 0.95 : 0.5))),
          ]),
          const SizedBox(height: 14),
        ],

        // The outcome of the two answers above.
        Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(plan['name'] as String? ?? '',
                          style: GoogleFonts.poppins(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF0B2450))),
                      const SizedBox(height: 2),
                      Text(plan['schedule_label'] as String? ?? '',
                          style: GoogleFonts.inter(
                              fontSize: 11.5,
                              color: const Color(0xFF5A6B82))),
                    ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                if (listFee != null)
                  Text('Rs ${_money(listFee)}',
                      style: GoogleFonts.inter(
                          fontSize: 11.5,
                          color: const Color(0xFF9AA5B5),
                          decoration: TextDecoration.lineThrough,
                          decorationColor: const Color(0xFF9AA5B5))),
                Text('Rs ${_money(fee)}',
                    style: GoogleFonts.poppins(
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                        color: const Color(0xFF0B2450))),
                Text('+ GST',
                    style: GoogleFonts.inter(
                        fontSize: 10, color: const Color(0xFF9AA5B5))),
              ]),
            ]),
            const SizedBox(height: 11),
            Wrap(spacing: 7, runSpacing: 7, children: [
              _Chip(
                  icon: Icons.timer_outlined,
                  label: plan['hours_label'] as String? ?? '',
                  dark: true),
              _Chip(
                  icon: Icons.layers_outlined,
                  label: plan['stage_limit'] is int
                      ? 'Stages 1-${plan['stage_limit']}'
                      : 'All 4 stages',
                  dark: true),
            ]),
            if ((plan['note'] as String? ?? '').isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(plan['note'] as String,
                  style: GoogleFonts.inter(
                      fontSize: 11.5,
                      height: 1.5,
                      color: const Color(0xFF5A6B82))),
            ],
          ]),
        ),
      ]),
    );
  }
}
