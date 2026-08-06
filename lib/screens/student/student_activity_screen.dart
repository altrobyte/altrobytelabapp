import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../constants/app_colors.dart';
import '../../services/api_service.dart';

/// "My Activity" — consolidated view of everything a student has done:
/// mock interviews, test series attempts, experiments, events joined,
/// and course (training module) completion. Each of these already has
/// its own tracking; this just brings them together in one place.
class StudentActivityScreen extends StatefulWidget {
  const StudentActivityScreen({super.key});

  @override
  State<StudentActivityScreen> createState() => _StudentActivityScreenState();
}

class _StudentActivityScreenState extends State<StudentActivityScreen> {
  Map<String, dynamic>? _data;
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
      final data = await ApiService.getStudentActivitySummary();
      if (!mounted) return;
      setState(() { _data = data; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text('My Activity', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
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
                      _buildStatsGrid(),
                      const SizedBox(height: 20),
                      _buildSection(
                        title: 'Mock Interviews',
                        icon: Icons.record_voice_over_rounded,
                        color: AppColors.accent,
                        emptyText: 'No mock interviews yet',
                        items: List<Map<String, dynamic>>.from(_data!['mock_interviews']['recent']),
                        itemBuilder: (i) => _ActivityTile(
                          title: i['role'] ?? '',
                          subtitle: i['status'] == 'completed'
                              ? 'Score: ${i['overall_score'] ?? 0}%'
                              : 'In progress',
                          date: i['created_at'],
                          color: AppColors.accent,
                        ),
                      ),
                      _buildSection(
                        title: 'Test Series',
                        icon: Icons.quiz_rounded,
                        color: AppColors.primary,
                        emptyText: 'No tests attempted yet',
                        items: List<Map<String, dynamic>>.from(_data!['test_series']['recent']),
                        itemBuilder: (t) => _ActivityTile(
                          title: t['title'] ?? '',
                          subtitle: 'Score: ${t['score']}/${t['total']}',
                          date: t['completed_at'],
                          color: AppColors.primary,
                        ),
                      ),
                      _buildSection(
                        title: 'AI Practice Tests',
                        icon: Icons.auto_awesome_rounded,
                        color: AppColors.accent,
                        emptyText: 'No practice tests taken yet',
                        items: List<Map<String, dynamic>>.from(
                            (_data!['practice'] as Map?)?['recent'] ?? const []),
                        itemBuilder: (p) => _ActivityTile(
                          // Generated tests have no title — the subject and
                          // topic they were built from identify them.
                          title: [p['subject'], p['topic']]
                              .where((v) => v != null && v.toString().trim().isNotEmpty)
                              .join(' — '),
                          subtitle: 'Score: ${p['score']}/${p['total']}',
                          date: p['completed_at'],
                          color: AppColors.accent,
                        ),
                      ),
                      _buildSection(
                        title: 'Experiments',
                        icon: Icons.science_rounded,
                        color: AppColors.accent,
                        emptyText: 'No experiments attempted yet',
                        items: List<Map<String, dynamic>>.from(_data!['experiments']['recent']),
                        itemBuilder: (e) => _ActivityTile(
                          title: e['title'] ?? '',
                          subtitle: e['verified'] == true ? 'Verified ✓' : 'Submitted',
                          date: e['created_at'],
                          color: AppColors.accent,
                        ),
                      ),
                      _buildSection(
                        title: 'Events Joined',
                        icon: Icons.event_rounded,
                        color: AppColors.primary,
                        emptyText: 'No events joined yet',
                        items: List<Map<String, dynamic>>.from(_data!['events']['recent']),
                        itemBuilder: (e) => _ActivityTile(
                          title: e['title'] ?? '',
                          subtitle: 'Registered',
                          date: e['registered_at'],
                          color: AppColors.primary,
                        ),
                      ),
                      _buildSection(
                        title: 'Workshops',
                        icon: Icons.video_camera_front_rounded,
                        color: AppColors.primary,
                        emptyText: 'No workshops registered yet',
                        items: List<Map<String, dynamic>>.from(
                            (_data!['live_sessions'] as Map?)?['recent'] ?? const []),
                        itemBuilder: (s) => _ActivityTile(
                          title: s['title'] ?? '',
                          subtitle: switch (s['status']) {
                            'paid' => 'Registered — paid',
                            'registered' => 'Registered — free',
                            _ => 'Payment pending',
                          },
                          date: s['registered_at'],
                          color: AppColors.primary,
                        ),
                      ),
                      _buildCoursesSection(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildStatsGrid() {
    final mi = _data!['mock_interviews'];
    final ts = _data!['test_series'];
    final exp = _data!['experiments'];
    final ev = _data!['events'];
    final courses = _data!['courses'];
    final sessions = (_data!['live_sessions'] as Map?) ?? const {};
    final stats = [
      ('Interviews', '${mi['completed']}', AppColors.accent),
      ('Tests Taken', '${ts['total_attempts']}', AppColors.primary),
      ('Workshops', '${sessions['confirmed'] ?? 0}', AppColors.primary),
      ('Experiments', '${exp['count']}', AppColors.accent),
      ('Events', '${ev['count']}', AppColors.primary),
      ('Courses Done', '${courses['completed']}', AppColors.success),
    ];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.3,
      children: stats.map((s) => Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.12))),
        padding: const EdgeInsets.all(12),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(s.$2, style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: s.$3)),
          const SizedBox(height: 4),
          Text(s.$1, textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
        ]),
      )).toList(),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Color color,
    required String emptyText,
    required List<Map<String, dynamic>> items,
    required Widget Function(Map<String, dynamic>) itemBuilder,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
        ]),
        const SizedBox(height: 10),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 26),
            child: Text(emptyText, style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textSecondary)),
          )
        else
          ...items.map(itemBuilder),
      ]),
    );
  }

  Widget _buildCoursesSection() {
    final courses = List<Map<String, dynamic>>.from(_data!['courses']['list']);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.school_rounded, color: AppColors.success, size: 18),
          const SizedBox(width: 8),
          Text('Course Progress', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
        ]),
        const SizedBox(height: 10),
        if (courses.isEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 26),
            child: Text('No courses started yet', style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textSecondary)),
          )
        else
          ...courses.map((c) {
            final total = c['total_items'] as int;
            final completed = c['completed_items'] as int;
            final pct = total == 0 ? 0.0 : completed / total;
            final enrollmentStatus = c['enrollment_status'] as String?;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(c['title'] ?? '', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13))),
                    if (enrollmentStatus != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: (enrollmentStatus == 'paid' ? AppColors.success : AppColors.warning).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(enrollmentStatus == 'paid' ? 'Enrolled' : 'Payment pending',
                            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700,
                                color: enrollmentStatus == 'paid' ? AppColors.success : AppColors.warning)),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text('$completed/$total', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                  ]),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(value: pct, minHeight: 6,
                        backgroundColor: Colors.grey.withValues(alpha: 0.15),
                        color: c['is_complete'] == true ? AppColors.success : AppColors.accent),
                  ),
                ]),
              ),
            );
          }),
      ]),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? date;
  final Color color;
  const _ActivityTile({required this.title, required this.subtitle, this.date, required this.color});

  @override
  Widget build(BuildContext context) {
    String? formattedDate;
    if (date != null) {
      try {
        formattedDate = DateFormat('d MMM').format(DateTime.parse(date!));
      } catch (_) {}
    }
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        dense: true,
        leading: Container(
          width: 8, height: 8,
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        title: Text(title, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500)),
        subtitle: Text(subtitle, style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.textSecondary)),
        trailing: formattedDate != null
            ? Text(formattedDate, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary))
            : null,
      ),
    );
  }
}
