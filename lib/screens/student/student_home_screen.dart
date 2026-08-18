import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../constants/app_colors.dart';
import '../../widgets/showcase_widgets.dart';
import '../../widgets/auth_sheet.dart';
import 'showcase_screens.dart';
import '../../utils/formatters.dart';
import '../../constants/api_constants.dart';
import '../../l10n/app_localizations.dart';
import '../../models/training_module_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/training_module_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/upgrade_sheet.dart';
import '../tools/ble_tester_screen.dart';
import '../tools/http_tester_screen.dart';
import '../tools/mqtt_tester_screen.dart';
import '../tools/websocket_tester_screen.dart';
import 'student_module_detail_screen.dart';
import 'student_practice_screen.dart';
import 'student_profile_screen.dart';
import 'student_training_screen.dart';

const _practiceSubjects = [
  ('Embedded C', Icons.memory_rounded, AppColors.primary),
  ('Electronics Fundamentals', Icons.bolt_rounded, AppColors.accent),
  ('ESP32 / Microcontrollers', Icons.developer_board_rounded, AppColors.primary),
  ('IoT Protocols', Icons.wifi_rounded, AppColors.accent),
  ('Circuit Design & PCB', Icons.electrical_services_rounded, AppColors.primary),
  ('Sensors', Icons.sensors_rounded, AppColors.accent),
  ('AI/ML for Embedded', Icons.psychology_rounded, AppColors.primary),
  ('FreeRTOS / RTOS', Icons.schedule_rounded, AppColors.accent),
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
  /// Custom Test Series generation is admin-only until it leaves beta. The
  /// server is the authority (/platform/features); this only decides whether
  /// to show an entry point for something the API would refuse anyway.
  bool _customTestEnabled = false;
  /// Everything the programme card states, straight from the roadmap it links
  /// to. Hardcoding "4 months" and "165 milestones" in the widget meant the
  /// card could disagree with the page one tap away — and the start date,
  /// which is a setting, never appeared at all.
  Map<String, dynamic> _programFacts = const {};

  /// Admin-curated strips. Empty until an admin adds one, and each section
  /// renders nothing at all rather than an empty placeholder — a "0 stories"
  /// heading is worse than no heading.
  List<dynamic> _stories = [];
  List<dynamic> _labSetups = [];
  List<dynamic> _placements = [];
  List<dynamic> _reviews = [];

  /// Placements first, then reviews, then stories: a result outranks a
  /// work-in-progress, and the first two cards are the only ones some people
  /// will ever see.
  List<dynamic> get _topStrip => [..._placements, ..._reviews, ..._stories];
  bool _loading = true;
  String? _feedError;

  List<dynamic> _featuredSessions = [];
  /// Published quizzes shown as a home row — real, tappable content that
  /// does not depend on the Custom Test Series feature being live.
  List<Map<String, dynamic>> _homeQuizzes = [];

  @override
  void initState() {
    super.initState();
    _loadFeed();
    _loadFeaturedSessions();
    _loadFeatures();
  }

  Future<void> _loadFeatures() async {
    try {
      final f = await ApiService.getPlatformFeatures();
      if (!mounted) return;
      setState(() => _customTestEnabled = f['custom_test_enabled'] == true);
    } catch (_) {
      // Default stays false — never advertise a feature we cannot confirm.
    }
  }

  Future<void> _loadFeaturedSessions() async {
    try {
      final sessions = await ApiService.getLiveSessions(featured: true);
      // One summary card for practice content, not one per quiz — the
      // Featured row is a teaser, not the full catalog. It links through
      // to the actual Test Series page for everything else.
      List<dynamic> practiceItems = [];
      List<Map<String, dynamic>> homeQuizzes = [];
      try {
        final testData = await ApiService.getTestSeriesForStudent();
        final series = (testData['series'] as List?) ?? [];
        final moduleGroups = (testData['module_tests'] as List?) ?? [];
        final standalone = (testData['standalone_tests'] as List?) ?? [];
        var quizCount = standalone.length;
        for (final m in moduleGroups) {
          quizCount += ((m['tests'] as List?) ?? []).length;
        }
        final courseCount = moduleGroups.length;

        // Keep the actual quizzes for the home row. With Custom Test Series
        // admin-only, this is the real practice content a visitor can use —
        // without it the homepage lost a whole section and looked empty.
        homeQuizzes = <Map<String, dynamic>>[
          for (final t in standalone) Map<String, dynamic>.from(t as Map),
          for (final m in moduleGroups)
            for (final t in ((m['tests'] as List?) ?? []))
              {...Map<String, dynamic>.from(t as Map), 'course': m['title']},
        ];

        // Prefer a real curated series (has its own admin-written
        // description); otherwise synthesize a summary from the quizzes.
        final firstSeries = series.isNotEmpty ? Map<String, dynamic>.from(series.first) : null;
        if (firstSeries != null) {
          practiceItems.add({
            ...firstSeries,
            '_kind': 'series',
            'description': (firstSeries['description'] as String?)?.trim().isNotEmpty == true
                ? firstSeries['description']
                : 'A curated set of tests to check what you\'ve learned.',
          });
        } else if (quizCount > 0) {
          practiceItems.add({
            'id': null,
            'title': 'Test Series',
            'description': courseCount > 0
                ? '$quizCount quiz${quizCount == 1 ? '' : 'zes'} across $courseCount course${courseCount == 1 ? '' : 's'} — test what you\'ve learned.'
                : '$quizCount quiz${quizCount == 1 ? '' : 'zes'} ready to practice.',
            'color': '#7C4DFF',
            '_kind': 'quiz_summary',
          });
        }
      } catch (_) {
        // Test Series failing must not block Live Sessions from showing.
      }
      if (!mounted) return;
      setState(() {
        _featuredSessions = _mergeFeatured(sessions, practiceItems);
        _homeQuizzes = homeQuizzes;
      });
    } catch (_) {
      // Non-critical — home feed must not break if this fails.
    }
  }

  /// Priority order: active/upcoming sessions first (soonest first), then
  /// published test series/quizzes, then past sessions (newest first) — so
  /// the most relevant, actionable card is always what the carousel opens on.
  static List<dynamic> _mergeFeatured(List<dynamic> sessions, List<dynamic> practiceItems) {
    DateTime? dateOf(dynamic s) {
      try {
        final raw = (s as Map)['session_date'];
        return raw != null ? DateTime.parse(raw.toString()) : null;
      } catch (_) {
        return null;
      }
    }

    final now = DateTime.now();
    final sessionItems = sessions
        .map((s) => {...Map<String, dynamic>.from(s as Map), '_type': 'session'})
        .toList();
    final seriesItems = practiceItems
        .map((s) => {...Map<String, dynamic>.from(s), '_type': 'test_series'})
        .toList();

    final upcoming = sessionItems.where((s) {
      final d = dateOf(s);
      return d == null || !d.isBefore(now);
    }).toList()
      ..sort((a, b) {
        final da = dateOf(a);
        final db = dateOf(b);
        if (da == null || db == null) return da == null ? (db == null ? 0 : 1) : -1;
        return da.compareTo(db);
      });
    final past = sessionItems.where((s) {
      final d = dateOf(s);
      return d != null && d.isBefore(now);
    }).toList()
      ..sort((a, b) {
        final da = dateOf(a)!;
        final db = dateOf(b)!;
        return db.compareTo(da);
      });

    return [...upcoming, ...seriesItems, ...past];
  }

  bool get _isLoggedIn => _token != null;

  int _logoTaps = 0;
  Timer? _logoTapTimer;
  // TEMPORARY pre-launch shortcut: 5 taps = admin, 10 taps (without pausing)
  // = super admin, both skip login entirely via the debug auto-login
  // endpoints. Waits briefly after the last tap so reaching 10 doesn't
  // fire the 5-tap admin navigation first. Remove this and restore the
  // normal /login and /super/login flows before real launch.
  void _onLogoTap() {
    _logoTaps++;
    _logoTapTimer?.cancel();
    _logoTapTimer = Timer(const Duration(milliseconds: 2000), () {
      final taps = _logoTaps;
      _logoTaps = 0;
      if (taps >= 10) {
        _debugGoSuperAdmin();
      } else if (taps >= 5) {
        _debugGoAdmin();
      }
    });
  }

  Future<void> _debugGoAdmin() async {
    final auth = context.read<AuthProvider>();
    try {
      final data = await ApiService.debugAutoLoginAdmin();
      await auth.setFromResponse(data);
      if (mounted) context.go('/dashboard');
    } catch (_) {}
  }

  Future<void> _debugGoSuperAdmin() async {
    final auth = context.read<AuthProvider>();
    try {
      final data = await ApiService.debugAutoLoginSuperAdmin();
      await auth.setFromResponse(data);
      if (mounted) context.go('/super/dashboard');
    } catch (_) {}
  }

  /// Working login path (WhatsApp OTP delivery is unreliable) — one Google
  /// button resolves to super_admin / admin / student based on the
  /// account's email.
  /// Opens the sheet with both methods. Google alone was the only way in, so
  /// every account arrived without a phone number — which is the one thing the
  /// OTP, the reminders and the CRM all need.
  Future<void> _signIn() async {
    final ok = await showAuthSheet(context);
    if (ok && mounted) _loadFeed();
  }

  Future<void> _loadFeed() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('student_token');

    setState(() {
      _token = token;
      _studentName = prefs.getString('student_name') ?? 'Student';
      _instituteName = prefs.getString('student_institute_name') ?? '';
    });

    // Admin-curated strips. Each is optional and independent: a failure in one
    // must not cost the page the other, and neither may block the feed.
    try {
      final r = await ApiService.getRoadmap('product-engineering');
      final plans = (r['plans'] as List?) ?? [];
      if (mounted) {
        setState(() => _programFacts = {
              'duration': plans.isEmpty
                  ? (r['duration_label'] as String? ?? '')
                  : plans.map((p) => (p as Map)['duration_label']).join(' or '),
              'milestones': '${r['step_count'] ?? ''}',
              'start': r['start_label'] as String? ?? '',
            });
      }
    } catch (_) {}
    try {
      final stories = await ApiService.getShowcase('story');
      if (mounted) setState(() => _stories = stories);
    } catch (_) {}
    try {
      final setups = await ApiService.getShowcase('lab_setup');
      if (mounted) setState(() => _labSetups = setups);
    } catch (_) {}
    try {
      final p = await ApiService.getShowcase('placement');
      if (mounted) setState(() => _placements = p);
    } catch (_) {}
    try {
      final rv = await ApiService.getShowcase('review');
      if (mounted) setState(() => _reviews = rv);
    } catch (_) {}

    // This only feeds the institute tests/notices/results section — it must
    // never block the rest of the home page (Practice/Training/Dev Tools
    // etc. don't depend on it at all). A transient hiccup here used to blank
    // out the entire home screen behind a "check internet" wall.
    setState(() { _loading = false; _feedError = null; });
    int? instituteId;
    try {
      final res = await ApiService.safeGet(
        Uri.parse(ApiConstants.studentFeed()),
        headers: token != null ? {'Authorization': 'Bearer $token'} : {},
      );
      // The status was never checked: a 401 or 500 body decodes fine, leaving
      // every list null and the page silently empty with no error at all —
      // while a mere network blip raised and got reported as a hard failure.
      // Exactly backwards.
      if (res.statusCode >= 400) {
        throw ApiException('Feed unavailable', statusCode: res.statusCode);
      }
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      instituteId = body['institute_id'] as int?;
      if (!mounted) return;
      setState(() {
        _tests = List<Map<String, dynamic>>.from(body['tests'] ?? []);
        _notices = List<Map<String, dynamic>>.from(body['notices'] ?? []);
        _results = List<Map<String, dynamic>>.from(body['recent_results'] ?? []);
        _waNumber = body['wa_ai_number'] as String?;
        _subscription = body['subscription'] as Map<String, dynamic>?;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _feedError = AppLocalizations.of(context)!.studentPortalErrorLoad;
        });
      }
    }

    // Loading the training modules is a SEPARATE concern. It used to sit
    // inside the try above, so a provider failure was reported to the student
    // as "the feed could not load" even when the feed had loaded perfectly.
    if (instituteId != null) {
      try {
        await prefs.setInt('student_institute_id', instituteId);
        if (mounted) {
          context.read<TrainingModuleProvider>().ensureModulesAsStudent(instituteId);
        }
      } catch (_) {
        // The Training section handles its own empty state.
      }
    }
  }

  Future<void> _openPractice({String? subject}) async {
    // Plain nav taps (no subject) land on the unified Practice & Test Series
    // tab; a topic card tap (subject set) skips straight to AI-generate
    // with that subject preselected.
    if (subject == null) {
      context.push('/student/test-series');
      return;
    }
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
        premiumPrice: (_subscription?['plan_999_price'] as num?)?.toInt() ?? 999,
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
                backgroundColor: AppColors.success,
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

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 700;
    final profileOrLogin = _isLoggedIn
        ? () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => StudentProfileScreen(waNumber: _waNumber)))
        : _signIn;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Positioned.fill(
            child: isMobile
                ? _buildBody(context)
                : Row(children: [
                    _SideRail(
                      isLoggedIn: _isLoggedIn,
                      showCustomTest: _customTestEnabled,
                      onHome: () {},
                      onPractice: () => _openPractice(),
                      onTraining: _openTrainingScreen,
                      onProfileOrLogin: profileOrLogin,
                    ),
                    Expanded(child: _buildBody(context)),
                  ]),
          ),
          // Bottom-right. Moving it left put it on top of the Featured
          // cards' own action buttons, which is worse than what it was
          // avoiding. bottom:88 sits above the Chat AI FAB when there is
          // one, and low enough to clear the carousel's next-arrow.
          Positioned(
              right: 12,
              bottom: isMobile ? 14 : 88,
              child: const _ActivityFeedTicker()),
        ],
      ),
      bottomNavigationBar: isMobile
          ? _StudentBottomNav(
              isLoggedIn: _isLoggedIn,
              showCustomTest: _customTestEnabled,
              onPractice: () => _openPractice(),
              onTestSeries: () => context.push('/student/test-series'),
              onTraining: _openTrainingScreen,
              onActivity: () => context.push('/student/activity'),
              onProfileOrLogin: profileOrLogin,
            )
          : null,
      // No Check In FAB — QR check-in is an offline-workshop-only action, and
      // as an extended FAB it was the loudest element on the whole page while
      // being the least used. QrScanScreen still exists for wherever check-in
      // belongs later.
      floatingActionButton: _isLoggedIn && _waNumber != null && _waNumber!.isNotEmpty
          ? FloatingActionButton.extended(
              heroTag: 'aichat',
              onPressed: _openAiChat,
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.chat_rounded, color: Colors.white),
              label: Text(AppLocalizations.of(context)!.studentPortalChatAI,
                  style: GoogleFonts.poppins(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            )
          : null,
    );
  }

  Widget _buildBody(BuildContext context) {
    // On desktop the side rail already lists Practice/Training/Experiments/
    // Jobs (and everything the "More" sheet holds), so the action row is a
    // pure duplicate that costs ~110px of above-the-fold space and pushed
    // Featured below the fold. Mobile has no rail, so it keeps the row.
    final isMobile = MediaQuery.sizeOf(context).width < 700;
    return _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
                  onRefresh: () => _loadFeed(),
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: _HomeHeader(
                          isLoggedIn: _isLoggedIn,
                          name: _studentName,
                          institute: _instituteName,
                          subscription: _subscription,
                          onRefresh: () {
                            setState(() => _loading = true);
                            _loadFeed();
                          },
                          onProfile: () => Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => StudentProfileScreen(waNumber: _waNumber))),
                          onLogin: () => context.push('/join'),
                          onLogoTap: _onLogoTap,
                          onGoogleSignIn: _signIn,
                        ),
                      ),
                      if (isMobile)
                        SliverToBoxAdapter(
                          child: _PrimaryActionRow(
                            showCustomTest: _customTestEnabled,
                            onPractice: () => _openPractice(),
                            onTestSeries: () => context.push('/student/test-series'),
                            onTraining: _openTrainingScreen,
                            onExperiments: () => context.push('/student/experiments'),
                            onJobs: () => context.push('/jobs'),
                            onMore: () => _showMoreActionsSheet(
                              context,
                              onMockInterview: () => context.push('/student/mock-interview'),
                              onSessions: () => context.push('/live-sessions'),
                              onEvents: () => context.push('/events'),
                              onTestSeries: () => context.push('/student/test-series'),
                              onDevTools: () => context.push('/student/dev-tools'),
                              onPricing: () => context.push('/pricing'),
                              onActivity: () => context.push('/student/activity'),
                            ),
                          ),
                        ),
                      SliverPadding(
                        padding: EdgeInsets.only(top: isMobile ? 16 : 12, bottom: 16),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            // ── The roadmap, first, before anything else. It is
                            // the premium programme and the thing that turns a
                            // free visitor into a paying one, so it does not sit
                            // below a fold. Everything under it is material; this
                            // is the reason to want any of it. ──
                            _RoadmapCard(
                                facts: _programFacts,
                                // go, not push: in go_router 12 an imperative
                                // push does not write the browser address bar,
                                // so the roadmap opened at the homepage URL and
                                // could not be copied or bookmarked.
                                onTap: () =>
                                    context.go('/roadmap/product-engineering')),
                            const SizedBox(height: 24),

                            // ── Hero moment: continue an in-progress module, else the
                            // featured live session — never both at once. ──
                            Consumer<TrainingModuleProvider>(
                              builder: (context, provider, _) {
                                TrainingModule? continueModule;
                                double continuePct = 0;
                                for (final m in provider.modules) {
                                  if (m.topicCount == 0) continue;
                                  final total = m.totalContentItems;
                                  if (total == 0) continue;
                                  final completed = provider.getProgress(m.id)?.completedCount ?? 0;
                                  final pct = completed / total;
                                  if (pct > 0 && pct < 1) {
                                    continueModule = m;
                                    continuePct = pct;
                                    break;
                                  }
                                }
                                if (continueModule != null) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: _ContinueLearningCard(
                                      module: continueModule,
                                      pct: continuePct,
                                      onTap: () => _openModule(continueModule!),
                                    ),
                                  );
                                }
                                if (_featuredSessions.isNotEmpty) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: _FeaturedCarousel(
                                        sessions: _featuredSessions,
                                        waNumber: _waNumber),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                            const SizedBox(height: 20),

                            // ── Top Stories: the proof. Everything else on
                            // this page is a claim about what students get;
                            // these are photographs of them getting it. Each
                            // card cycles its own media so one card with five
                            // photos shows five. ──
                            // ── One strip, not three. Placements and reviews
                            // ride along with the stories: three sections cost
                            // the page more height than the extra headings were
                            // worth, and each card still reads as what it is. ──
                            if (_topStrip.isNotEmpty) ...[
                              ShowcaseHeader(
                                title: 'Top Stories',
                                subtitle: 'What our students build — and where '
                                    'they end up',
                                onViewAll: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const ShowcaseAlbumScreen(kind: 'story'))),
                              ),
                              const SizedBox(height: 12),
                              AutoScrollStrip(
                                height: 210,
                                itemCount: _topStrip.length,
                                itemBuilder: (context, i) {
                                  final item = _topStrip[i] as Map<String, dynamic>;
                                  void open() => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                ShowcaseDetailScreen(item: item)),
                                      );
                                  return switch (item['kind']) {
                                    'placement' =>
                                      PlacementCard(item: item, onTap: open),
                                    'review' => ReviewCard(item: item, onTap: open),
                                    _ => StoryCard(item: item, onTap: open),
                                  };
                                },
                              ),
                              const SizedBox(height: 26),
                            ],

                            // ── Choose your lab setup: the core product. Square
                            // cards with a price, because a lab setup is a thing
                            // you buy, not a thing you read. ──
                            if (_labSetups.isNotEmpty) ...[
                              ShowcaseHeader(
                                title: 'Choose your lab setup',
                                subtitle: 'Everything you need to build, in one box',
                                onViewAll: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => const ShowcaseAlbumScreen(
                                            kind: 'lab_setup'))),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                height: 268,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  itemCount: _labSetups.length,
                                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                                  itemBuilder: (context, i) {
                                    final item = _labSetups[i] as Map<String, dynamic>;
                                    return LabSetupCard(
                                      item: item,
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                ShowcaseDetailScreen(item: item)),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 26),
                            ],

                            if (_waNumber != null && _waNumber!.isNotEmpty) ...[
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: _AiChatBanner(onTap: _openAiChat),
                              ),
                              const SizedBox(height: 20),
                            ],

                            // ── Custom Test Series (Unstop-style topic row) ──
                            // Hidden entirely while the feature is admin-only:
                            // showing topic cards that lead to a 403 is worse
                            // than not showing the row at all.
                            // Real published Test Series — the practice row a
                            // visitor actually gets while Custom Test Series
                            // is admin-only. Without this the homepage had a
                            // hole where a whole section used to be.
                            if (!_customTestEnabled && _homeQuizzes.isNotEmpty) ...[
                              _RowSectionHeader(
                                title: 'Test Series',
                                subtitle: 'Published tests — start any one',
                                onViewAll: () => context.push('/student/test-series'),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                height: 128,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  itemCount: _homeQuizzes.length > 8 ? 8 : _homeQuizzes.length,
                                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                                  itemBuilder: (context, i) {
                                    final q = _homeQuizzes[i];
                                    return _TopicCard(
                                      label: (q['title'] ?? 'Test').toString(),
                                      icon: Icons.quiz_rounded,
                                      color: AppColors.accent,
                                      onTap: () => context.push('/student/test-series'),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 28),
                            ],

                            if (_customTestEnabled) ...[
                              _RowSectionHeader(
                                title: 'Custom Test Series',
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
                            ],

                            // ── Continue Training: only modules that actually have
                            // content — an empty coaching gets no section at all,
                            // not a "0 modules" placeholder. ──
                            Consumer<TrainingModuleProvider>(
                              builder: (context, provider, _) {
                                if (provider.isLoading && provider.modules.isEmpty) {
                                  return const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 16),
                                    child: SizedBox(height: 150, child: Center(child: CircularProgressIndicator())),
                                  );
                                }
                                final withContent = provider.modules.where((m) => m.topicCount > 0).toList();
                                if (withContent.isEmpty) return const SizedBox.shrink();
                                double pctOf(TrainingModule m) {
                                  final total = m.totalContentItems;
                                  if (total == 0) return 0;
                                  return (provider.getProgress(m.id)?.completedCount ?? 0) / total;
                                }
                                withContent.sort((a, b) {
                                  bool inProgress(TrainingModule m) { final p = pctOf(m); return p > 0 && p < 1; }
                                  final ai = inProgress(a), bi = inProgress(b);
                                  if (ai != bi) return ai ? -1 : 1;
                                  return 0;
                                });
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _RowSectionHeader(
                                      title: 'Continue Training',
                                      subtitle: 'Notes, videos & tests from your courses',
                                      onViewAll: _openTrainingScreen,
                                    ),
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      height: 150,
                                      child: ListView.separated(
                                        scrollDirection: Axis.horizontal,
                                        padding: const EdgeInsets.symmetric(horizontal: 16),
                                        itemCount: withContent.length,
                                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                                        itemBuilder: (context, i) {
                                          final m = withContent[i];
                                          return _ModuleCard(
                                            module: m, progress: pctOf(m),
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
                                    color: AppColors.primary,
                                    onTap: () => Navigator.push(context,
                                        MaterialPageRoute(builder: (_) => const MqttTesterScreen())),
                                  ),
                                  const SizedBox(width: 12),
                                  _TopicCard(
                                    label: 'HTTP Tester', icon: Icons.http_rounded,
                                    color: AppColors.accent,
                                    onTap: () => Navigator.push(context,
                                        MaterialPageRoute(builder: (_) => const HttpTesterScreen())),
                                  ),
                                  const SizedBox(width: 12),
                                  _TopicCard(
                                    label: 'WebSocket Tester', icon: Icons.cable_rounded,
                                    color: AppColors.primary,
                                    onTap: () => Navigator.push(context,
                                        MaterialPageRoute(builder: (_) => const WebSocketTesterScreen())),
                                  ),
                                  const SizedBox(width: 12),
                                  _TopicCard(
                                    label: 'BLE Tester', icon: Icons.bluetooth_rounded,
                                    color: AppColors.accent,
                                    onTap: () => Navigator.push(context,
                                        MaterialPageRoute(builder: (_) => const BleTesterScreen())),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 28),

                            // ── Roadmap: one muted teaser, rest collapsed — never
                            // let "Coming Soon" outnumber working features. ──
                            const _RoadmapSection(),
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
                                        // Paid tiers have a daily ceiling too now, so
                                        // is_premium no longer implies "always allowed" —
                                        // remaining_today is accurate for every tier.
                                        quizAllowed: (_subscription?['remaining_today'] as num? ?? 1) > 0,
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

                                  // Only a signed-in student HAS an institute
                                  // feed. Showing a visitor a full-width
                                  // "could not load / nothing here" wall for a
                                  // section that was never theirs is the worst
                                  // possible first impression — they get the
                                  // real content above instead.
                                  if (_isLoggedIn &&
                                      _tests.isEmpty &&
                                      _notices.isEmpty &&
                                      _results.isEmpty)
                                    _feedError != null
                                        ? _FeedErrorCard(message: _feedError!, onRetry: _loadFeed)
                                        : _EmptyFeedCard(
                                            onStartPractice: () => _openPractice(),
                                            isLoggedIn: _isLoggedIn,
                                          ),
                                ],
                              ),
                            ),

                            const _HomeFooter(),
                            const SizedBox(height: 24),
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
  /// `subscription` block from /student/feed — plan, is_premium and the
  /// month's generation quota. Null until the feed lands, or when signed out.
  final Map<String, dynamic>? subscription;
  final VoidCallback onRefresh;
  final VoidCallback onProfile;
  final VoidCallback onLogin;
  final VoidCallback onLogoTap;
  final VoidCallback onGoogleSignIn;

  const _HomeHeader({
    required this.isLoggedIn,
    required this.name,
    required this.institute,
    required this.subscription,
    required this.onRefresh,
    required this.onProfile,
    required this.onLogin,
    required this.onLogoTap,
    required this.onGoogleSignIn,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                GestureDetector(
                  onTap: onLogoTap,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: Image.asset('assets/images/logo.png', width: 40, height: 40, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: isLoggedIn
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Hi, ${Fmt.greetingName(name)} 👋',
                                style: GoogleFonts.poppins(
                                    color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
                            if (institute.isNotEmpty)
                              Text(institute,
                                  style: GoogleFonts.inter(color: Colors.white54, fontSize: 12)),
                          ],
                        )
                      // scaleDown rather than ellipsis: the brand name broke
                      // across two lines as "AltrobyteL / ab" on a narrow
                      // phone, and truncating it to "Altrobyte…" would be no
                      // better. It shrinks to fit instead.
                      : FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text('AltrobyteLab',
                              maxLines: 1,
                              softWrap: false,
                              style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600)),
                        ),
                ),
                const _WhatsAppButton(),
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
                ] else
                  OutlinedButton.icon(
                    onPressed: onGoogleSignIn,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white38),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.login_rounded, size: 17),
                    label: Text('Sign in', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600)),
                  ),
              ]),
              const SizedBox(height: 12),
              // The strip pill is left-aligned with room to spare, so the
              // plan chip rides along in the same row — an upgrade path that
              // is always on screen without costing the header any height.
              Row(children: [
                const Expanded(child: _HomeStrip()),
                if (isLoggedIn && subscription != null) ...[
                  const SizedBox(width: 12),
                  _PlanChip(subscription: subscription!),
                ],
              ]),
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
  final bool showCustomTest;
  final VoidCallback onHome;
  final VoidCallback onPractice;
  final VoidCallback onTraining;
  final VoidCallback onProfileOrLogin;

  const _SideRail({
    required this.isLoggedIn,
    required this.showCustomTest,
    required this.onHome,
    required this.onPractice,
    required this.onTraining,
    required this.onProfileOrLogin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 68,
      color: AppColors.primary,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            _RailItem(icon: Icons.home_rounded, label: 'Home', active: true, onTap: onHome),
            if (showCustomTest)
              _RailItem(icon: Icons.bolt_rounded, label: 'Custom Test', onTap: onPractice),
            _RailItem(icon: Icons.school_rounded, label: 'Training', onTap: onTraining),
            _RailItem(
                icon: Icons.video_camera_front_rounded,
                label: 'Sessions',
                onTap: () => context.push('/live-sessions')),
            _RailItem(
                icon: Icons.emoji_events_rounded,
                label: 'Challenges',
                onTap: () => context.push('/student/challenges')),
            _RailItem(
                icon: Icons.quiz_rounded,
                label: 'Test Series',
                onTap: () => context.push('/student/test-series')),
            _RailItem(
                icon: Icons.science_rounded,
                label: 'Experiments',
                onTap: () => context.push('/student/experiments')),
            _RailItem(
                icon: Icons.developer_board_rounded,
                label: 'Dev Tools',
                onTap: () => context.push('/student/dev-tools')),
            _RailItem(
                icon: Icons.record_voice_over_rounded,
                label: 'Interview',
                onTap: () => context.push('/student/mock-interview')),
            _RailItem(
                icon: Icons.work_rounded,
                label: 'Jobs',
                onTap: () => context.push('/jobs')),
            _RailItem(
                icon: Icons.event_rounded,
                label: 'Events',
                onTap: () => context.push('/events')),
            _RailItem(
                icon: Icons.sell_rounded,
                label: 'Pricing',
                onTap: () => context.push('/pricing')),
            _RailItem(
                icon: Icons.insights_rounded,
                label: 'Activity',
                onTap: () => context.push('/student/activity')),
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

/// Direct WhatsApp contact in the header — sits between the greeting and
/// the profile icon so it's reachable without hunting through menus.
class _WhatsAppButton extends StatelessWidget {
  const _WhatsAppButton();

  static const _color = Color(0xFF25D366);

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.sizeOf(context).width < 420;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: OutlinedButton.icon(
        onPressed: () async {
          final uri = Uri.parse('https://wa.me/917222977927');
          if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: _color,
          side: const BorderSide(color: _color),
          padding: EdgeInsets.symmetric(horizontal: isNarrow ? 8 : 12, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        icon: const Icon(Icons.chat_rounded, size: 16, color: _color),
        label: isNarrow
            ? const SizedBox.shrink()
            : Text('Message Us', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: _color)),
      ),
    );
  }
}

/// The only always-visible plan/upgrade affordance on the feed. Free
/// students see what they have left this month, which is the number that
/// makes upgrading feel worth it; paid students just see their tier. Tapping
/// either opens /pricing. Without this the sole upgrade path was hitting a
/// limit and getting the block sheet, or spotting "Pricing" in the side rail.
class _PlanChip extends StatelessWidget {
  final Map<String, dynamic> subscription;
  const _PlanChip({required this.subscription});

  @override
  Widget build(BuildContext context) {
    final premium = subscription['is_premium'] == true;
    final plan = (subscription['plan'] ?? 'free').toString();
    final remaining = subscription['generations_remaining'];
    final limit = subscription['monthly_generation_limit'];

    final label = premium
        ? (plan == '9999' ? 'Elite' : 'Plus')
        : (remaining is int && limit is int
            ? '$remaining/$limit series left'
            : 'Free plan');
    final color = premium ? AppColors.success : AppColors.accent;

    return InkWell(
      onTap: () => context.push('/pricing'),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.55)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(premium ? Icons.verified_rounded : Icons.bolt_rounded,
              size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(label,
              style: GoogleFonts.inter(
                  color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
          if (!premium) ...[
            const SizedBox(width: 6),
            Container(width: 1, height: 11, color: Colors.white38),
            const SizedBox(width: 6),
            Text('Upgrade',
                style: GoogleFonts.inter(
                    color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
          ],
        ]),
      ),
    );
  }
}

/// Social/group-join links + short admin updates, admin-editable via
/// /home-strip. Replaces the old fixed "Tests taken / Avg score" row —
/// falls back to the old tagline if admin hasn't configured anything yet,
/// so the header never looks broken or empty.
class _HomeStrip extends StatefulWidget {
  const _HomeStrip();

  @override
  State<_HomeStrip> createState() => _HomeStripState();
}

class _HomeStripState extends State<_HomeStrip> {
  List<dynamic> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await ApiService.getHomeStrip();
      if (!mounted) return;
      setState(() { _items = items; _loading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _openLink(String url) async {
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox(height: 20);
    if (_items.isEmpty) {
      return Text('Learn. Build. Compete in Deeptech.',
          style: GoogleFonts.inter(color: Colors.white70, fontSize: 13.5));
    }
    return _RotatingStripSlot(items: _items, onOpenLink: _openLink);
  }
}

IconData _homeStripIconFor(String? key) => switch (key) {
      'whatsapp' => Icons.chat_rounded,
      'instagram' => Icons.camera_alt_rounded,
      'linkedin' => Icons.work_rounded,
      'youtube' => Icons.play_circle_fill_rounded,
      'telegram' => Icons.send_rounded,
      'discord' => Icons.forum_rounded,
      _ => Icons.link_rounded,
    };

/// Links and updates used to stack as two separate rows, pushing the
/// header taller than it needed to be. Now they share one slot and take
/// turns — one item visible at a time, rotating every few seconds.
class _RotatingStripSlot extends StatefulWidget {
  final List<dynamic> items;
  final ValueChanged<String> onOpenLink;
  const _RotatingStripSlot({required this.items, required this.onOpenLink});

  @override
  State<_RotatingStripSlot> createState() => _RotatingStripSlotState();
}

class _RotatingStripSlotState extends State<_RotatingStripSlot> {
  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.items.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 4), (_) {
        if (!mounted) return;
        setState(() => _index = (_index + 1) % widget.items.length);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.items[_index];
    final isLink = item['item_type'] == 'link';
    final content = Container(
      key: ValueKey(_index),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(isLink ? _homeStripIconFor(item['icon']) : Icons.campaign_rounded, color: Colors.white, size: 15),
        const SizedBox(width: 8),
        Flexible(
          child: Text(item['label'] ?? '',
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: isLink
          ? InkWell(
              key: ValueKey('link-$_index'),
              borderRadius: BorderRadius.circular(10),
              onTap: () => widget.onOpenLink(item['url'] ?? ''),
              child: content,
            )
          : content,
    );
  }
}

/// Small social-proof widget floating bottom-right ("X enrolled in Y") —
/// cycles through recent real activity. Public and name-masked; the same
/// feed is available unmasked to admin via /activity-feed/admin.
class _ActivityFeedTicker extends StatefulWidget {
  const _ActivityFeedTicker();

  @override
  State<_ActivityFeedTicker> createState() => _ActivityFeedTickerState();
}

class _ActivityFeedTickerState extends State<_ActivityFeedTicker> {
  List<dynamic> _items = [];
  int _index = 0;
  Timer? _timer;
  bool _dismissed = false;
  int _shown = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await ApiService.getActivityFeed(limit: 10);
      if (!mounted || items.isEmpty) return;
      setState(() => _items = items);
      // Every 5s was relentless on a phone: whatever you were reading, a
      // card slid over it twelve times a minute. Slower, and it retires after
      // a few turns — social proof works once; after that it is just a thing
      // covering the page.
      _timer = Timer.periodic(const Duration(seconds: 11), (t) {
        if (!mounted) return;
        _shown++;
        if (_shown >= 6) {
          t.cancel();
          setState(() => _dismissed = true);
          return;
        }
        setState(() => _index = (_index + 1) % _items.length);
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty || _dismissed) return const SizedBox.shrink();
    final item = _items[_index];
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      transitionBuilder: (child, anim) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(0.15, 0), end: Offset.zero).animate(anim),
        child: FadeTransition(opacity: anim, child: child),
      ),
      child: Material(
        key: ValueKey(_index),
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        elevation: 4,
        shadowColor: Colors.black.withValues(alpha: 0.2),
        child: Container(
          constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width < 600 ? 215 : 260),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 26, height: 26,
              decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: const Icon(Icons.bolt_rounded, color: AppColors.success, size: 15),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: RichText(
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.textPrimary),
                  children: [
                    TextSpan(text: '${item['student_name']} ', style: const TextStyle(fontWeight: FontWeight.w700)),
                    TextSpan(text: '${item['action']} '),
                    TextSpan(text: item['target'], style: const TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
            InkWell(
              onTap: () => setState(() => _dismissed = true),
              child: const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(Icons.close_rounded, size: 14, color: Colors.grey),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Shown only for the tests/notices/results section when that one fetch
/// fails — the rest of the home page (Practice/Training/Dev Tools etc.)
/// keeps working regardless, since none of it depends on this call.
class _FeedErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _FeedErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(children: [
        Icon(Icons.wifi_off_rounded, size: 36, color: Colors.grey[400]),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center, style: GoogleFonts.inter(color: AppColors.textSecondary)),
        const SizedBox(height: 14),
        OutlinedButton(onPressed: onRetry, child: Text(AppLocalizations.of(context)!.studentPortalRetry)),
      ]),
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
              color: AppColors.accent.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome_rounded, color: AppColors.accent, size: 30),
          ),
          const SizedBox(height: 16),
          Text('Nothing here yet',
              style: GoogleFonts.poppins(
                  fontSize: 15.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          Text(
              'Meanwhile, check out the Test Series and Course Quizzes tab.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 18),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
            ),
            onPressed: onStartPractice,
            icon: const Icon(Icons.quiz_rounded, size: 18),
            label: Text('Explore Test Series',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13.5)),
          ),
        ],
      ),
    );
  }
}

/// Primary action row — capped at the 4 daily-use features (Practice,
/// Training, Experiments, Jobs) plus a "More" tile for everything else
/// (Mock Interview, Sessions, Events, Test Series, Pricing, Activity).
/// Keeping this to 4+1 instead of a wall of 8 icons is what makes the
/// "what do I do first" decision fast on a small screen.
class _PrimaryActionRow extends StatelessWidget {
  final bool showCustomTest;
  final VoidCallback onPractice;
  final VoidCallback onTestSeries;
  final VoidCallback onTraining;
  final VoidCallback onExperiments;
  final VoidCallback onJobs;
  final VoidCallback onMore;

  const _PrimaryActionRow({
    required this.showCustomTest,
    required this.onPractice,
    required this.onTestSeries,
    required this.onTraining,
    required this.onExperiments,
    required this.onJobs,
    required this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    final items = <(String, IconData, Color, VoidCallback)>[
      // Same slot, different destination while Custom Test is admin-only —
      // Test Series is what a student should reach for instead.
      showCustomTest
          ? ('Custom Test', Icons.bolt_rounded, AppColors.accent, onPractice)
          : ('Test Series', Icons.quiz_rounded, AppColors.accent, onTestSeries),
      ('Training', Icons.school_rounded, AppColors.primary, onTraining),
      ('Experiments', Icons.science_rounded, AppColors.accent, onExperiments),
      ('Jobs', Icons.work_rounded, AppColors.primary, onJobs),
    ];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ...items.map((item) => _QuickAccessTile(label: item.$1, icon: item.$2, color: item.$3, onTap: item.$4)),
          _QuickAccessTile(label: 'More', icon: Icons.grid_view_rounded, color: AppColors.textSecondary, onTap: onMore),
        ],
      ),
    );
  }
}

