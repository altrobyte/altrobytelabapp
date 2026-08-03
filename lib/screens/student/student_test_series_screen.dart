import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants/app_colors.dart';
import '../../services/api_service.dart';

/// Unified Practice & Test Series tab — a "Generate custom practice test"
/// CTA up top, plus a listing of curated Test Series and quizzes authored
/// inside Training Modules ("Course Quizzes"). Previously two separate
/// screens; merged per product decision so students have one place to find
/// every quiz, whether AI-generated on demand, admin-curated, or embedded
/// in a course.
class StudentTestSeriesScreen extends StatefulWidget {
  const StudentTestSeriesScreen({super.key});

  @override
  State<StudentTestSeriesScreen> createState() => _StudentTestSeriesScreenState();
}

class _StudentTestSeriesScreenState extends State<StudentTestSeriesScreen> {
  List<dynamic> _series = [];
  List<dynamic> _moduleTests = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final prefs = await SharedPreferences.getInstance();
      final instituteId = prefs.getInt('student_institute_id');
      if (instituteId == null) {
        setState(() { _series = []; _moduleTests = []; _loading = false; });
        return;
      }
      final data = await ApiService.getTestSeriesStudent(instituteId);
      if (!mounted) return;
      setState(() {
        _series = data['series'] as List? ?? [];
        _moduleTests = data['module_tests'] as List? ?? [];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Color _parseColor(String? hex) {
    try {
      return Color(int.parse((hex ?? '').replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text('Practice & Test Series',
            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(_error!, style: GoogleFonts.inter(color: AppColors.textSecondary)),
                    const SizedBox(height: 12),
                    ElevatedButton(onPressed: _load, child: const Text('Retry')),
                  ]),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      const _PracticeCta(),
                      const SizedBox(height: 24),
                      if (_moduleTests.isNotEmpty) ...[
                        _SectionLabel('Course Quizzes'),
                        const SizedBox(height: 10),
                        ..._moduleTests.map((m) => _ModuleTestsCard(
                              moduleTitle: m['module_title'] ?? '',
                              color: _parseColor(m['module_color']),
                              tests: (m['tests'] as List?) ?? [],
                            )),
                        const SizedBox(height: 14),
                      ],
                      if (_series.isNotEmpty) ...[
                        _SectionLabel('Test Series'),
                        const SizedBox(height: 10),
                        ..._series.map((s) => _SeriesCard(
                              series: s,
                              color: _parseColor(s['color']),
                            )),
                      ],
                      if (_series.isEmpty && _moduleTests.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Center(
                            child: Column(children: [
                              Icon(Icons.quiz_outlined, size: 40, color: Colors.grey[300]),
                              const SizedBox(height: 10),
                              Text('No test series or course quizzes published yet',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(color: AppColors.textSecondary)),
                            ]),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}

/// Beta gate: custom AI-generated practice tests are intentionally disabled
/// on this tab for now — students see only admin Test Series and Course
/// Quizzes here until this graduates out of beta.
class _PracticeCta extends StatelessWidget {
  const _PracticeCta();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(24)),
          child: Icon(Icons.bolt_rounded, color: Colors.grey.shade500, size: 26),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Generate a Custom Practice Test',
                style: GoogleFonts.poppins(color: Colors.grey.shade600, fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 2),
            Text('Coming soon — pick a topic and AI builds it instantly',
                style: GoogleFonts.inter(color: Colors.grey.shade500, fontSize: 12)),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(20)),
          child: Text('SOON',
              style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.grey.shade700, letterSpacing: 0.4)),
        ),
      ]),
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

class _ModuleTestsCard extends StatefulWidget {
  final String moduleTitle;
  final Color color;
  final List<dynamic> tests;
  const _ModuleTestsCard({required this.moduleTitle, required this.color, required this.tests});

  @override
  State<_ModuleTestsCard> createState() => _ModuleTestsCardState();
}

class _ModuleTestsCardState extends State<_ModuleTestsCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
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
                decoration: BoxDecoration(color: widget.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.school_rounded, color: widget.color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.moduleTitle, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14.5)),
                  const SizedBox(height: 4),
                  Text('${widget.tests.length} quiz${widget.tests.length == 1 ? '' : 'zes'}',
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
          ...widget.tests.map((t) => ListTile(
                dense: true,
                leading: Icon(Icons.description_outlined, color: widget.color, size: 20),
                title: Text(t['title'] ?? '', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500)),
                subtitle: Text('${t['subject'] ?? ''} · ${t['duration_mins'] ?? 0} min',
                    style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.textSecondary)),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                onTap: () => context.push('/test/${t['id']}'),
              )),
          const SizedBox(height: 8),
        ],
      ]),
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
          const SizedBox(height: 8),
        ],
      ]),
    );
  }
}
