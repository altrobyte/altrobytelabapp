import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../constants/app_colors.dart';
import '../../constants/api_constants.dart';
import '../../l10n/app_localizations.dart';
import '../../models/training_module_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/training_module_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/upgrade_sheet.dart';
import '../tools/http_tester_screen.dart';
import '../tools/mqtt_tester_screen.dart';
import '../tools/websocket_tester_screen.dart';
import 'qr_scan_screen.dart';
import 'student_module_detail_screen.dart';
import 'student_practice_screen.dart';
import 'student_profile_screen.dart';
import 'student_training_screen.dart';

const _practiceSubjects = [
  ('Embedded C', Icons.memory_rounded, Color(0xFF7C4DFF)),
  ('Electronics Fundamentals', Icons.bolt_rounded, Color(0xFF1565C0)),
  ('ESP32 / Microcontrollers', Icons.developer_board_rounded, Color(0xFF00BFA5)),
  ('IoT Protocols', Icons.wifi_rounded, Color(0xFFFF6B35)),
  ('Circuit Design & PCB', Icons.electrical_services_rounded, Color(0xFFE53935)),
  ('Sensors', Icons.sensors_rounded, Color(0xFF43A047)),
  ('AI/ML for Embedded', Icons.psychology_rounded, Color(0xFF6D4C41)),
  ('FreeRTOS / RTOS', Icons.schedule_rounded, Color(0xFF00838F)),
];