/// Sheet holding the less-frequent destinations bumped out of the primary
/// action row — still one tap away, just not competing for above-the-fold
/// space on a 375px screen.
void _showMoreActionsSheet(
  BuildContext context, {
  required VoidCallback onMockInterview,
  required VoidCallback onSessions,
  required VoidCallback onEvents,
  required VoidCallback onTestSeries,
  required VoidCallback onDevTools,
  required VoidCallback onPricing,
  required VoidCallback onActivity,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.85),
        child: SingleChildScrollView(
        child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('More', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 6),
          _MoreSheetTile(icon: Icons.record_voice_over_rounded, label: 'Mock Interview',
              onTap: () { Navigator.pop(ctx); onMockInterview(); }),
          _MoreSheetTile(icon: Icons.video_camera_front_rounded, label: 'Live Sessions / Workshops',
              onTap: () { Navigator.pop(ctx); onSessions(); }),
          _MoreSheetTile(icon: Icons.event_rounded, label: 'Events',
              onTap: () { Navigator.pop(ctx); onEvents(); }),
          _MoreSheetTile(icon: Icons.quiz_rounded, label: 'Test Series',
              onTap: () { Navigator.pop(ctx); onTestSeries(); }),
          _MoreSheetTile(icon: Icons.developer_board_rounded, label: 'Dev Tools',
              onTap: () { Navigator.pop(ctx); onDevTools(); }),
          _MoreSheetTile(icon: Icons.sell_rounded, label: 'Pricing',
              onTap: () { Navigator.pop(ctx); onPricing(); }),
          _MoreSheetTile(icon: Icons.insights_rounded, label: 'My Activity',
              onTap: () { Navigator.pop(ctx); onActivity(); }),
        ]),
        ),
        ),
      ),
    ),
  );
}

