import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../constants/app_colors.dart';
import '../../constants/api_constants.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/language_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/link_coaching_sheet.dart';

const _brand = AppColors.primary;

class StudentProfileScreen extends StatefulWidget {
  final String? waNumber;
  const StudentProfileScreen({super.key, this.waNumber});

  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen> {
  String _name = 'Student';
  String _phone = '';
  String _institute = '';
  String _batchName = '';
  String _instituteCode = '';
  int? _studentId;
  // ignore: unused_field
  int? _instituteId;
  bool _isStandalone = false;
  Map<String, dynamic>? _stats;
  List<dynamic> _results = [];
  bool _loading = true;
  bool _loadingResults = false;

  // Accounts created via Google sign-in (no WhatsApp number) get a random
  // server-side placeholder phone (`g` + 12 hex chars) to satisfy the DB's
  // NOT NULL/unique constraint — never a real number, so never show it as one.
  static final _placeholderPhoneRe = RegExp(r'^g[0-9a-f]{12}$');
  bool get _hasRealPhone => _phone.isNotEmpty && !_placeholderPhoneRe.hasMatch(_phone);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _name = prefs.getString('student_name') ?? 'Student';
    _phone = prefs.getString('student_phone') ?? '';
    _institute = prefs.getString('student_institute_name') ?? '';
    _studentId = prefs.getInt('student_id');
    _instituteId = prefs.getInt('student_institute_id');
    final token = prefs.getString('student_token');

    // Load detailed profile from /student/me
    if (token != null) {
      try {
        final res = await http.get(
          Uri.parse(ApiConstants.studentMe()),
          headers: {'Authorization': 'Bearer $token'},
        );
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          _name = (data['name'] ?? _name).toString();
          _phone = (data['phone'] ?? _phone).toString();
          _batchName = (data['batch_name'] ?? '').toString();
          _institute = (data['institute_name'] ?? _institute).toString();
          _instituteCode = (data['institute_code'] ?? '').toString();
          _isStandalone = data['is_standalone'] == true;
        }
      } catch (_) {}
    }

    // Load analytics
    if (_studentId != null && _studentId! > 0) {
      try {
        _stats = await ApiService.getStudentAnalytics(_studentId!);
      } catch (_) {}
    }

