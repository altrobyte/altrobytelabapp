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

const _teal = Color(0xFF00BFA5);

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
  String _email = '';
  String _instituteCode = '';
  int? _studentId;
  // ignore: unused_field
  int? _instituteId;
  bool _isStandalone = false;
  Map<String, dynamic>? _stats;
  List<dynamic> _fees = [];
  List<dynamic> _results = [];
  bool _loading = true;
  bool _loadingFees = false;
  bool _loadingResults = false;

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
          _email = (data['email'] ?? '').toString();
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

  Future<void> _loadFees() async {
    if (_studentId == null || _studentId! <= 0) return;
    setState(() => _loadingFees = true);
    try {
      _fees = await ApiService.getStudentFees(_studentId!);
    } catch (_) {}
    if (mounted) setState(() => _loadingFees = false);
  }

  Future<void> _loadResults() async {
    if (_studentId == null || _studentId! <= 0) return;
    setState(() => _loadingResults = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('student_token');
      if (token != null) {
        final res = await http.get(
          Uri.parse(ApiConstants.studentFeed()),
          headers: {'Authorization': 'Bearer $token'},
        );
        if (res.statusCode == 200) {
          final body = jsonDecode(res.body) as Map<String, dynamic>;
          _results = body['recent_results'] as List? ?? [];
        }
      }
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
        ? 'https://coachingclub-bba5c.web.app/${_instituteCode.toLowerCase()}'
        : 'https://coachingclub-bba5c.web.app';
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
            style: FilledButton.styleFrom(backgroundColor: _teal),
            onPressed: () async {
              final newName = ctrl.text.trim();
              if (newName.isEmpty) return;
              Navigator.pop(context);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('student_name', newName);
              if (!mounted) return;
              setState(() => _name = newName);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Name updated!'), backgroundColor: _teal),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showFees() {
    _loadFees();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModalState) {
          // Listen for fee loading state changes
          if (_loadingFees) {
            _loadFees().then((_) {
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
                    const Icon(Icons.receipt_long_rounded, color: _teal, size: 22),
                    const SizedBox(width: 8),
                    Text('My Fees', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                  ]),
                ),
                Expanded(
                  child: _loadingFees
                      ? const Center(child: CircularProgressIndicator(color: _teal))
                      : _fees.isEmpty
                          ? Center(child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle_rounded, size: 48, color: Colors.green.shade300),
                                const SizedBox(height: 8),
                                Text('No pending fees!', style: GoogleFonts.inter(color: AppColors.textSecondary)),
                              ],
                            ))
                          : ListView.builder(
                              controller: scrollCtrl,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _fees.length,
                              itemBuilder: (_, i) {
                                final fee = _fees[i] as Map<String, dynamic>;
                                final status = (fee['status'] ?? 'pending').toString();
                                final isPaid = status == 'paid';
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: isPaid
                                          ? Colors.green.withValues(alpha: 0.1)
                                          : Colors.orange.withValues(alpha: 0.1),
                                      child: Icon(
                                        isPaid ? Icons.check_circle : Icons.pending_rounded,
                                        color: isPaid ? Colors.green : Colors.orange,
                                      ),
                                    ),
                                    title: Text('₹${fee['amount'] ?? 0}',
                                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                                    subtitle: Text(
                                      'Due: ${fee['due_date'] ?? '-'} • ${status.toUpperCase()}',
                                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                                    ),
                                    trailing: isPaid
                                        ? const Text('✅', style: TextStyle(fontSize: 18))
                                        : const Text('⏳', style: TextStyle(fontSize: 18)),
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
                    const Icon(Icons.emoji_events_rounded, color: Color(0xFFFFA000), size: 22),
                    const SizedBox(width: 8),
                    Text('My Test Results', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                  ]),
                ),
                Expanded(
                  child: _loadingResults
                      ? const Center(child: CircularProgressIndicator(color: _teal))
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

  void _showAttendance() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.event_available_rounded, size: 48, color: _teal),
          const SizedBox(height: 12),
          Text('Attendance', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _teal.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _AttendStat('Rate', '${_stats?['attendance_rate'] ?? 0}%', _teal),
              Container(width: 1, height: 40, color: Colors.grey.shade300),
              _AttendStat('Present', '${_stats?['total_present'] ?? '-'}', Colors.green),
              Container(width: 1, height: 40, color: Colors.grey.shade300),
              _AttendStat('Absent', '${_stats?['total_absent'] ?? '-'}', AppColors.error),
            ]),
          ),
          const SizedBox(height: 16),
          Text('Use QR Check-in to mark your daily attendance',
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  void _showAboutInstitute() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.school_rounded, color: AppColors.primary, size: 26),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_institute, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
              if (_batchName.isNotEmpty)
                Text('Batch: $_batchName', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
            ])),
          ]),
          const SizedBox(height: 16),
          if (_instituteCode.isNotEmpty)
            _InfoRow(Icons.vpn_key_rounded, 'Institute Code', _instituteCode),
          _InfoRow(Icons.phone_rounded, 'Your Phone', _phone.isNotEmpty ? '+91 $_phone' : '-'),
          if (_email.isNotEmpty)
            _InfoRow(Icons.email_rounded, 'Email', _email),
          const SizedBox(height: 16),
        ]),
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
            content: Text('Coaching linked successfully!'), backgroundColor: _teal));
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

    final avg = (_stats?['avg_test_score'] ?? 0).toString();
    final attend = (_stats?['attendance_rate'] ?? 0).toString();
    final tests = (_stats?['total_tests_taken'] ?? 0).toString();

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
          ? const Center(child: CircularProgressIndicator(color: _teal))
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
                        color: _teal.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                        border: Border.all(color: _teal.withValues(alpha: 0.5), width: 2),
                      ),
                      child: Center(child: Text(initials,
                          style: GoogleFonts.poppins(
                              color: _teal, fontSize: 32, fontWeight: FontWeight.bold))),
                    ),
                    const SizedBox(height: 14),
                    Text(_name,
                        style: GoogleFonts.poppins(
                            fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                    if (_phone.isNotEmpty)
                      Text('+91 $_phone',
                          style: GoogleFonts.inter(color: Colors.white60, fontSize: 13)),
                    if (_institute.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                        decoration: BoxDecoration(
                          color: _teal.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(_institute,
                            style: GoogleFonts.inter(
                                fontSize: 12, color: _teal, fontWeight: FontWeight.w600)),
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
                Row(children: [
                  _stat('Avg Score', '$avg%', AppColors.accent),
                  const SizedBox(width: 10),
                  _stat('Attendance', '$attend%', AppColors.success),
                  const SizedBox(width: 10),
                  _stat('Tests', tests, AppColors.primary),
                ]),
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
                    _actionTile(Icons.receipt_long_rounded, 'My Fees', 'View fee status & history', const Color(0xFF7C4DFF), _showFees),
                    _divider(),
                    _actionTile(Icons.emoji_events_rounded, 'My Test Results', 'View scores & performance', const Color(0xFFFFA000), _showResults),
                    _divider(),
                    _actionTile(Icons.event_available_rounded, 'My Attendance', 'View attendance summary', _teal, _showAttendance),
                    _divider(),
                    _actionTile(Icons.school_rounded, 'About Institute', 'Institute details & info', AppColors.primary, _showAboutInstitute),
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
                        const Color(0xFFFF5722), () => _launch('app-settings:')),
                    _divider(),
                    // Share
                    _settingsTile(Icons.share_rounded, 'Share App', 'Invite friends to join',
                        const Color(0xFF2196F3), _shareApp),
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
                          _teal,
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

class _AttendStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _AttendStat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Column(children: [
    Text(value, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
    Text(label, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
  ]);
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _InfoRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(children: [
      Icon(icon, size: 18, color: AppColors.textSecondary),
      const SizedBox(width: 10),
      Text(label, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
      const Spacer(),
      Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500)),
    ]),
  );
}