class _MoreSheetTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _MoreSheetTile({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 38, height: 38,
        decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(11)),
        child: Icon(icon, color: AppColors.primary, size: 19),
      ),
      title: Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13.5)),
      onTap: onTap,
    );
  }
}

/// Persistent bottom nav for mobile — capped at 5 items per the mobile
/// layout rules (Home, Practice, Training, Activity, Profile). Desktop/tablet
/// still uses the full [_SideRail] instead.
class _StudentBottomNav extends StatelessWidget {
  final bool isLoggedIn;
  final bool showCustomTest;
  final VoidCallback onPractice;
  final VoidCallback onTestSeries;
  final VoidCallback onTraining;
  final VoidCallback onActivity;
  final VoidCallback onProfileOrLogin;

  const _StudentBottomNav({
    required this.isLoggedIn,
    required this.showCustomTest,
    required this.onPractice,
    required this.onTestSeries,
    required this.onTraining,
    required this.onActivity,
    required this.onProfileOrLogin,
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.white,
      selectedItemColor: AppColors.accent,
      unselectedItemColor: AppColors.textSecondary,
      currentIndex: 0,
      selectedLabelStyle: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w600),
      unselectedLabelStyle: GoogleFonts.inter(fontSize: 10.5),
      onTap: (i) {
        switch (i) {
          // Slot 1 is Custom Test only while that feature is live; otherwise
          // it points at Test Series. Swapping rather than removing keeps the
          // five fixed indices this switch depends on.
          case 1: (showCustomTest ? onPractice : onTestSeries)(); break;
          case 2: onTraining(); break;
          case 3: onActivity(); break;
          case 4: onProfileOrLogin(); break;
        }
      },
      items: [
        const BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
        showCustomTest
            ? const BottomNavigationBarItem(icon: Icon(Icons.bolt_rounded), label: 'Custom Test')
            : const BottomNavigationBarItem(icon: Icon(Icons.quiz_rounded), label: 'Test Series'),
        const BottomNavigationBarItem(icon: Icon(Icons.school_rounded), label: 'Training'),
        const BottomNavigationBarItem(icon: Icon(Icons.insights_rounded), label: 'Activity'),
        BottomNavigationBarItem(
          icon: Icon(isLoggedIn ? Icons.account_circle_rounded : Icons.login_rounded),
          label: isLoggedIn ? 'Profile' : 'Join',
        ),
      ],
    );
  }
}

