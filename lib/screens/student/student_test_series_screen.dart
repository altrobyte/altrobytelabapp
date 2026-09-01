import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../services/api_service.dart';
import '../../widgets/auth_sheet.dart';
import '../../widgets/share_test_link.dart';

/// Unified Test Series tab — a "Generate a Custom Test Series"
/// CTA up top, every individual quiz (whether authored inside a course or
/// published standalone) in one flat grid, and curated multi-test Test
/// Series below. Quizzes used to be split into separate "Course Quizzes" /
/// "General Tests" labeled groups — same content, so merged into one list.
class StudentTestSeriesScreen extends StatefulWidget {
  const StudentTestSeriesScreen({super.key});

  @override
  State<StudentTestSeriesScreen> createState() => _StudentTestSeriesScreenState();
}

class _StudentTestSeriesScreenState extends State<StudentTestSeriesScreen> {
  List<dynamic> _series = [];
  List<dynamic> _moduleTests = [];
  List<dynamic> _standaloneTests = [];
  bool _loading = true;
  String? _error;
  bool _needsSignIn = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; _needsSignIn = false; });
    try {
      // Don't gate on the locally stored institute id. Login writes
      // `institute_id ?? 0`, so a student without one ended up asking for
      // institute 0 and always got an empty tab. The server resolves it from
      // the token and falls back to the Altrobyte Lab institute.
      final data = await ApiService.getTestSeriesForStudent();
      if (!mounted) return;
      setState(() {
        _series = data['series'] as List? ?? [];
        _moduleTests = data['module_tests'] as List? ?? [];
        _standaloneTests = data['standalone_tests'] as List? ?? [];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        // A 401 is not an error to report, it is a door to open. Telling
        // somebody to sign in and then giving them only a Retry button
        // leaves them pressing it forever.
        _needsSignIn = e is ApiException && e.statusCode == 401;
        _error = e is ApiException ? e.message : e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _signInThenLoad() async {
    final ok = await showAuthSheet(context, reason: 'to see your test series');
    if (ok && mounted) _load();
  }

  Color _parseColor(String? hex) {
    try {
      return Color(int.parse((hex ?? '').replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppColors.primary;
    }
  }

  /// Flattens module quizzes + standalone tests into one list — same
  /// underlying data, just no longer split into separate labeled groups.
  List<Map<String, dynamic>> get _allQuizzes {
    final result = <Map<String, dynamic>>[];
    for (final m in _moduleTests) {
      final tests = (m['tests'] as List?) ?? [];
      for (final t in tests) {
        result.add({
          ...Map<String, dynamic>.from(t),
          'source': m['module_title'],
          'color': m['module_color'],
        });
      }
    }
    for (final t in _standaloneTests) {
      result.add({...Map<String, dynamic>.from(t), 'source': null, 'color': null});
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final quizzes = _allQuizzes;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text('Test Series',
            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(
                          _needsSignIn
                              ? Icons.lock_outline_rounded
                              : Icons.wifi_off_rounded,
                          size: 38,
                          color: AppColors.textSecondary),
                      const SizedBox(height: 14),
                      Text(
                          _needsSignIn
                              ? 'Sign in to see your test series'
                              : _error!,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                              fontSize: 14,
                              height: 1.5,
                              color: AppColors.textSecondary)),
                      if (_needsSignIn) ...[
                        const SizedBox(height: 6),
                        Text('Your attempts and scores are saved to your account.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                                fontSize: 12,
                                height: 1.5,
                                color: AppColors.textSecondary)),
                      ],
                      const SizedBox(height: 18),
                      SizedBox(
                        width: 220,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                          ),
                          onPressed: _needsSignIn ? _signInThenLoad : _load,
                          child: Text(_needsSignIn ? 'Sign in' : 'Retry',
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600, fontSize: 14)),
                        ),
                      ),
                    ]),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: CustomScrollView(
                    slivers: [
                      if (quizzes.isNotEmpty)
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                          sliver: SliverGrid(
                            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 220,
                              mainAxisSpacing: 14,
                              crossAxisSpacing: 14,
                              mainAxisExtent: 210,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, i) => _QuizTile(quiz: quizzes[i], color: _parseColor(quizzes[i]['color'])),
                              childCount: quizzes.length,
                            ),
                          ),
                        ),
                      if (_series.isNotEmpty) ...[
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                          sliver: SliverToBoxAdapter(child: _SectionLabel('Test Series')),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, i) => _SeriesCard(series: _series[i], color: _parseColor(_series[i]['color'])),
                              childCount: _series.length,
                            ),
                          ),
                        ),
                      ],
                      if (_series.isEmpty && quizzes.isEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 40),
                            child: Center(
                              child: Column(children: [
                                Icon(Icons.quiz_outlined, size: 40, color: Colors.grey[300]),
                                const SizedBox(height: 10),
                                Text('No test series or quizzes published yet',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.inter(color: AppColors.textSecondary)),
                              ]),
                            ),
                          ),
                        ),
                      const SliverToBoxAdapter(child: SizedBox(height: 20)),
                    ],
                  ),
                ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(width: 4, height: 16, color: AppColors.primary),
      const SizedBox(width: 8),
      Text(text, style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textPrimary)),
    ]);
  }
}

