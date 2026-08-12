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
import '../../constants/app_colors.dart';
import '../../services/api_service.dart';

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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await ApiService.getRoadmap(widget.slug);
      _roadmap = r;
      if (_open.isEmpty) _openCurrentBranch((r['steps'] as List?) ?? []);
    } catch (e) {
      _error = e is ApiException ? e.message : 'Could not load the roadmap';
    }
    if (mounted) setState(() => _loading = false);
  }

  /// Open every ancestor of the current step, so it is visible without hunting.
  bool _openCurrentBranch(List nodes) {
    for (final n in nodes) {
      final node = n as Map<String, dynamic>;
      final children = (node['children'] as List?) ?? [];
      final hit = node['is_current'] == true || _openCurrentBranch(children);
      if (hit) {
        _open.add(node['id'] as int);
        return true;
      }
    }
    return false;
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

  @override
  Widget build(BuildContext context) {
    final r = _roadmap;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(r?['title'] as String? ?? 'Roadmap',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 17)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
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
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 48),
                        children: [
                          _Header(roadmap: r),
                          const SizedBox(height: 18),
                          for (final m in (r['steps'] as List?) ?? [])
                            _Node(
                              step: m as Map<String, dynamic>,
                              depth: 0,
                              signedIn: r['signed_in'] == true,
                              isOpen: _open.contains(m['id']),
                              openIds: _open,
                              busyIds: _busy,
                              onToggleOpen: (id) => setState(
                                  () => _open.contains(id) ? _open.remove(id) : _open.add(id)),
                              onTick: _toggle,
                            ),
                          const SizedBox(height: 8),
                          _EnrollCta(roadmap: r),
                        ],
                      ),
                    ),
    );
  }
}

class _Header extends StatelessWidget {
  final Map<String, dynamic> roadmap;
  const _Header({required this.roadmap});

  @override
  Widget build(BuildContext context) {
    final done = (roadmap['steps_done'] as int?) ?? 0;
    final total = (roadmap['step_count'] as int?) ?? 0;
    final duration = roadmap['duration_label'] as String? ?? '';
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
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (duration.isNotEmpty) _Chip(icon: Icons.schedule_rounded, label: duration),
          _Chip(icon: Icons.checklist_rounded, label: '$total milestones'),
        ]),
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
  const _Chip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 5),
          Text(label,
              style: GoogleFonts.inter(
                  color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600)),
        ]),
      );
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

  const _Node({
    required this.step,
    required this.depth,
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
  const _EnrollCta({required this.roadmap});

  Future<void> _openWhatsApp(BuildContext context) async {
    final number = roadmap['whatsapp_number'] as String? ?? '';
    final title = roadmap['title'] as String? ?? 'the programme';
    final text = Uri.encodeComponent(
        "Hi! I saw the $title roadmap on your site and I'd like to join. "
        "Could you tell me about the next batch and the fees?");
    // No number configured yet — send them somewhere real rather than opening
    // a broken link.
    final uri = number.isEmpty
        ? Uri.parse('/partner')
        : Uri.parse('https://wa.me/$number?text=$text');
    if (number.isEmpty) {
      if (context.mounted) Navigator.pushNamed(context, '/partner');
      return;
    }
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open WhatsApp')));
      }
    }
  }

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
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => _openWhatsApp(context),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.chat_rounded, size: 19, color: Colors.white),
            label: Text('Talk to us about joining',
                style: GoogleFonts.poppins(
                    fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
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
