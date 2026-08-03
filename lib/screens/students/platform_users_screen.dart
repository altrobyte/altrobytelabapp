import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../constants/app_colors.dart';
import '../../services/api_service.dart';

// Google sign-in accounts (no WhatsApp number) get a random placeholder
// phone (`g` + 12 hex chars) to satisfy the DB's NOT NULL/unique constraint;
// anonymous guests get "0000000000". Neither is a real number — never show
// them to the admin as if they were.
final _placeholderPhoneRe = RegExp(r'^g[0-9a-f]{12}$');
bool _isPlaceholderPhone(String phone) => _placeholderPhoneRe.hasMatch(phone) || phone == '0000000000';

String _displayPhone(dynamic rawPhone) {
  final phone = (rawPhone ?? '').toString();
  if (phone.isEmpty) return '-';
  return _isPlaceholderPhone(phone) ? 'Signed in via Google' : phone;
}

String _fmtDate(dynamic v) {
  if (v == null) return '';
  try {
    return DateFormat('d MMM yyyy').format(DateTime.parse(v.toString()));
  } catch (_) {
    return '';
  }
}

/// Admin roster of real platform users (student_users) — who registered,
/// their plan, and their activity across courses/interviews/experiments/
/// events/sessions/jobs. Distinct from the legacy institute-scoped
/// Students screen (batches/fees model), which doesn't apply here.
class PlatformUsersScreen extends StatefulWidget {
  const PlatformUsersScreen({super.key});

  @override
  State<PlatformUsersScreen> createState() => _PlatformUsersScreenState();
}

class _PlatformUsersScreenState extends State<PlatformUsersScreen> {
  List<dynamic> _users = [];
  bool _loading = true;
  String? _error;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final users = await ApiService.getPlatformUsers();
      if (!mounted) return;
      setState(() { _users = users; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  List<dynamic> get _filtered {
    if (_search.trim().isEmpty) return _users;
    final q = _search.trim().toLowerCase();
    return _users.where((u) {
      final name = (u['name'] ?? '').toString().toLowerCase();
      final email = (u['email'] ?? '').toString().toLowerCase();
      final phone = (u['phone'] ?? '').toString().toLowerCase();
      return name.contains(q) || email.contains(q) || phone.contains(q);
    }).toList();
  }

  Future<void> _showActivity(Map<String, dynamic> user) async {
    Map<String, dynamic>? activity;
    String? err;
    try {
      activity = await ApiService.getPlatformUserActivity(user['id'] as int);
    } catch (e) {
      err = e.toString();
    }
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        expand: false,
        builder: (ctx, scrollCtrl) => Padding(
          padding: const EdgeInsets.all(20),
          child: err != null
              ? Center(child: Text(err, style: GoogleFonts.inter(color: AppColors.error)))
              : _ActivityDetail(user: user, activity: activity!, scrollController: scrollCtrl),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text('Users', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded, color: Colors.white), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: GoogleFonts.inter(color: AppColors.textSecondary)))
              : Column(children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      onChanged: (v) => setState(() => _search = v),
                      decoration: InputDecoration(
                        hintText: 'Search by name, email or phone',
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  Expanded(
                    child: _filtered.isEmpty
                        ? Center(child: Text('No users found', style: GoogleFonts.inter(color: AppColors.textSecondary)))
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              final isWide = constraints.maxWidth >= 900;
                              return Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 1400),
                                  child: isWide ? _buildTable() : _buildList(),
                                ),
                              );
                            },
                          ),
                  ),
                ]),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: _filtered.length,
      itemBuilder: (context, i) => _UserCard(user: _filtered[i], onTap: () => _showActivity(_filtered[i])),
    );
  }

  Widget _buildTable() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Name')),
          DataColumn(label: Text('Contact')),
          DataColumn(label: Text('Plan')),
          DataColumn(label: Text('Joined')),
          DataColumn(label: Text('Courses')),
          DataColumn(label: Text('Interviews')),
          DataColumn(label: Text('Experiments')),
          DataColumn(label: Text('Events')),
          DataColumn(label: Text('Sessions')),
          DataColumn(label: Text('Jobs')),
          DataColumn(label: Text('')),
        ],
        rows: _filtered.map((u) {
          final isPremium = u['plan'] == 'premium';
          return DataRow(cells: [
            DataCell(Text(u['name'] ?? '', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13))),
            DataCell(Text('${_displayPhone(u['phone'])}\n${u['email'] ?? ''}', style: GoogleFonts.inter(fontSize: 11.5))),
            DataCell(Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: (isPremium ? AppColors.accent : Colors.grey).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6)),
              child: Text((u['plan'] ?? 'free').toString().toUpperCase(),
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700,
                      color: isPremium ? AppColors.accent : AppColors.textSecondary)),
            )),
            DataCell(Text(_fmtDate(u['created_at']), style: GoogleFonts.inter(fontSize: 11.5))),
            DataCell(Text('${u['courses_started'] ?? 0}')),
            DataCell(Text('${u['mock_interviews'] ?? 0}')),
            DataCell(Text('${u['experiments'] ?? 0}')),
            DataCell(Text('${u['events_registered'] ?? 0}')),
            DataCell(Text('${u['sessions_registered'] ?? 0}')),
            DataCell(Text('${u['jobs_applied'] ?? 0}')),
            DataCell(TextButton(onPressed: () => _showActivity(u), child: const Text('View'))),
          ]);
        }).toList(),
      ),
    );
  }

}