/// The "what should I do right now" hero — resumes an in-progress module.
class _ContinueLearningCard extends StatelessWidget {
  final TrainingModule module;
  final double pct;
  final VoidCallback onTap;
  const _ContinueLearningCard({required this.module, required this.pct, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.primaryDark],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('CONTINUE LEARNING',
                  style: GoogleFonts.inter(color: Colors.white60, fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
              const SizedBox(height: 4),
              Text(module.title,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct, minHeight: 6,
                  backgroundColor: Colors.white.withValues(alpha: 0.15),
                  valueColor: const AlwaysStoppedAnimation(AppColors.accent),
                ),
              ),
              const SizedBox(height: 6),
              Text('${(pct * 100).round()}% complete', style: GoogleFonts.inter(color: Colors.white70, fontSize: 11.5)),
            ]),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white60, size: 16),
        ]),
      ),
    );
  }
}

/// Roadmap / "Coming Soon" — capped at one muted teaser above the fold,
/// the rest tucked behind a collapsed "what's next" disclosure so they
/// never outnumber the app's actual working features.
class _RoadmapSection extends StatelessWidget {
  const _RoadmapSection();

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [
          Icon(Icons.rocket_launch_rounded, size: 13, color: Colors.grey.shade400),
          const SizedBox(width: 6),
          Text("What's next", style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.grey.shade500)),
        ]),
      ),
      const SizedBox(height: 10),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: _ComingSoonTeaser(icon: Icons.emoji_events_rounded, label: 'IoT & Embedded Hackathons'),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            iconColor: Colors.grey.shade400,
            collapsedIconColor: Colors.grey.shade400,
            title: Text('More on the roadmap',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade500)),
            childrenPadding: const EdgeInsets.only(bottom: 8),
            children: const [
              _RoadmapListItem(icon: Icons.work_rounded, label: 'Embedded/IoT Internships'),
              _RoadmapListItem(icon: Icons.business_center_rounded, label: 'Product Engineer Job Board'),
              _RoadmapListItem(icon: Icons.groups_rounded, label: 'Mentorship with Industry Engineers'),
            ],
          ),
        ),
      ),
    ]);
  }
}