class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  String? _token;
  String _studentName = '';
  String _instituteName = '';
  String? _waNumber;

  List<Map<String, dynamic>> _tests = [];
  List<Map<String, dynamic>> _notices = [];
  List<Map<String, dynamic>> _results = [];
  Map<String, dynamic>? _subscription;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFeed();
  }

  bool get _isLoggedIn => _token != null;

  int _logoTaps = 0;
  // TEMPORARY pre-launch shortcut: 5 taps = admin, 10 taps = super admin,
  // both skip login entirely via the debug auto-login endpoints. Remove
  // this and restore the normal /login and /super/login flows before
  // real launch.
  Future<void> _onLogoTap() async {
    _logoTaps++;
    if (_logoTaps == 5) {
      final auth = context.read<AuthProvider>();
      try {
        final data = await ApiService.debugAutoLoginAdmin();
        await auth.setFromResponse(data);
        if (mounted) context.go('/dashboard');
      } catch (_) {}
    } else if (_logoTaps >= 10) {
      _logoTaps = 0;
      final auth = context.read<AuthProvider>();
      try {
        final data = await ApiService.debugAutoLoginSuperAdmin();
        await auth.setFromResponse(data);
        if (mounted) context.go('/super/dashboard');
      } catch (_) {}
    }
  }

  // TEMPORARY: login/OTP disabled entirely pre-launch. The backend treats
  // a missing token as a shared anonymous guest, so the feed just loads
  // with no token, no account, no Login/Logout UI anywhere. Restore real
  // per-student login before launch.
  Future<void> _loadFeed() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('student_token');

    setState(() {
      _token = token;
      _studentName = prefs.getString('student_name') ?? 'Student';
      _instituteName = prefs.getString('student_institute_name') ?? '';
    });

    try {
      final res = await http.get(
        Uri.parse(ApiConstants.studentFeed()),
        headers: token != null ? {'Authorization': 'Bearer $token'} : {},
      );
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      setState(() {
        _tests = List<Map<String, dynamic>>.from(body['tests'] ?? []);
        _notices = List<Map<String, dynamic>>.from(body['notices'] ?? []);
        _results = List<Map<String, dynamic>>.from(body['recent_results'] ?? []);
        _waNumber = body['wa_ai_number'] as String?;
        _subscription = body['subscription'] as Map<String, dynamic>?;
        _loading = false;
      });

      final instituteId = prefs.getInt('student_institute_id');
      if (instituteId != null && instituteId != 0 && mounted) {
        context.read<TrainingModuleProvider>().ensureModulesAsStudent(instituteId);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = AppLocalizations.of(context)!.studentPortalErrorLoad;
          _loading = false;
        });
      }
    }
  }

  Future<void> _openPractice({String? subject}) async {
    // TEMPORARY: login gate disabled while WhatsApp OTP delivery is broken.
    // Re-enable this check once OTP is confirmed working.
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
          builder: (_) => StudentPracticeScreen(initialSubject: subject)),
    );
    if (!mounted) return;
    _loadFeed(); // refresh quota banner
    if (result == 'upgrade') _showUpgradeSheet();
  }

  void _promptLogin({required String title, required String message}) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.lock_rounded, color: AppColors.accent, size: 24),
          ),
          const SizedBox(height: 16),
          Text(title, style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(message, style: GoogleFonts.inter(fontSize: 13.5, color: AppColors.textSecondary, height: 1.5)),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                context.push('/join');
              },
              child: Text('Continue with WhatsApp',
                  style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Maybe later', style: GoogleFonts.inter(color: AppColors.textSecondary)),
            ),
          ),
        ]),
      ),
    );
  }

  void _openTrainingScreen() {
    // TEMPORARY: login gate disabled while WhatsApp OTP delivery is broken.
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const StudentTrainingScreen()),
    );
  }

  void _openModule(TrainingModule module) async {
    final provider = context.read<TrainingModuleProvider>();
    final completedIds =
        provider.getProgress(module.id)?.completedItemIds ?? <int>{};
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StudentModuleDetailScreen(
          module: module,
          completedIds: completedIds,
        ),
      ),
    );
    if (mounted) provider.loadProgress(module.id);
  }

  void _showUpgradeSheet() {
    final lastResult = _results.isNotEmpty ? _results.first : null;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => UpgradeSheet(
        lastResult: lastResult,
        onPaymentOpened: _startSubscriptionVerification,
        premiumPrice: (_subscription?['premium_price'] as num?)?.toInt() ?? 99,
      ),
    );
  }

  // Polls backend every 5 seconds for up to 3 minutes after payment link opened.
  void _startSubscriptionVerification() {
    int attempts = 0;
    const maxAttempts = 36; // 36 × 5s = 3 min
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 5));
      if (!mounted) return false;
      attempts++;
      try {
        final res = await ApiService.verifyStudentSubscription();
        if (res['status'] == 'paid') {
          if (mounted) {
            setState(() {
              _subscription = {
                ..._subscription ?? {},
                'is_premium': true,
                'plan': 'premium',
                'remaining_today': -1,
              };
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Premium activated! Unlimited quizzes unlocked.'),
                backgroundColor: Color(0xFF00897B),
                duration: Duration(seconds: 4),
              ),
            );
          }
          return false;
        }
      } catch (_) {}
      return attempts < maxAttempts && mounted;
    });
  }

  Future<void> _openAiChat() async {
    if (_waNumber == null || _waNumber!.isEmpty) return;
    final phone = _waNumber!.replaceAll(RegExp(r'\D'), '');
    final uri = Uri.parse('https://wa.me/$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  int get _testsTaken => _results.length;

  int get _avgScore {
    if (_results.isEmpty) return 0;
    final total = _results.fold<double>(
        0, (sum, r) => sum + ((r['pct'] ?? 0) as num).toDouble());
    return (total / _results.length).round();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(children: [
        _SideRail(
          isLoggedIn: _isLoggedIn,
          onHome: () {},
          onPractice: () => _openPractice(),
          onTraining: _openTrainingScreen,
          onProfileOrLogin: _isLoggedIn
              ? () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => StudentProfileScreen(waNumber: _waNumber)))
              : () => context.push('/join'),
        ),
        Expanded(child: _buildBody(context)),
      ]),
      floatingActionButton: _isLoggedIn
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FloatingActionButton.extended(
                  heroTag: 'checkin',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const QrScanScreen()),
                  ),
                  backgroundColor: AppColors.accent,
                  icon: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white),
                  label: Text('Check In',
                      style: GoogleFonts.poppins(
                          color: Colors.white, fontWeight: FontWeight.w600)),
                ),
                if (_waNumber != null && _waNumber!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  FloatingActionButton.extended(
                    heroTag: 'aichat',
                    onPressed: _openAiChat,
                    backgroundColor: const Color(0xFF00BFA5),
                    icon: const Icon(Icons.chat_rounded, color: Colors.white),
                    label: Text(AppLocalizations.of(context)!.studentPortalChatAI,
                        style: GoogleFonts.poppins(
                            color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                ],
              ],
            )
          : null,
    );
  }

  Widget _buildBody(BuildContext context) {
    return _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.wifi_off_rounded,
                          size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 12),
                      Text(_error!,
                          style: GoogleFonts.inter(
                              color: AppColors.textSecondary)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _loading = true;
                              _error = null;
                            });
                            _loadFeed();
                          },
                          child: Text(AppLocalizations.of(context)!.studentPortalRetry)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    setState(() => _loading = true);
                    await _loadFeed();
                  },
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: _HomeHeader(
                          isLoggedIn: _isLoggedIn,
                          name: _studentName,
                          institute: _instituteName,
                          testsTaken: _testsTaken,
                          avgScore: _avgScore,
                          onRefresh: () {
                            setState(() => _loading = true);
                            _loadFeed();
                          },
                          onProfile: () => Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => StudentProfileScreen(waNumber: _waNumber))),
                          onLogin: () => context.push('/join'),
                          onLogoTap: _onLogoTap,
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.only(top: 16, bottom: 16),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            if (_subscription != null)
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: _QuizLimitBanner(
                                  subscription: _subscription!,
                                  onUpgrade: _showUpgradeSheet,
                                ),
                              ),
                            if (_subscription != null) const SizedBox(height: 20),

                            if (_waNumber != null && _waNumber!.isNotEmpty) ...[
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: _AiChatBanner(onTap: _openAiChat),
                              ),
                              const SizedBox(height: 20),
                            ],

                            // ── Popular Topics to Practice (Unstop-style row) ──
                            _RowSectionHeader(
                              title: 'Practice Tests',
                              subtitle: 'Pick a topic — AI builds the test instantly',
                              onViewAll: () => _openPractice(),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 128,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: _practiceSubjects.length,
                                separatorBuilder: (_, __) => const SizedBox(width: 12),
                                itemBuilder: (context, i) {
                                  final s = _practiceSubjects[i];
                                  return _TopicCard(
                                    label: s.$1, icon: s.$2, color: s.$3,
                                    onTap: () => _openPractice(subject: s.$1),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 28),

                            // ── Training Modules (Unstop-style row, real data) ──
                            Consumer<TrainingModuleProvider>(
                              builder: (context, provider, _) {
                                if (!provider.modulesLoaded && !provider.isLoading) {
                                  return const SizedBox.shrink();
                                }
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _RowSectionHeader(
                                      title: 'Training Modules',
                                      subtitle: 'Notes, videos & tests from your coaching',
                                      onViewAll: _openTrainingScreen,
                                    ),
                                    const SizedBox(height: 12),
                                    if (provider.isLoading && provider.modules.isEmpty)
                                      const SizedBox(
                                          height: 150,
                                          child: Center(child: CircularProgressIndicator()))
                                    else if (provider.modules.isEmpty)
                                      const Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 16),
                                        child: _EmptyRowHint(
                                          icon: Icons.school_rounded,
                                          text: 'Your coaching hasn\'t published any modules yet.',
                                        ),
                                      )
                                    else
                                      SizedBox(
                                        height: 150,
                                        child: ListView.separated(
                                          scrollDirection: Axis.horizontal,
                                          padding: const EdgeInsets.symmetric(horizontal: 16),
                                          itemCount: provider.modules.length,
                                          separatorBuilder: (_, __) => const SizedBox(width: 12),
                                          itemBuilder: (context, i) {
                                            final m = provider.modules[i];
                                            final progress = provider.getProgress(m.id);
                                            final total = m.totalContentItems;
                                            final pct = total == 0
                                                ? 0.0
                                                : (progress?.completedCount ?? 0) / total;
                                            return _ModuleCard(
                                              module: m, progress: pct,
                                              onTap: () => _openModule(m),
                                            );
                                          },
                                        ),
                                      ),
                                    const SizedBox(height: 28),
                                  ],
                                );
                              },
                            ),

                            // ── Dev Tools (public, no login — ever) ──
                            const _RowSectionHeader(
                              title: 'Dev Tools',
                              subtitle: 'Test brokers and endpoints right in the browser — free, no login',
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 128,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                children: [
                                  _TopicCard(
                                    label: 'MQTT Tester', icon: Icons.developer_board_rounded,
                                    color: const Color(0xFF7C4DFF),
                                    onTap: () => Navigator.push(context,
                                        MaterialPageRoute(builder: (_) => const MqttTesterScreen())),
                                  ),
                                  const SizedBox(width: 12),
                                  _TopicCard(
                                    label: 'HTTP Tester', icon: Icons.http_rounded,
                                    color: const Color(0xFF1565C0),
                                    onTap: () => Navigator.push(context,
                                        MaterialPageRoute(builder: (_) => const HttpTesterScreen())),
                                  ),
                                  const SizedBox(width: 12),
                                  _TopicCard(
                                    label: 'WebSocket Tester', icon: Icons.cable_rounded,
                                    color: const Color(0xFF00BFA5),
                                    onTap: () => Navigator.push(context,
                                        MaterialPageRoute(builder: (_) => const WebSocketTesterScreen())),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 28),

                            // ── Coming Soon (Unstop-style row) ──
                            const _RowSectionHeader(
                              title: "What's Coming",
                              subtitle: 'More ways to build, compete and get hired',
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 128,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                children: const [
                                  _ComingSoonMiniCard(icon: Icons.emoji_events_rounded, label: 'IoT & Embedded Hackathons'),
                                  SizedBox(width: 12),
                                  _ComingSoonMiniCard(icon: Icons.work_rounded, label: 'Embedded/IoT Internships'),
                                  SizedBox(width: 12),
                                  _ComingSoonMiniCard(icon: Icons.business_center_rounded, label: 'Product Engineer Job Board'),
                                  SizedBox(width: 12),
                                  _ComingSoonMiniCard(icon: Icons.groups_rounded, label: 'Mentorship with Industry Engineers'),
                                ],
                              ),
                            ),
                            const SizedBox(height: 28),

                            // ── Institute feed: tests / results / notices ──
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (_tests.isNotEmpty) ...[
                                    _SectionHeader(
                                        title: AppLocalizations.of(context)!.studentPortalTestsAvailable,
                                        count: _tests.length),
                                    const SizedBox(height: 8),
                                    ..._tests.map((t) => _TestCard(
                                        test: t,
                                        studentToken: _token ?? '',
                                        quizAllowed: _subscription?['is_premium'] == true ||
                                            (_subscription?['remaining_today'] ?? 3) > 0,
                                        onUpgrade: _showUpgradeSheet)),
                                    const SizedBox(height: 20),
                                  ],

                                  if (_results.isNotEmpty) ...[
                                    _SectionHeader(
                                        title: AppLocalizations.of(context)!.studentPortalRecentResults,
                                        count: _results.length),
                                    const SizedBox(height: 8),
                                    ..._results.map((r) => _ResultCard(result: r)),
                                    const SizedBox(height: 20),
                                  ],

                                  if (_notices.isNotEmpty) ...[
                                    _SectionHeader(
                                        title: AppLocalizations.of(context)!.studentPortalNotices,
                                        count: _notices.length),
                                    const SizedBox(height: 8),
                                    ..._notices.map((n) => _NoticeCard(notice: n)),
                                    const SizedBox(height: 20),
                                  ],

                                  if (_tests.isEmpty && _notices.isEmpty && _results.isEmpty)
                                    _EmptyFeedCard(
                                      onStartPractice: () => _openPractice(),
                                      isLoggedIn: _isLoggedIn,
                                    ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 80),
                          ]),
                        ),
                      ),
                    ],
                  ),
                );
  }
}

