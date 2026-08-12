// The roadmap — an ordered path with a visible finish line.
//
// Students say the hard part is not finding material, it is not knowing what
// to learn, in what order, or whether they are on track. So this screen answers
// exactly three questions and nothing else:
//
//   what is the path        → the ordered steps
//   where am I              → progress, and one highlighted "you are here"
//   what do I get at the end → the outcome, and a Challenge as the last step
//
// It is public on purpose. Seeing the path is the pitch; hiding it behind a
// login wastes the thing that makes someone want an account.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

  /// Which step is expanded. Starts on the current one so the screen opens
  /// already answering "what do I do next" — the reason they came.
  int? _expanded;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await ApiService.getRoadmap(widget.slug);
      _roadmap = r;
      final steps = (r['steps'] as List?) ?? [];
      for (var i = 0; i < steps.length; i++) {
        if (steps[i]['is_current'] == true) {
          _expanded = i;
          break;
        }
      }
      _expanded ??= steps.isEmpty ? null : 0;
    } catch (e) {
      _error = e is ApiException ? e.message : 'Could not load the roadmap';
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final r = _roadmap;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(r?['title'] as String? ?? 'Roadmap',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? _ErrorState(message: _error, onRetry: () {
                  setState(() { _loading = true; _error = ''; });
                  _load();
                })
              : r == null
                  ? const SizedBox.shrink()
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                        children: [
                          _Header(roadmap: r),
                          const SizedBox(height: 20),
                          ..._buildSteps(r),
                        ],
                      ),
                    ),
    );
  }

  List<Widget> _buildSteps(Map<String, dynamic> r) {
    final steps = (r['steps'] as List?) ?? [];
    return [
      for (var i = 0; i < steps.length; i++)
        _StepTile(
          step: steps[i] as Map<String, dynamic>,
          index: i,
          isLast: i == steps.length - 1,
          expanded: _expanded == i,
          signedIn: r['signed_in'] == true,
          onTap: () => setState(() => _expanded = _expanded == i ? null : i),
        ),
    ];
  }
}

/// Title, what you walk away with, how long it takes, and how far along you
/// are. The duration is not decoration — "4-6 months" is what makes this read
/// as a programme rather than a playlist.
class _Header extends StatelessWidget {
  final Map<String, dynamic> roadmap;
  const _Header({required this.roadmap});