class _ComingSoonTeaser extends StatelessWidget {
  final IconData icon;
  final String label;
  const _ComingSoonTeaser({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(children: [
        Icon(icon, size: 18, color: Colors.grey.shade400),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label, style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(20)),
          child: Text('SOON',
              style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.grey.shade600, letterSpacing: 0.4)),
        ),
      ]),
    );
  }
}

class _RoadmapListItem extends StatelessWidget {
  final IconData icon;
  final String label;
  const _RoadmapListItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Icon(icon, size: 16, color: Colors.grey.shade400),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: GoogleFonts.inter(fontSize: 12.5, color: Colors.grey.shade500))),
      ]),
    );
  }
}

class _QuickAccessTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _QuickAccessTile({required this.label, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 68,
        child: Column(children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 6),
          Text(label, textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }
}

/// Unstop-style "Featured" carousel — poster cards with arrow navigation,
/// spotlighting the admin's featured Live Sessions / Workshops at the top
/// of the home feed.
class _FeaturedCarousel extends StatefulWidget {
  final List<dynamic> sessions;
  final String? waNumber;
  const _FeaturedCarousel({required this.sessions, this.waNumber});

  @override
  State<_FeaturedCarousel> createState() => _FeaturedCarouselState();
}

class _FeaturedCarouselState extends State<_FeaturedCarousel> {
  final _scrollCtrl = ScrollController();
  static const _cardWidth = 210.0;
  static const _cardGap = 14.0;

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollBy(double delta) {
    if (!_scrollCtrl.hasClients) return;
    final max = _scrollCtrl.position.maxScrollExtent;
    final target = (_scrollCtrl.offset + delta).clamp(0.0, max);
    _scrollCtrl.animateTo(target, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 4, height: 20, color: AppColors.primary),
        const SizedBox(width: 10),
        Text('Featured', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 17)),
        const Spacer(),
        TextButton(
          onPressed: () => context.push('/live-sessions'),
          child: Text('View All', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12.5)),
        ),
      ]),
      const SizedBox(height: 14),
      SizedBox(
        height: 390,
        child: ClipRect(
          child: Stack(alignment: Alignment.center, children: [
          ListView.separated(
            controller: _scrollCtrl,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: widget.sessions.length,
            separatorBuilder: (_, __) => const SizedBox(width: _cardGap),
            itemBuilder: (context, i) {
              final item = widget.sessions[i] as Map<String, dynamic>;
              return SizedBox(
                width: _cardWidth,
                child: item['_type'] == 'test_series'
                    ? _FeaturedSeriesPosterCard(series: item)
                    : _FeaturedPosterCard(session: item, waNumber: widget.waNumber),
              );
            },
          ),
          if (widget.sessions.length > 1) ...[
            Positioned(
              left: 0,
              child: _CarouselArrow(icon: Icons.chevron_left_rounded, onTap: () => _scrollBy(-(_cardWidth + _cardGap) * 2)),
            ),
            Positioned(
              right: 0,
              child: _CarouselArrow(icon: Icons.chevron_right_rounded, onTap: () => _scrollBy((_cardWidth + _cardGap) * 2)),
            ),
          ],
          ]),
        ),
      ),
    ]);
  }
}