class _HomeHeader extends StatelessWidget {
  final bool isLoggedIn;
  final String name;
  final String institute;
  final int testsTaken;
  final int avgScore;
  final VoidCallback onRefresh;
  final VoidCallback onProfile;
  final VoidCallback onLogin;
  final VoidCallback onLogoTap;

  const _HomeHeader({
    required this.isLoggedIn,
    required this.name,
    required this.institute,
    required this.testsTaken,
    required this.avgScore,
    required this.onRefresh,
    required this.onProfile,
    required this.onLogin,
    required this.onLogoTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0D1B5E), Color(0xFF060F38)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                GestureDetector(
                  onTap: onLogoTap,
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [AppColors.accent, Color(0xFFFF8A50)]),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 22),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: isLoggedIn
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Hi, $name 👋',
                                style: GoogleFonts.poppins(
                                    color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
                            if (institute.isNotEmpty)
                              Text(institute,
                                  style: GoogleFonts.inter(color: Colors.white54, fontSize: 12)),
                          ],
                        )
                      : Text('AltrobyteLab',
                          style: GoogleFonts.poppins(
                              color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                ),
                if (isLoggedIn) ...[
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
                    onPressed: onRefresh,
                  ),
                  IconButton(
                    icon: const Icon(Icons.account_circle_rounded, color: Colors.white),
                    tooltip: 'Profile',
                    onPressed: onProfile,
                  ),
                ],
                // TEMPORARY: login button hidden while WhatsApp OTP is broken.
              ]),
              const SizedBox(height: 18),
              if (isLoggedIn)
                Row(children: [
                  Expanded(
                    child: _StatPill(
                      icon: Icons.quiz_rounded, color: const Color(0xFF7C4DFF),
                      value: '$testsTaken', label: 'Tests taken',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatPill(
                      icon: Icons.trending_up_rounded, color: const Color(0xFF00BFA5),
                      value: testsTaken > 0 ? '$avgScore%' : '—', label: 'Avg score',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatPill(
                      icon: Icons.local_fire_department_rounded, color: AppColors.accent,
                      value: testsTaken > 0 ? 'Active' : 'New', label: 'Status',
                    ),
                  ),
                ])
              else
                Text('Learn. Build. Compete in Deeptech.',
                    style: GoogleFonts.inter(color: Colors.white70, fontSize: 13.5)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Persistent icon-only navigation rail (Unstop-style), visible in every
/// auth state — browsing never requires login, only specific actions do.
class _SideRail extends StatelessWidget {
  final bool isLoggedIn;
  final VoidCallback onHome;
  final VoidCallback onPractice;
  final VoidCallback onTraining;
  final VoidCallback onProfileOrLogin;

  const _SideRail({
    required this.isLoggedIn,
    required this.onHome,
    required this.onPractice,
    required this.onTraining,
    required this.onProfileOrLogin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 68,
      color: const Color(0xFF0D1B5E),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            _RailItem(icon: Icons.home_rounded, label: 'Home', active: true, onTap: onHome),
            _RailItem(icon: Icons.bolt_rounded, label: 'Practice', onTap: onPractice),
            _RailItem(icon: Icons.school_rounded, label: 'Training', onTap: onTraining),
            const Spacer(),
            // TEMPORARY: login/profile rail item hidden while WhatsApp OTP is broken.
            if (isLoggedIn)
              _RailItem(
                icon: Icons.account_circle_rounded,
                label: 'Profile',
                onTap: onProfileOrLogin,
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _RailItem({required this.icon, required this.label, this.active = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            Icon(icon, color: active ? AppColors.accent : Colors.white54, size: 22),
            const SizedBox(height: 4),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 9.5, color: active ? AppColors.accent : Colors.white38,
                    fontWeight: active ? FontWeight.w600 : FontWeight.normal)),
          ],
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;
  const _StatPill({required this.icon, required this.color, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 8),
          Text(value,
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
          Text(label, style: GoogleFonts.inter(color: Colors.white54, fontSize: 10.5)),
        ],
      ),
    );
  }
}

class _EmptyFeedCard extends StatelessWidget {
  final VoidCallback onStartPractice;
  final bool isLoggedIn;
  const _EmptyFeedCard({required this.onStartPractice, this.isLoggedIn = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFF7C4DFF).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF7C4DFF), size: 30),
          ),
          const SizedBox(height: 16),
          Text(isLoggedIn ? 'No tests from your coaching yet' : 'Ready when you are',
              style: GoogleFonts.poppins(
                  fontSize: 15.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          Text(
              isLoggedIn
                  ? 'Meanwhile, generate your own AI practice test on any topic.'
                  : 'Pick a topic above to generate an AI practice test.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 18),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF7C4DFF),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
            ),
            onPressed: onStartPractice,
            icon: const Icon(Icons.bolt_rounded, size: 18),
            label: Text('Start AI Practice Test',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13.5)),
          ),
        ],
      ),
    );
  }
}