/// A single quiz card — a colored cover header (icon on a gradient,
/// matching the poster-style look used for Live Sessions) with the title
/// and details below, rather than a flat icon-and-text row. Course/general
/// origin shown as a small subtitle tag rather than a separate labeled
/// section, so every quiz sits in one unified, browsable grid.
class _QuizTile extends StatelessWidget {
  final Map<String, dynamic> quiz;
  final Color color;
  const _QuizTile({required this.quiz, required this.color});

  @override
  Widget build(BuildContext context) {
    final source = quiz['source'] as String?;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/test/${quiz['id']}'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            height: 118,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, Color.lerp(color, Colors.black, 0.25)!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(clipBehavior: Clip.none, children: [
              Positioned(
                right: -18, top: -18,
                child: Icon(Icons.fact_check_rounded, size: 90, color: Colors.white.withValues(alpha: 0.14)),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.fact_check_rounded, color: Colors.white, size: 22),
                    const SizedBox(height: 8),
                    Text(quiz['title'] ?? '',
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5)),
                  ],
                ),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              if (source != null) ...[
                Text(source,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(fontSize: 10.5, color: color, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
              ],
              Row(children: [
                Icon(Icons.timer_outlined, size: 12, color: AppColors.textSecondary),
                const SizedBox(width: 3),
                Text('${quiz['duration_mins'] ?? 0} min',
                    style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
                const Spacer(),
                // Beside the chevron, where the eye already goes. Sending a
                // test to a class group is a different job from taking one,
                // so it should not require opening the test first.
                InkWell(
                  onTap: () => shareTestLink(
                      context,
                      id: quiz['id'] as int,
                      title: '${quiz['title'] ?? 'Test'}',
                      minutes: (quiz['duration_mins'] as num?)?.toInt() ?? 0,
                      questions:
                          (quiz['question_count'] as num?)?.toInt() ?? 0),
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 4),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.link_rounded, size: 13, color: color),
                      const SizedBox(width: 4),
                      Text('Copy link',
                          style: GoogleFonts.inter(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: color)),
                    ]),
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(Icons.arrow_forward_ios_rounded, size: 11, color: Colors.grey),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _SeriesCard extends StatefulWidget {
  final Map<String, dynamic> series;
  final Color color;
  const _SeriesCard({required this.series, required this.color});

  @override
  State<_SeriesCard> createState() => _SeriesCardState();
}

class _SeriesCardState extends State<_SeriesCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final tests = widget.series['tests'] as List? ?? [];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.quiz_rounded, color: widget.color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.series['title'] ?? '',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14.5)),
                  if ((widget.series['description'] ?? '').isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(widget.series['description'],
                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                  const SizedBox(height: 4),
                  Text('${tests.length} test${tests.length == 1 ? '' : 's'}',
                      style: GoogleFonts.inter(fontSize: 11.5, color: widget.color, fontWeight: FontWeight.w600)),
                ]),
              ),
              AnimatedRotation(
                turns: _expanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(Icons.expand_more_rounded, color: Colors.grey[400]),
              ),
            ]),
          ),
        ),
        if (_expanded) ...[
          const Divider(height: 1),
          ...tests.map((t) => ListTile(
                dense: true,
                leading: Icon(Icons.description_outlined, color: widget.color, size: 20),
                title: Text(t['title'] ?? '', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500)),
                subtitle: Text('${t['subject'] ?? ''} · ${t['duration_mins'] ?? 0} min',
                    style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.textSecondary)),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                onTap: () => context.push('/test/${t['id']}'),
              )),
          // The series has an address of its own now, and that page is the
          // one worth sending to a group — this tab cannot be shared.
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () =>
                    context.push('/test-series/${widget.series['id']}'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: widget.color,
                  side: BorderSide(color: widget.color.withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                icon: const Icon(Icons.open_in_new_rounded, size: 15),
                label: Text('Open series page · share',
                    style: GoogleFonts.inter(
                        fontSize: 12.5, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ],
      ]),
    );
  }
}