class _CarouselArrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CarouselArrow({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 3,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, color: AppColors.textPrimary, size: 22),
        ),
      ),
    );
  }
}

class _FeaturedPosterCard extends StatelessWidget {
  final Map<String, dynamic> session;
  /// So a finished session can capture the interest its button promises.
  final String? waNumber;
  const _FeaturedPosterCard({required this.session, this.waNumber});

  @override
  Widget build(BuildContext context) {
    DateTime? date;
    try {
      date = session['session_date'] != null ? DateTime.parse(session['session_date']) : null;
    } catch (_) {}
    final isPast = date != null && date.isBefore(DateTime.now());
    final hasRecording = (session['recording_url'] ?? '').toString().isNotEmpty;
    // A finished workshop with no recording used to say "Session Ended" and
    // do nothing. On a homepage where every session has passed, that is three
    // dead ends as the first thing a visitor sees. The card still earns its
    // place — it is proof these run — but the button now captures the interest
    // it was throwing away.
    final tagLabel = isPast
        ? (hasRecording ? 'Watch Recording' : 'Notify me about the next one')
        : 'Register Now';
    final tagIcon = isPast
        ? (hasRecording ? Icons.play_circle_fill_rounded : Icons.notifications_active_rounded)
        : Icons.arrow_forward_rounded;
    final isFinished = isPast && !hasRecording;
    final tagColor = isFinished
        ? const Color(0xFFE8F5E9)
        : hasRecording && isPast
            ? AppColors.primary
            : AppColors.accent;
    // Green on pale green, not white on grey: this pill is an invitation
    // now, and it has to read like one.
    final tagTextColor = isFinished ? const Color(0xFF2E7D32) : Colors.white;
    final banner = (session['banner_url'] ?? '').toString();

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      // A finished session with no recording has nothing on its detail page,
      // so sending someone there is the same dead end the old label was. This
      // opens WhatsApp with the workshop named — which also lands them in the
      // CRM as a lead, from a card that used to convert nobody.
      onTap: () {
        if (isFinished && (waNumber ?? '').isNotEmpty) {
          final phone = waNumber!.replaceAll(RegExp(r'\D'), '');
          final title = (session['title'] ?? 'your workshop').toString();
          final text = Uri.encodeComponent(
              'Hi! I missed "$title". Please let me know when the next batch is.');
          launchUrl(Uri.parse('https://wa.me/$phone?text=$text'),
              mode: LaunchMode.externalApplication);
          return;
        }
        context.push('/live-sessions/${session['id']}');
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: AspectRatio(
            aspectRatio: 3 / 4,
            // contain, not cover — these are text-heavy promo posters, so
            // cropping to fill the box was cutting off real content.
            child: banner.isNotEmpty
                ? Container(
                    color: Colors.grey.shade100,
                    child: Image.network(banner, fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const _PosterFallback()),
                  )
                : const _PosterFallback(),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: tagColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: isFinished
                ? null
                : [BoxShadow(color: tagColor.withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 3))],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(tagIcon, size: 13, color: tagTextColor),
            const SizedBox(width: 5),
            Text(tagLabel,
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: tagTextColor)),
          ]),
        ),
        const SizedBox(height: 8),
        Text(session['title'] ?? '',
            maxLines: 2, overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13.5, color: AppColors.textPrimary)),
      ]),
    );
  }
}