class _AiChatBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _AiChatBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF00897B), Color(0xFF00BFA5)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFF00BFA5).withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.smart_toy_rounded,
                  color: Colors.white, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Builder(builder: (ctx) => Text(
                      AppLocalizations.of(ctx)!.studentPortalAskAI,
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold))),
                  Builder(builder: (ctx) => Text(
                      AppLocalizations.of(ctx)!.studentPortalAskAISubtitle,
                      style: GoogleFonts.inter(
                          color: Colors.white70, fontSize: 12))),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white60, size: 16),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  const _SectionHeader({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title,
            style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text('$count',
              style: GoogleFonts.inter(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

class _TestCard extends StatelessWidget {
  final Map<String, dynamic> test;
  final String studentToken;
  final bool quizAllowed;
  final VoidCallback onUpgrade;
  const _TestCard({
    required this.test,
    required this.studentToken,
    this.quizAllowed = true,
    required this.onUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    final attempted = (test['attempted'] ?? 0) > 0;
    final difficulty = test['difficulty'] ?? '';
    final diffColor = difficulty == 'easy'
        ? Colors.green
        : difficulty == 'hard'
            ? AppColors.error
            : Colors.orange;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: attempted
            ? null
            : !quizAllowed
                ? onUpgrade
                : () => context.push('/test/${test['id']}',
                    extra: studentToken),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                    attempted
                        ? Icons.check_circle_rounded
                        : Icons.quiz_rounded,
                    color: attempted ? Colors.green : AppColors.primary,
                    size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(test['title'] ?? 'Test',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (test['subject'] != null) ...[
                          Text(test['subject'],
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppColors.textSecondary)),
                          const SizedBox(width: 8),
                        ],
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: diffColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(difficulty,
                              style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: diffColor,
                                  fontWeight: FontWeight.w500)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (test['duration_mins'] != null)
                Column(
                  children: [
                    Text('${test['duration_mins']}',
                        style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary)),
                    Builder(builder: (ctx) => Text(
                        AppLocalizations.of(ctx)!.studentPortalMin,
                        style: GoogleFonts.inter(
                            fontSize: 11, color: AppColors.textSecondary))),
                  ],
                ),
              const SizedBox(width: 8),
              if (attempted)
                const Icon(Icons.check_circle_rounded,
                    color: Colors.green, size: 20)
              else
                const Icon(Icons.arrow_forward_ios_rounded,
                    color: AppColors.textSecondary, size: 14),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final Map<String, dynamic> result;
  const _ResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final pct = (result['pct'] ?? 0).toDouble();
    final color = pct >= 70
        ? Colors.green
        : pct >= 40
            ? Colors.orange
            : AppColors.error;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text('${pct.toStringAsFixed(0)}%',
                    style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: color)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(result['title'] ?? 'Test',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                          color: AppColors.textPrimary)),
                  Text(
                      '${result['score'] ?? 0} / ${result['total'] ?? 0} correct',
                      style: GoogleFonts.inter(
                          fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuizLimitBanner extends StatelessWidget {
  final Map<String, dynamic> subscription;
  final VoidCallback onUpgrade;
  const _QuizLimitBanner({required this.subscription, required this.onUpgrade});

  @override
  Widget build(BuildContext context) {
    final isPremium = subscription['is_premium'] == true;
    final remaining = subscription['remaining_today'] ?? 0;
    final dailyLimit = subscription['daily_limit'] ?? 3;
    final genRemaining = subscription['generations_remaining'] ?? 0;
    final genLimit = subscription['monthly_generation_limit'] ?? 5;
    final genUsed = subscription['generations_used_this_month'] ?? 0;

    if (isPremium) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.workspace_premium_rounded, color: AppColors.accent, size: 18),
              const SizedBox(width: 8),
              Text('Premium Active',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.accent)),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              const SizedBox(width: 26),
              Text('Tests this month: $genUsed / $genLimit  •  Quizzes: unlimited',
                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.accent.withValues(alpha: 0.8))),
            ]),
          ],
        ),
      );
    }

    final color = remaining > 0 ? AppColors.primary : AppColors.error;
    final genColor = genRemaining > 0 ? const Color(0xFF6366F1) : AppColors.error;
    return Column(
      children: [
        // Daily quiz attempts banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(children: [
            Icon(remaining > 0 ? Icons.quiz_rounded : Icons.lock_clock_rounded,
                color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    remaining > 0
                        ? '$remaining of $dailyLimit free quizzes remaining today'
                        : 'Daily quiz limit reached',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: color),
                  ),
                  if (remaining <= 0)
                    Text('Upgrade to Premium for more access',
                        style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            ),
            TextButton(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: onUpgrade,
              child: Text(remaining > 0 ? 'Upgrade' : 'Get Premium',
                  style: GoogleFonts.inter(
                      fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.accent)),
            ),
          ]),
        ),
        const SizedBox(height: 6),
        // Monthly generation quota banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: genColor.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: genColor.withValues(alpha: 0.25)),
          ),
          child: Row(children: [
            Icon(Icons.auto_awesome_rounded, color: genColor, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                genRemaining > 0
                    ? 'AI Tests: $genRemaining remaining this month ($genUsed/$genLimit used)'
                    : 'Monthly AI test limit reached ($genLimit/month)',
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: genColor),
              ),
            ),
            if (genRemaining <= 0)
              TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: onUpgrade,
                child: Text('₹99/mo',
                    style: GoogleFonts.inter(
                        fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.accent)),
              ),
          ]),
        ),
      ],
    );
  }
}

