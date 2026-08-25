import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../constants/app_colors.dart';
import '../../services/api_service.dart';

/// One test series, at an address you can send someone.
///
/// A series used to exist only inside the app's Test Series tab, which meant
/// it could not be posted in a WhatsApp group and nobody could see what was in
/// it before signing in. This page is public: the counts, the test list and
/// the share button all render for a stranger, and a signed-in student
/// additionally sees their own record against each test.
class TestSeriesPage extends StatefulWidget {
  final int seriesId;
  const TestSeriesPage({super.key, required this.seriesId});

  @override
  State<TestSeriesPage> createState() => _TestSeriesPageState();
}

class _TestSeriesPageState extends State<TestSeriesPage> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await ApiService.getSeriesPublic(widget.seriesId);
      if (mounted) setState(() { _data = d; _loading = false; });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e is ApiException ? e.message : 'Could not load. $e';
          _loading = false;
        });
      }
    }
  }

  Map<String, dynamic> get _series =>
      Map<String, dynamic>.from(_data?['series'] ?? {});
  List get _tests => (_data?['tests'] as List?) ?? const [];
  Map<String, dynamic> get _totals =>
      Map<String, dynamic>.from(_data?['totals'] ?? {});
  Map<String, dynamic>? get _me => _data?['me'] == null
      ? null
      : Map<String, dynamic>.from(_data!['me']);

  /// The short link, not the API host.
  ///
  /// /ts/:id redirects to the backend page that carries the preview tags, so
  /// what gets pasted into a group stays on the domain people recognise —
  /// and a reader whose network cannot resolve railway.app still opens it.
  String get _shareUrl => 'https://altrobytelab.com/ts/${widget.seriesId}';

  Future<void> _share() async {
    final title = _series['title'] ?? 'Test series';
    final bits = <String>[];
    if ((_totals['tests'] ?? 0) != 0) bits.add('${_totals['tests']} tests');
    if ((_totals['questions'] ?? 0) != 0) {
      bits.add('${_totals['questions']} questions');
    }
    final text = Uri.encodeComponent(
        '*$title*\n${bits.join(' · ')}\n\nFree practice tests from Altrobyte Lab:\n$_shareUrl');
    final uri = Uri.parse('https://wa.me/?text=$text');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      await _copy();
    }
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _shareUrl));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link copied')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 760;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primary,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        title: Text('Test series',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 17)),
        actions: [
          if (!_loading && _error.isEmpty)
            IconButton(
              tooltip: 'Copy link',
              onPressed: _copy,
              icon: const Icon(Icons.link_rounded, size: 20),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? _errorState()
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(16, 16, 16, wide ? 48 : 32),
                      children: [
                        _header(),
                        const SizedBox(height: 14),
                        if (_me != null) ...[_progress(), const SizedBox(height: 14)],
                        _shareBar(),
                        const SizedBox(height: 20),
                        Text('TESTS IN THIS SERIES',
                            style: GoogleFonts.inter(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.9,
                                color: const Color(0xFF9AA5B5))),
                        const SizedBox(height: 10),
                        for (var i = 0; i < _tests.length; i++)
                          _testTile(Map<String, dynamic>.from(_tests[i]), i),
                        if (_tests.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 28),
                            child: Text('No tests published in this series yet.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                    fontSize: 13, color: const Color(0xFF5A6B82))),
                          ),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _errorState() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.quiz_outlined, size: 42, color: Color(0xFF9AA5B5)),
            const SizedBox(height: 12),
            Text(_error,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 13.5, height: 1.5)),
            const SizedBox(height: 18),
            FilledButton(
                onPressed: () => context.go('/student/test-series'),
                child: const Text('See all test series')),
          ]),
        ),
      );

  Widget _header() {
    final colour = _parseColour(_series['color']) ?? AppColors.primary;
    final desc = '${_series['description'] ?? ''}'.trim();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colour, Color.lerp(colour, Colors.black, 0.25)!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${_series['title'] ?? 'Test series'}',
            style: GoogleFonts.poppins(
                fontSize: 21,
                height: 1.25,
                fontWeight: FontWeight.w700,
                color: Colors.white)),
        if (desc.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(desc,
              style: GoogleFonts.inter(
                  fontSize: 13,
                  height: 1.5,
                  color: Colors.white.withValues(alpha: 0.85))),
        ],
        const SizedBox(height: 14),
        // Counted from the rows, so the page cannot promise more than it has.
        Wrap(spacing: 8, runSpacing: 8, children: [
          _chip('${_totals['tests'] ?? 0} tests'),
          if ((_totals['questions'] ?? 0) != 0)
            _chip('${_totals['questions']} questions'),
          if ((_totals['minutes'] ?? 0) != 0) _chip('${_totals['minutes']} min'),
          if ((_totals['learners'] ?? 0) != 0)
            _chip('${_totals['learners']} taken'),
        ]),
      ]),
    );
  }

  Widget _chip(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: GoogleFonts.inter(
                fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.white)),
      );

  Widget _progress() {
    final me = _me!;
    final done = (me['tests_done'] as num?)?.toInt() ?? 0;
    final total = (me['tests_total'] as num?)?.toInt() ?? 0;
    final avg = (me['best_avg_pct'] as num?)?.toDouble() ?? 0;
    final nextId = me['next_test_id'];
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6EBF3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text('$done of $total done',
                style: GoogleFonts.poppins(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary)),
          ),
          if (done > 0)
            Text('${avg.toStringAsFixed(0)}% average',
                style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.success)),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: total == 0 ? 0 : done / total,
            minHeight: 6,
            backgroundColor: const Color(0xFFEDF1F7),
            valueColor: const AlwaysStoppedAnimation(AppColors.accent),
          ),
        ),
        if (nextId != null) ...[
          const SizedBox(height: 13),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => _openTest(nextId as int),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11)),
              ),
              child: Text(done == 0 ? 'Start the first test' : 'Continue',
                  style: GoogleFonts.poppins(
                      fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _shareBar() => Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: const Color(0xFF25D366).withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Row(children: [
          Expanded(
            child: Text('Send this series to your class group',
                style: GoogleFonts.inter(
                    fontSize: 12.5,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary)),
          ),
          const SizedBox(width: 10),
          FilledButton.icon(
            onPressed: _share,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.share_rounded, size: 16),
            label: Text('Share',
                style: GoogleFonts.poppins(
                    fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ]),
      );

  Widget _testTile(Map<String, dynamic> t, int index) {
    final mine = _me?['per_test']?['${t['id']}'] as Map?;
    final bestPct = (mine?['best_pct'] as num?)?.toDouble();
    final attempts = (mine?['attempts'] as num?)?.toInt() ?? 0;
    final bits = <String>[
      if ('${t['subject'] ?? ''}'.isNotEmpty) '${t['subject']}',
      if ((t['question_count'] ?? 0) != 0) '${t['question_count']} Q',
      if ((t['duration_mins'] ?? 0) != 0) '${t['duration_mins']} min',
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFE6EBF3)),
      ),
      child: InkWell(
        onTap: () => _openTest(t['id'] as int),
        borderRadius: BorderRadius.circular(13),
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Row(children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: attempts > 0
                    ? AppColors.success.withValues(alpha: 0.12)
                    : const Color(0xFFF1F4F9),
                shape: BoxShape.circle,
              ),
              child: attempts > 0
                  ? const Icon(Icons.check_rounded,
                      size: 16, color: AppColors.success)
                  : Text('${index + 1}',
                      style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF9AA5B5))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${t['title'] ?? 'Test'}',
                        style: GoogleFonts.poppins(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary)),
                    if (bits.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(bits.join(' · '),
                          style: GoogleFonts.inter(
                              fontSize: 11.5, color: const Color(0xFF9AA5B5))),
                    ],
                  ]),
            ),
            if (bestPct != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (bestPct >= 60 ? AppColors.success : AppColors.warning)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text('${bestPct.toStringAsFixed(0)}%',
                    style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: bestPct >= 60
                            ? AppColors.success
                            : AppColors.warning)),
              )
            else
              const Icon(Icons.chevron_right_rounded,
                  size: 20, color: Color(0xFFC3CCD9)),
          ]),
        ),
      ),
    );
  }

  /// Reload on the way back: a test taken in the pushed route changes the
  /// numbers on this one, and coming back to a stale page reads as a bug.
  Future<void> _openTest(int testId) async {
    await context.push('/test/$testId');
    if (mounted) _load();
  }

  static Color? _parseColour(dynamic raw) {
    final v = '${raw ?? ''}'.replaceAll('#', '');
    if (v.length != 6) return null;
    final n = int.tryParse(v, radix: 16);
    return n == null ? null : Color(0xFF000000 | n);
  }
}