/// One summary "poster" for practice content — not one per quiz, since the
/// Featured row is a teaser. The cover has no banner image, so it's a
/// colored gradient with an icon, title, and description filling the
/// space (an admin-written description for a real curated series, or an
/// auto-summary of quiz/course counts otherwise) instead of sitting empty.
/// Below: a Start button to jump straight into practicing, plus a "View
/// All" link to the full Test Series page.
class _FeaturedSeriesPosterCard extends StatelessWidget {
  final Map<String, dynamic> series;
  const _FeaturedSeriesPosterCard({required this.series});

  Color _parseColor(String? hex) {
    try {
      return Color(int.parse((hex ?? '').replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _parseColor(series['color'] as String?);
    final description = (series['description'] as String?) ?? '';

    // No standalone page exists per-series yet — both Start and View All
    // land on the Test Series tab, which is the actual practice surface.
    void openStart() => context.push('/student/test-series');

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: openStart,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: AspectRatio(
              aspectRatio: 3 / 4,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, Color.lerp(color, Colors.black, 0.3)!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(clipBehavior: Clip.none, children: [
                  Positioned(
                    right: -30, bottom: -30,
                    child: Icon(Icons.fact_check_rounded, size: 190, color: Colors.white.withValues(alpha: 0.14)),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.fact_check_rounded, color: Colors.white, size: 28),
                        const SizedBox(height: 10),
                        Text(series['title'] ?? '',
                            maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(description,
                              maxLines: 4, overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.85), fontSize: 11.5, height: 1.4)),
                        ],
                      ],
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: openStart,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: AppColors.accent.withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 3))],
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.play_arrow_rounded, size: 15, color: Colors.white),
                  const SizedBox(width: 3),
                  Text('Start',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                ]),
              ),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => context.push('/student/test-series'),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              child: Text('View All',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
            ),
          ),
        ]),
      ],
    );
  }
}