class _NoticeCard extends StatelessWidget {
  final Map<String, dynamic> notice;
  const _NoticeCard({required this.notice});

  String? _extractYoutubeId(String? url) {
    if (url == null || url.isEmpty) return null;
    try {
      final uri = Uri.parse(url);
      if (uri.host.contains('youtu.be')) return uri.pathSegments.first;
      if (uri.host.contains('youtube.com')) return uri.queryParameters['v'];
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final type = notice['type'] ?? 'notice';
    final linkUrl = notice['link_url'] as String?;
    final isVideo = type == 'video';
    final youtubeId = _extractYoutubeId(linkUrl);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: linkUrl != null && linkUrl.isNotEmpty
            ? () async {
                final uri = Uri.parse(linkUrl);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              }
            : null,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // YouTube thumbnail for video posts
          if (isVideo && youtubeId != null) ...[
            Stack(alignment: Alignment.center, children: [
              Image.network(
                'https://img.youtube.com/vi/$youtubeId/hqdefault.jpg',
                width: double.infinity, height: 160,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 160, color: Colors.grey.shade200,
                  child: const Icon(Icons.broken_image_rounded, size: 40, color: Colors.grey),
                ),
              ),
              Container(
                width: 50, height: 50,
                decoration: BoxDecoration(
                  color: Colors.red.shade600.withValues(alpha: 0.92),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 30),
              ),
            ]),
          ],
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (!isVideo || youtubeId == null)
                Container(
                  width: 36, height: 36,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: isVideo ? const Color(0xFFFFEBEE) : const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isVideo ? Icons.play_circle_filled_rounded : Icons.campaign_rounded,
                    color: isVideo ? const Color(0xFFE53935) : const Color(0xFFF57C00),
                    size: 20,
                  ),
                ),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(notice['title'] ?? '',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600, fontSize: 13,
                          color: AppColors.textPrimary)),
                  if ((notice['content'] ?? '').isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(notice['content'],
                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                  if (linkUrl != null && linkUrl.isNotEmpty && !isVideo) ...[
                    const SizedBox(height: 6),
                    Row(children: [
                      const Icon(Icons.open_in_new_rounded, size: 12, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text('Open Link',
                          style: GoogleFonts.inter(
                              fontSize: 11, color: AppColors.primary,
                              fontWeight: FontWeight.w600)),
                    ]),
                  ],
                ]),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ── Unstop-style horizontal discovery rows ──────────────────────────────────

class _RowSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onViewAll;
  const _RowSectionHeader({required this.title, this.subtitle, this.onViewAll});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: GoogleFonts.poppins(
                      fontSize: 16.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              if (subtitle != null)
                Text(subtitle!,
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
        ),
        if (onViewAll != null)
          TextButton(
            onPressed: onViewAll,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text('View All',
                  style: GoogleFonts.inter(
                      fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.primary)),
              const SizedBox(width: 2),
              const Icon(Icons.arrow_forward_rounded, size: 14, color: AppColors.primary),
            ]),
          ),
      ]),
    );
  }
}