    if (mounted) setState(() => _loading = false);
  }

  /// Results come from /student/activity-summary, not the institute feed.
  /// Students who signed up with Google have no institute `students` row —
  /// their `student_id` is NULL, which the app stores as 0 — so gating this
  /// on a positive student_id meant they never even asked for their results
  /// and always saw the empty state. activity-summary is keyed on the
  /// student_user and falls back to phone, so it covers both kinds of account.
  Future<void> _loadResults() async {
    setState(() => _loadingResults = true);
    try {
      final summary = await ApiService.getStudentActivitySummary();
      final tests = (summary['test_series'] as Map?)?['recent'] as List? ?? [];
      final practice = (summary['practice'] as Map?)?['recent'] as List? ?? [];

      Map<String, dynamic> row(Map m, String title) {
        final total = (m['total'] as num?)?.toDouble() ?? 0;
        final score = (m['score'] as num?)?.toDouble() ?? 0;
        return {
          'title': title,
          'score': m['score'] ?? 0,
          'total': m['total'] ?? 0,
          'pct': total > 0 ? score / total * 100 : 0,
          'at': m['completed_at']?.toString() ?? '',
        };
      }

      _results = [
        for (final t in tests) row(t as Map, (t['title'] ?? 'Test').toString()),
        // Practice tests are generated on the fly and have no title of their
        // own — the subject/topic they came from is what identifies them.
        for (final p in practice)
          row(p as Map, [p['subject'], p['topic']]
              .where((v) => v != null && v.toString().trim().isNotEmpty)
              .join(' — ')),
      ]..sort((a, b) => (b['at'] as String).compareTo(a['at'] as String));
    } catch (_) {}
    if (mounted) setState(() => _loadingResults = false);
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('student_token');
    if (token != null) {
      try {
        await http.post(Uri.parse(ApiConstants.studentLogout()),
            headers: {'Authorization': 'Bearer $token'});
      } catch (_) {}
    }
    for (final k in [
      'student_token', 'student_user_id', 'student_id',
      'student_institute_id', 'student_name', 'student_phone',
      'student_institute_name',
    ]) {
      await prefs.remove(k);
    }
    if (!mounted) return;
    // Unwind back past this (imperatively-pushed) Profile screen first —
    // go('/') alone can leave a stale StudentHomeScreen mounted underneath
    // with its old in-memory logged-in state, since it was never actually
    // popped/rebuilt by go_router in that case.
    Navigator.of(context).popUntil((route) => route.isFirst);
    if (mounted) context.go('/');
  }

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _confirmLogout() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          const Icon(Icons.logout_rounded, color: AppColors.error, size: 22),
          const SizedBox(width: 8),
          Text(l10n.settingsLogout),
        ]),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.commonCancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              Navigator.pop(context);
              _logout();
            },
            child: Text(l10n.settingsLogout),
          ),
        ],
      ),
    );
  }

  void _shareApp() {
    final link = _instituteCode.isNotEmpty
        ? 'https://lab.altrobyte.com/${_instituteCode.toLowerCase()}'
        : 'https://lab.altrobyte.com';
    Share.share('$_institute\nJoin us on AltrobyteLab: $link');
  }

  void _showEditName() {
    final ctrl = TextEditingController(text: _name);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Edit Name', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Your Name',
            prefixIcon: Icon(Icons.person_rounded),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _brand),
            onPressed: () async {
              final newName = ctrl.text.trim();
              if (newName.isEmpty) return;
              Navigator.pop(context);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('student_name', newName);
              if (!mounted) return;
              setState(() => _name = newName);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Name updated!'), backgroundColor: AppColors.success),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showResults() {
    _loadResults();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModalState) {
          if (_loadingResults) {
            _loadResults().then((_) {
              if (ctx.mounted) setModalState(() {});
            });
          }
          return DraggableScrollableSheet(
            initialChildSize: 0.6,
            maxChildSize: 0.9,
            minChildSize: 0.3,
            expand: false,
            builder: (_, scrollCtrl) => Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    const Icon(Icons.emoji_events_rounded, color: AppColors.accent, size: 22),
                    const SizedBox(width: 8),
                    Text('My Test Results', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                  ]),
                ),
                Expanded(
                  child: _loadingResults
                      ? const Center(child: CircularProgressIndicator(color: _brand))
                      : _results.isEmpty
                          ? Center(child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.quiz_rounded, size: 48, color: Colors.grey.shade300),
                                const SizedBox(height: 8),
                                Text('No test results yet', style: GoogleFonts.inter(color: AppColors.textSecondary)),
                              ],
                            ))
                          : ListView.builder(
                              controller: scrollCtrl,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _results.length,
                              itemBuilder: (_, i) {
                                final r = _results[i] as Map<String, dynamic>;
                                final pct = (r['pct'] ?? 0).toDouble();
                                final color = pct >= 70 ? Colors.green : pct >= 40 ? Colors.orange : AppColors.error;
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: color.withValues(alpha: 0.1),
                                      child: Text('${pct.toStringAsFixed(0)}%',
                                          style: GoogleFonts.poppins(
                                              fontSize: 11, fontWeight: FontWeight.bold, color: color)),
                                    ),
                                    title: Text(r['title'] ?? 'Test',
                                        style: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 13)),
                                    subtitle: Text('${r['score'] ?? 0} / ${r['total'] ?? 0} correct',
                                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showLinkCoaching() {
    showLinkCoachingSheet(
      context,
      phone: _phone,
      onLinked: () {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Coaching linked successfully!'), backgroundColor: AppColors.success));
        setState(() => _isStandalone = false);
        _load();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final lang = context.watch<LanguageProvider>();
    final initials = _name.trim().isNotEmpty ? _name.trim()[0].toUpperCase() : 'S';

    final testsTakenNum = (_stats?['total_tests_taken'] as num?)?.toInt() ?? 0;
    final attendanceNum = (_stats?['attendance_rate'] as num?)?.toInt() ?? 0;
    final hasActivity = testsTakenNum > 0 || attendanceNum > 0;
    final avg = (_stats?['avg_test_score'] ?? 0).toString();
    final attend = attendanceNum.toString();
    final tests = testsTakenNum.toString();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.sidebar,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text('Profile',
            style: GoogleFonts.poppins(
                color: Colors.white, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded, size: 20),
            tooltip: 'Edit Name',
            onPressed: _showEditName,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _brand))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Profile header ──
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.sidebar, AppColors.sidebar.withValues(alpha: 0.85)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.sidebar.withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(children: [
                    Container(
                      width: 76, height: 76,
                      decoration: BoxDecoration(
                        color: _brand.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                        border: Border.all(color: _brand.withValues(alpha: 0.5), width: 2),
                      ),
                      child: Center(child: Text(initials,
                          style: GoogleFonts.poppins(
                              color: _brand, fontSize: 32, fontWeight: FontWeight.bold))),
                    ),
                    const SizedBox(height: 14),
                    Text(_name,
                        style: GoogleFonts.poppins(
                            fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                    if (_hasRealPhone)
                      Text('+91 $_phone',
                          style: GoogleFonts.inter(color: Colors.white60, fontSize: 13)),
                    if (_institute.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                        decoration: BoxDecoration(
                          color: _brand.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(_institute,
                            style: GoogleFonts.inter(
                                fontSize: 12, color: _brand, fontWeight: FontWeight.w600)),
                      ),
                    ],
                    if (_batchName.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('Batch: $_batchName',
                          style: GoogleFonts.inter(color: Colors.white38, fontSize: 11)),
                    ],
                  ]),
                ),
                const SizedBox(height: 16),

                // ── Stats ──
                if (hasActivity)
                  Row(children: [
                    _stat('Avg Score', '$avg%', AppColors.accent),
                    const SizedBox(width: 10),
                    _stat('Attendance', '$attend%', AppColors.success),
                    const SizedBox(width: 10),
                    _stat('Tests', tests, AppColors.primary),
                  ])
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
                    ),
                    child: Row(children: [
                      Expanded(
                        child: Text('Take your first test to see your stats here',
                            style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text('Custom Test', style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w600)),
                      ),
                    ]),
                  ),
                const SizedBox(height: 20),

                // ── Quick Actions ──
                _sectionTitle('Quick Actions'),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: Column(children: [
                    if (_isStandalone) ...[
                      _actionTile(Icons.link_rounded, 'Link to Coaching',
                          'Connect your account to an institute', AppColors.primary, _showLinkCoaching),
                      _divider(),
                    ],
                    // Test Results only. Fees, Attendance and About Institute
                    // are institute-admin concepts inherited from AltroCoach
                    // and mean nothing to a Lab student; My Activity is
                    // already reachable from the side rail.
                    _actionTile(Icons.emoji_events_rounded, 'My Test Results', 'View scores & performance', AppColors.accent, _showResults),
                  ]),
                ),
                const SizedBox(height: 20),

                // ── Settings ──
                _sectionTitle(l10n.settingsTitle),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: Column(children: [
                    // Language
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Row(children: [
                        const Icon(Icons.language_rounded, color: AppColors.primary, size: 20),
                        const SizedBox(width: 10),
                        Text(l10n.settingsLanguage,
                            style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                      ]),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Row(children: [
                        _langBtn(l10n.settingsLangEnglish, !lang.isHindi,
                            () => lang.setLocale(const Locale('en'))),
                        const SizedBox(width: 12),
                        _langBtn(l10n.settingsLangHindi, lang.isHindi,
                            () => lang.setLocale(const Locale('hi'))),
                      ]),
                    ),
                    _divider(),
                    // Notifications
                    _settingsTile(Icons.notifications_rounded, 'Notifications', 'Push notification preferences',
                        AppColors.primary, () => _launch('app-settings:')),
                    _divider(),
                    // Share
                    _settingsTile(Icons.share_rounded, 'Share App', 'Invite friends to join',
                        AppColors.accent, _shareApp),
                  ]),
                ),
                const SizedBox(height: 20),

                // ── Help & About ──
                _sectionTitle(l10n.settingsHelp),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: Column(children: [
                    if ((widget.waNumber ?? '').isNotEmpty)
                      _settingsTile(Icons.smart_toy_rounded, 'Chat with AI Tutor', 'Get instant help on WhatsApp',
                          _brand,
                          () => _launch(
                              'https://wa.me/${widget.waNumber!.replaceAll(RegExp(r'\D'), '')}')),
                    if ((widget.waNumber ?? '').isNotEmpty) _divider(),
                    _settingsTile(Icons.support_agent_rounded, l10n.settingsContactSupport,
                        'support@altrobyte.com', AppColors.textSecondary,
                        () => _launch('mailto:support@altrobyte.com')),
                    _divider(),
                    _settingsTile(Icons.privacy_tip_rounded, l10n.settingsPrivacyPolicy,
                        'Read our privacy policy', AppColors.textSecondary,
                        () => _launch('https://coachingclub-bba5c.web.app/privacy.html')),
                    _divider(),
                    _settingsTile(Icons.delete_outline_rounded, 'Delete Account',
                        'Request account deletion', AppColors.error,
                        () => _launch('https://coachingclub-bba5c.web.app/delete-account.html')),
                    _divider(),
                    ListTile(
                      leading: const Icon(Icons.info_outline_rounded, color: AppColors.textSecondary, size: 20),
                      title: Text(l10n.settingsAppVersion, style: GoogleFonts.inter(fontSize: 14)),
                      trailing: Text('v1.0.0', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                    ),
                  ]),
                ),
                const SizedBox(height: 20),

                // ── Logout ──
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    leading: const Icon(Icons.logout_rounded, color: AppColors.error),
                    title: Text(l10n.settingsLogout,
                        style: GoogleFonts.inter(
                            color: AppColors.error, fontWeight: FontWeight.w600)),
                    onTap: _confirmLogout,
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: Text('Powered by AltrobyteLab',
                      style: GoogleFonts.inter(
                          color: AppColors.textSecondary, fontSize: 11)),
                ),
                const SizedBox(height: 16),
              ],
            ),
    );
  }

  Widget _stat(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(children: [
          Text(value,
              style: GoogleFonts.poppins(
                  fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 11, color: AppColors.textSecondary)),
        ]),
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 10, left: 4),
        child: Text(t,
            style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      );

  Widget _divider() => Divider(height: 1, indent: 56, endIndent: 16, color: Colors.grey.shade100);

  Widget _actionTile(IconData icon, String title, String subtitle, Color color, VoidCallback onTap) {
    return ListTile(
      leading: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
      onTap: onTap,
    );
  }

  Widget _settingsTile(IconData icon, String title, String subtitle, Color color, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: color, size: 20),
      title: Text(title, style: GoogleFonts.inter(fontSize: 14)),
      subtitle: Text(subtitle, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary, size: 18),
      onTap: onTap,
    );
  }

  Widget _langBtn(String label, bool active, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? AppColors.primary : AppColors.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: active ? AppColors.primary : Colors.grey.shade300),
          ),
          child: Center(
            child: Text(label,
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: active ? Colors.white : AppColors.textPrimary)),
          ),
        ),
      ),
    );
  }
}