class _PosterFallback extends StatelessWidget {
  const _PosterFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(child: Icon(Icons.video_camera_front_rounded, color: Colors.white, size: 40)),
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
            colors: [AppColors.primary, AppColors.primaryLight],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
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
    final isPlacement = notice['category'] == 'placement';
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
                    color: isVideo ? AppColors.error : AppColors.warning,
                    size: 20,
                  ),
                ),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (isPlacement) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      margin: const EdgeInsets.only(bottom: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.work_rounded, size: 11, color: AppColors.primary),
                        const SizedBox(width: 3),
                        Text('PLACEMENT',
                            style: GoogleFonts.inter(
                                fontSize: 9.5, fontWeight: FontWeight.w700,
                                color: AppColors.primary, letterSpacing: 0.3)),
                      ]),
                    ),
                  ],
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

/// Bottom-of-page site footer — brand, quick links, social icons, copyright.
/// The home feed previously just stopped after the last content section with
/// no closing element at all.
class _HomeFooter extends StatefulWidget {
  const _HomeFooter();

  @override
  State<_HomeFooter> createState() => _HomeFooterState();
}

class _HomeFooterState extends State<_HomeFooter> {
  Map<String, dynamic> _links = {};

  @override
  void initState() {
    super.initState();
    ApiService.getCompanySocialLinks().then((links) {
      if (mounted) setState(() => _links = links);
    }).catchError((_) {});
  }

  IconData _iconFor(String platform) {
    switch (platform) {
      case 'instagram': return Icons.camera_alt_rounded;
      case 'youtube': return Icons.play_circle_fill_rounded;
      case 'linkedin': return Icons.business_center_rounded;
      case 'twitter': return Icons.alternate_email_rounded;
      case 'facebook': return Icons.facebook_rounded;
      default: return Icons.link_rounded;
    }
  }

  Future<void> _openLink(String url) async {
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final activeSocials = _links.entries.where((e) => (e.value as String? ?? '').isNotEmpty).toList();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
      ),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: Image.asset('assets/images/logo.png', width: 32, height: 32, fit: BoxFit.cover),
          ),
          const SizedBox(width: 8),
          Text('AltrobyteLab', style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 6),
        Text('Learn. Build. Compete in Deeptech.',
            style: GoogleFonts.inter(color: Colors.white54, fontSize: 11.5)),
        const SizedBox(height: 20),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 18, runSpacing: 8,
          children: [
            _FooterLink('About Us', () => context.push('/about')),
            _FooterLink('Company', () => context.push('/company')),
            _FooterLink('Partner With Us', () => context.push('/partner')),
            _FooterLink('Pricing', () => context.push('/pricing')),
            _FooterLink('Contact Us', () => context.push('/contact')),
            _FooterLink('Terms & Conditions', () => context.push('/terms')),
            _FooterLink('Refunds & Cancellations', () => context.push('/refunds')),
          ],
        ),
        if (activeSocials.isNotEmpty) ...[
          const SizedBox(height: 20),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            children: activeSocials.map((e) => IconButton(
              onPressed: () => _openLink(e.value as String),
              icon: Icon(_iconFor(e.key), color: Colors.white, size: 18),
              style: IconButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: 0.1)),
            )).toList(),
          ),
        ],
        const SizedBox(height: 20),
        Container(height: 1, color: Colors.white12),
        const SizedBox(height: 14),
        Text('© ${DateTime.now().year} AltrobyteLab. All rights reserved.',
            style: GoogleFonts.inter(color: Colors.white38, fontSize: 10.5)),
        const SizedBox(height: 4),
        Text('AltrobyteLab is operated by Altrobyte Automation Private Limited.',
            style: GoogleFonts.inter(color: Colors.white38, fontSize: 10.5)),
      ]),
    );
  }
}

class _FooterLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _FooterLink(this.label, this.onTap);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Text(label, style: GoogleFonts.inter(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w500)),
    );
  }
}

/// Entry point to the roadmap — the first thing on the homepage.
///
/// It has to carry three facts before a tap: this is long, it is structured,
/// and it ends somewhere worth reaching. A plain menu row carries none of them.
///
/// On a wide screen the facts and the button sit in the empty right-hand half
/// rather than below, so the card fills the width it already occupies instead
/// of growing taller and pushing everything else down the page.
class _RoadmapCard extends StatelessWidget {
  final VoidCallback onTap;
  final Map<String, dynamic> facts;
  const _RoadmapCard({required this.onTap, this.facts = const {}});

  String _f(String k) => '${facts[k] ?? ''}';

  static const _levels = [
    ('Foundation', Color(0xFF66BB6A)),
    ('Intermediate', Color(0xFF42A5F5)),
    ('Advanced', Color(0xFFAB47BC)),
    ('Industry', Color(0xFFFF9800)),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0B2450), Color(0xFF16407F), Color(0xFF1565C0)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0B2450).withValues(alpha: 0.25),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: LayoutBuilder(builder: (context, c) {
            final wide = c.maxWidth > 720;
            final left = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _badge(),
                  const SizedBox(height: 14),
                  Text('Product Engineering Program',
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          height: 1.2)),
                  const SizedBox(height: 3),
                  Text('The full roadmap — every stage, in order',
                      style: GoogleFonts.inter(
                          color: const Color(0xFFFFC107),
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text(
                      'Build 3-4 real industrial products — PCB in your hand, '
                      'cloud, AI, portfolio',
                      style: GoogleFonts.inter(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 12.5,
                          height: 1.4)),
                  const SizedBox(height: 16),
                  _ladder(),
                ]);

            final right = Column(
                crossAxisAlignment:
                    wide ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Wrap(
                    spacing: 14,
                    runSpacing: 6,
                    alignment: wide ? WrapAlignment.end : WrapAlignment.start,
                    children: [
                      if (_f('duration').isNotEmpty)
                        _MiniFact(
                            icon: Icons.schedule_rounded, label: _f('duration')),
                      if (_f('milestones').isNotEmpty)
                        _MiniFact(
                            icon: Icons.checklist_rounded,
                            label: '${_f('milestones')} milestones'),
                      if (_f('start').isNotEmpty)
                        _MiniFact(
                            icon: Icons.event_available_rounded,
                            label: _f('start'),
                            highlight: true),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _button(wide),
                ]);

            if (!wide) {
              return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [left, const SizedBox(height: 16), right]);
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(flex: 3, child: left),
                const SizedBox(width: 28),
                Flexible(flex: 2, child: right),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _badge() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFFFC107),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text('FLAGSHIP PROGRAM',
            style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.7,
                color: const Color(0xFF3E2700))),
      );

  Widget _ladder() => Row(children: [
        for (final l in _levels) ...[
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                  height: 3,
                  decoration: BoxDecoration(
                      color: l.$2, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 5),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(l.$1,
                    style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.75))),
              ),
            ]),
          ),
          const SizedBox(width: 6),
        ],
      ]);

  Widget _button(bool wide) => Container(
        width: wide ? null : double.infinity,
        padding: EdgeInsets.symmetric(horizontal: wide ? 22 : 0, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (!wide) const Spacer(),
          const Icon(Icons.route_rounded, size: 17, color: Color(0xFF0B2450)),
          const SizedBox(width: 7),
          Text('Open the roadmap',
              style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0B2450))),
          if (!wide) const Spacer(),
        ]),
      );
}

class _MiniFact extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool highlight;
  const _MiniFact({required this.icon, required this.label, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    final color = highlight ? const Color(0xFFFFC107) : Colors.white;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: color.withValues(alpha: highlight ? 1 : 0.8)),
      const SizedBox(width: 4),
      Text(label,
          style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: highlight ? FontWeight.w700 : FontWeight.w400,
              color: color.withValues(alpha: highlight ? 1 : 0.88))),
    ]);
  }
}