class _TopicCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _TopicCard({required this.label, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 108,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(11)),
              child: Icon(icon, color: color, size: 19),
            ),
            const Spacer(),
            Text(label,
                maxLines: 2, overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  final TrainingModule module;
  final double progress;
  final VoidCallback onTap;
  const _ModuleCard({required this.module, required this.progress, required this.onTap});

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _parseColor(module.color);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(11)),
              child: Icon(Icons.school_rounded, color: color, size: 19),
            ),
            const SizedBox(height: 10),
            Text(module.title,
                maxLines: 2, overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            const Spacer(),
            Text('${module.topicCount} topics • ${module.totalContentItems} items',
                style: GoogleFonts.inter(fontSize: 10.5, color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progress, minHeight: 5,
                backgroundColor: color.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation(progress >= 1 ? AppColors.success : color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComingSoonMiniCard extends StatelessWidget {
  final IconData icon;
  final String label;
  const _ComingSoonMiniCard({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 136,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(11)),
            child: Icon(icon, color: Colors.grey.shade600, size: 19),
          ),
          const Spacer(),
          Text(label,
              maxLines: 2, overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          const SizedBox(height: 3),
          Text('Coming Soon',
              style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w700, color: AppColors.accent)),
        ],
      ),
    );
  }
}

class _EmptyRowHint extends StatelessWidget {
  final IconData icon;
  final String text;
  const _EmptyRowHint({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        Icon(icon, color: Colors.grey.shade400, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textSecondary)),
        ),
      ]),
    );
  }
}