  @override
  Widget build(BuildContext context) {
    final percent = (roadmap['percent'] as int?) ?? 0;
    final done = (roadmap['steps_done'] as int?) ?? 0;
    final total = (roadmap['step_count'] as int?) ?? 0;
    final duration = roadmap['duration_label'] as String? ?? '';
    final outcome = roadmap['outcome'] as String? ?? '';
    final signedIn = roadmap['signed_in'] == true;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF12326B), Color(0xFF1565C0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (roadmap['subtitle'] != null && (roadmap['subtitle'] as String).isNotEmpty)
          Text(roadmap['subtitle'] as String,
              style: GoogleFonts.inter(
                  color: Colors.white.withValues(alpha: 0.85), fontSize: 13.5, height: 1.4)),
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (duration.isNotEmpty) _Chip(icon: Icons.schedule_rounded, label: duration),
          _Chip(icon: Icons.list_alt_rounded, label: '$total steps'),
        ]),
        if (outcome.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.flag_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('What you finish with',
                      style: GoogleFonts.inter(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.4)),
                  const SizedBox(height: 3),
                  Text(outcome,
                      style: GoogleFonts.inter(
                          color: Colors.white, fontSize: 13, height: 1.4)),
                ]),
              ),
            ]),
          ),
        ],
        // Progress is only meaningful for someone with progress. Showing "0%"
        // to a visitor makes a path they might want look like a chore.
        if (signedIn) ...[
          const SizedBox(height: 18),
          Row(children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: total == 0 ? 0 : done / total,
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
          const SizedBox(height: 6),
          Text(
            percent == 100
                ? 'Path complete — go take a Challenge'
                : done == 0
                    ? 'Not started — the first step is below'
                    : '$percent% done',
            style: GoogleFonts.inter(
                color: Colors.white.withValues(alpha: 0.8), fontSize: 12),
          ),
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

/// One step, as a node on a vertical line. Tapping expands it — the list stays
/// scannable at a glance, and the detail is there when a step matters.
class _StepTile extends StatelessWidget {
  final Map<String, dynamic> step;
  final int index;
  final bool isLast;
  final bool expanded;
  final bool signedIn;
  final VoidCallback onTap;

  const _StepTile({
    required this.step,
    required this.index,
    required this.isLast,
    required this.expanded,
    required this.signedIn,
    required this.onTap,
  });

  bool get _complete => step['complete'] == true;
  bool get _current => step['is_current'] == true;
  String get _kind => step['kind'] as String? ?? 'module';

  ({IconData icon, Color color, String label}) get _kindStyle => switch (_kind) {
        'challenge' => (
            icon: Icons.workspace_premium_rounded,
            color: const Color(0xFFE65100),
            label: 'Challenge'
          ),
        'workshop' => (
            icon: Icons.groups_rounded,
            color: const Color(0xFF6A1B9A),
            label: 'Workshop'
          ),
        'milestone' => (
            icon: Icons.flag_rounded,
            color: const Color(0xFF2E7D32),
            label: 'Milestone'
          ),
        _ => (icon: Icons.menu_book_rounded, color: AppColors.primary, label: 'Learn'),
      };

  @override
  Widget build(BuildContext context) {
    final style = _kindStyle;
    final dotColor = _complete
        ? const Color(0xFF4CAF50)
        : _current
            ? style.color
            : AppColors.textSecondary.withValues(alpha: 0.35);

    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // The spine: a node and the line to the next step.
        Column(children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: _complete || _current ? dotColor : Colors.transparent,
              border: Border.all(color: dotColor, width: 2),
              shape: BoxShape.circle,
            ),
            child: _complete
                ? const Icon(Icons.check_rounded, size: 17, color: Colors.white)
                : Center(
                    child: Text('${index + 1}',
                        style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _current ? Colors.white : AppColors.textSecondary)),
                  ),
          ),
          if (!isLast)
            Expanded(
              child: Container(
                width: 2,
                margin: const EdgeInsets.symmetric(vertical: 4),
                color: _complete
                    ? const Color(0xFF4CAF50).withValues(alpha: 0.5)
                    : AppColors.textSecondary.withValues(alpha: 0.18),
              ),
            ),
        ]),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _current
                        ? style.color.withValues(alpha: 0.55)
                        : Colors.black.withValues(alpha: 0.07),
                    width: _current ? 1.6 : 1,
                  ),
                  boxShadow: _current
                      ? [BoxShadow(color: style.color.withValues(alpha: 0.13), blurRadius: 14)]
                      : null,
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(style.icon, size: 15, color: style.color),
                    const SizedBox(width: 6),
                    Text(style.label.toUpperCase(),
                        style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: style.color)),
                    if (step['is_optional'] == true) ...[
                      const SizedBox(width: 6),
                      Text('· optional',
                          style: GoogleFonts.inter(
                              fontSize: 10, color: AppColors.textSecondary)),
                    ],
                    const Spacer(),
                    // "You are here" is the single most useful thing on the
                    // screen, so it is stated, not merely implied by styling.
                    if (_current)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: style.color,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('YOU ARE HERE',
                            style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                                color: Colors.white)),
                      ),
                    Icon(expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                        size: 20, color: AppColors.textSecondary),
                  ]),
                  const SizedBox(height: 7),
                  Text(step['title'] as String? ?? '',
                      style: GoogleFonts.poppins(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: _complete
                              ? AppColors.textSecondary
                              : AppColors.textPrimary)),
                  if ((step['duration_label'] as String? ?? '').isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(children: [
                      Icon(Icons.schedule_rounded,
                          size: 12, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(step['duration_label'] as String,
                          style: GoogleFonts.inter(
                              fontSize: 11.5, color: AppColors.textSecondary)),
                    ]),
                  ],
                  if (signedIn && _kind == 'module' && (step['items_total'] as int? ?? 0) > 0) ...[
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: (step['items_done'] as int) / (step['items_total'] as int),
                            minHeight: 5,
                            backgroundColor:
                                AppColors.textSecondary.withValues(alpha: 0.15),
                            valueColor: AlwaysStoppedAnimation(
                                _complete ? const Color(0xFF4CAF50) : style.color),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('${step['items_done']}/${step['items_total']}',
                          style: GoogleFonts.inter(
                              fontSize: 11, color: AppColors.textSecondary)),
                    ]),
                  ],
                  AnimatedCrossFade(
                    duration: const Duration(milliseconds: 180),
                    crossFadeState: expanded
                        ? CrossFadeState.showFirst
                        : CrossFadeState.showSecond,
                    firstChild: Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        (step['description'] as String? ?? '').isEmpty
                            ? 'No description yet.'
                            : step['description'] as String,
                        style: GoogleFonts.inter(
                            fontSize: 12.5,
                            height: 1.5,
                            color: AppColors.textSecondary),
                      ),
                    ),
                    secondChild: const SizedBox(width: double.infinity),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
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