class _UserCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback onTap;
  const _UserCard({required this.user, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isPremium = user['plan'] == 'premium';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(user['name'] ?? '', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14.5))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: (isPremium ? AppColors.accent : Colors.grey).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6)),
                child: Text((user['plan'] ?? 'free').toString().toUpperCase(),
                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700,
                        color: isPremium ? AppColors.accent : AppColors.textSecondary)),
              ),
            ]),
            const SizedBox(height: 4),
            Text('${_displayPhone(user['phone'])}  •  ${user['email'] ?? ''}',
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 6, children: [
              _statChip(Icons.school_rounded, '${user['courses_started'] ?? 0} courses'),
              _statChip(Icons.record_voice_over_rounded, '${user['mock_interviews'] ?? 0} interviews'),
              _statChip(Icons.science_rounded, '${user['experiments'] ?? 0} experiments'),
              _statChip(Icons.event_rounded, '${user['events_registered'] ?? 0} events'),
              _statChip(Icons.video_camera_front_rounded, '${user['sessions_registered'] ?? 0} sessions'),
              _statChip(Icons.work_rounded, '${user['jobs_applied'] ?? 0} jobs'),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _statChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(text, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
      ]),
    );
  }
}

class _ActivityDetail extends StatelessWidget {
  final Map<String, dynamic> user;
  final Map<String, dynamic> activity;
  final ScrollController scrollController;
  const _ActivityDetail({required this.user, required this.activity, required this.scrollController});

  @override
  Widget build(BuildContext context) {
    final courses = (activity['courses'] as List?) ?? [];
    final interviews = (activity['mock_interviews'] as List?) ?? [];
    final events = (activity['events'] as List?) ?? [];
    final sessions = (activity['live_sessions'] as List?) ?? [];
    final jobs = (activity['jobs'] as List?) ?? [];
    final testAttempts = (activity['test_attempts'] as List?) ?? [];
    final practice = (activity['practice_attempts'] as List?) ?? [];

    return ListView(
      controller: scrollController,
      children: [
        Text(user['name'] ?? '', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 17)),
        Text('${_displayPhone(user['phone'])}  •  ${user['email'] ?? ''}',
            style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textSecondary)),
        const SizedBox(height: 16),
        _section('Courses', Icons.school_rounded, courses.isEmpty
            ? [_empty('No course progress yet')]
            : courses.map((c) {
                final total = (c['total_items'] ?? 0) as int;
                final done = (c['completed_items'] ?? 0) as int;
                final pct = total > 0 ? (done / total * 100).round() : 0;
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(c['title'] ?? ''),
                  subtitle: LinearProgressIndicator(value: total > 0 ? done / total : 0, minHeight: 6, borderRadius: BorderRadius.circular(3)),
                  trailing: Text('$pct%', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                );
              }).toList()),
        _section('Mock Interviews', Icons.record_voice_over_rounded, interviews.isEmpty
            ? [_empty('None yet')]
            : interviews.map((i) => ListTile(
                dense: true, contentPadding: EdgeInsets.zero,
                title: Text(i['role'] ?? ''),
                subtitle: Text('${i['status']} · score ${i['overall_score'] ?? '-'}'),
              )).toList()),
        _section('Tests Attempted', Icons.quiz_rounded, testAttempts.isEmpty
            ? [_empty('None yet')]
            : testAttempts.map((t) => ListTile(
                dense: true, contentPadding: EdgeInsets.zero,
                title: Text(t['title'] ?? ''),
                subtitle: Text(_fmtDate(t['completed_at'])),
                trailing: Text('${t['score'] ?? 0}/${t['total'] ?? 0}',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              )).toList()),
        _section('AI Practice Tests', Icons.auto_awesome_rounded, practice.isEmpty
            ? [_empty('None yet')]
            : practice.map((p) => ListTile(
                dense: true, contentPadding: EdgeInsets.zero,
                // Generated on the fly, so there is no test title — the
                // subject/topic it was built from is the only label.
                title: Text([p['subject'], p['topic']]
                    .where((v) => v != null && v.toString().trim().isNotEmpty)
                    .join(' — ')),
                subtitle: Text(_fmtDate(p['completed_at'])),
                trailing: Text('${p['score'] ?? 0}/${p['total'] ?? 0}',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              )).toList()),
        _section('Events', Icons.event_rounded, events.isEmpty
            ? [_empty('None yet')]
            : events.map((e) => ListTile(dense: true, contentPadding: EdgeInsets.zero, title: Text(e['title'] ?? ''))).toList()),
        _section('Live Sessions', Icons.video_camera_front_rounded, sessions.isEmpty
            ? [_empty('None yet')]
            : sessions.map((s) => ListTile(
                dense: true, contentPadding: EdgeInsets.zero,
                title: Text(s['title'] ?? ''), trailing: Text(s['status'] ?? ''),
              )).toList()),
        _section('Job Applications', Icons.work_rounded, jobs.isEmpty
            ? [_empty('None yet')]
            : jobs.map((j) => ListTile(
                dense: true, contentPadding: EdgeInsets.zero,
                title: Text(j['title'] ?? ''), trailing: Text(j['status'] ?? ''),
              )).toList()),
      ],
    );
  }

  Widget _section(String title, IconData icon, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 16, color: AppColors.accent),
          const SizedBox(width: 6),
          Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13.5)),
        ]),
        const Divider(),
        ...children,
      ]),
    );
  }

  Widget _empty(String text) => Text(text, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary));
}
