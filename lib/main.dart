import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/brand_provider.dart';
import 'providers/institute_provider.dart';
import 'providers/language_provider.dart';
import 'providers/test_provider.dart';
import 'providers/training_module_provider.dart';
import 'services/error_reporter.dart';
import 'screens/login_screen.dart';
import 'screens/main_layout.dart';
import 'screens/dashboard_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/students/students_screen.dart';
import 'screens/students/student_detail_screen.dart';
import 'screens/test_generator/test_generator_screen.dart';
import 'screens/test_generator/test_attempt_screen.dart';
import 'screens/attendance/attendance_screen.dart';
import 'screens/fees/fee_management_screen.dart';
import 'screens/analytics/analytics_screen.dart';
import 'screens/batches/batches_screen.dart';
import 'screens/broadcast/broadcast_screen.dart';
import 'screens/role_selection_screen.dart';
import 'screens/branded_landing_screen.dart';
import 'screens/student/student_login_screen.dart';
import 'screens/student/student_home_screen.dart';
import 'screens/student/student_onboarding_screen.dart';
import 'screens/student/student_training_screen.dart';
import 'screens/tools/dev_tools_hub_screen.dart';
import 'screens/manager/manager_login_screen.dart';
import 'screens/training_modules/training_modules_screen.dart';
import 'screens/experiments/experiments_screen.dart';
import 'screens/experiments/student_experiments_screen.dart';
import 'screens/student/student_test_series_screen.dart';
import 'screens/student/student_activity_screen.dart';
import 'screens/jobs/job_updates_screen.dart';
import 'screens/jobs/job_detail_screen.dart';
import 'screens/jobs/job_updates_admin_screen.dart';
import 'screens/events/events_screen.dart';
import 'screens/events/event_detail_screen.dart';
import 'screens/events/events_admin_screen.dart';
import 'screens/live_sessions/live_sessions_screen.dart';
import 'screens/live_sessions/live_session_detail_screen.dart';
import 'screens/live_sessions/live_sessions_admin_screen.dart';
import 'screens/students/platform_users_screen.dart';
import 'screens/enquiries/partner_enquiry_screen.dart';
import 'screens/enquiries/enquiries_admin_screen.dart';
import 'screens/mock_interview/mock_interview_screen.dart';
import 'screens/pricing/pricing_screen.dart';
import 'screens/program_page.dart';
import 'screens/book_call_screen.dart';
import 'screens/admin/bookings_screen.dart';
import 'screens/admin/errors_screen.dart';
import 'screens/student/roadmap_screen.dart';
import 'screens/student/what_if_screen.dart';
import 'screens/student/test_series_page.dart';
import 'screens/admin/showcase_admin_screen.dart';
import 'screens/admin/roadmap_admin_screen.dart';
import 'screens/admin/crm_screen.dart';
import 'screens/admin/wa_messages_screen.dart';
import 'screens/pricing/pricing_admin_screen.dart';
import 'screens/company/company_profile_screen.dart';
import 'screens/company/company_page_view_screen.dart';
import 'screens/company/company_items_screen.dart';
import 'screens/challenges/student_challenges_screen.dart';
import 'screens/challenges/challenges_admin_screen.dart';
import 'screens/home_strip/home_strip_admin_screen.dart';
import 'screens/home_strip/activity_feed_admin_screen.dart';
import 'screens/super_admin/super_admin_login_screen.dart';
import 'screens/super_admin/super_admin_dashboard_screen.dart';
import 'screens/super_admin/commission_tracker_screen.dart';
import 'screens/super_admin/super_admin_settings_screen.dart';
import 'screens/audit_logs_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/auth/whatsapp_login_screen.dart';
import 'screens/plan_upgrade_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Without this, Flutter web defaults to hash-based URLs (/#/live-sessions/1),
  // so a shared link built as a clean path (/live-sessions/1) — which is what
  // every share/registration/receipt link in this app generates — loads with
  // an empty route fragment and silently falls back to home. This is why
  // shared workshop/course links were landing on the home page instead of
  // the intended page.
  usePathUrlStrategy();

  // Anything Flutter catches on the way to the red screen. Without this, a
  // widget that throws for one person on one browser is something nobody ever
  // hears about — which is how every problem this week was found: by somebody
  // hitting it and saying so.
  final previousOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    previousOnError?.call(details);
    ErrorReporter.send(
      details.library ?? 'flutter',
      details.exception,
      details.stack,
      context: details.context?.toString(),
    );
  };

  runZonedGuarded(() async {
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    } catch (e, st) {
      // Google Sign-In just won't be available if this fails — the rest of
      // the app (WhatsApp/password login, all other features) must not be
      // blocked by a Firebase bootstrap error.
      debugPrint('Firebase.initializeApp failed: $e\n$st');
    }
    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()..tryAutoLogin()),
          ChangeNotifierProvider(create: (_) => BrandProvider()),
          ChangeNotifierProvider(create: (_) => InstituteProvider()),
          ChangeNotifierProvider(create: (_) => TestProvider()),
          ChangeNotifierProvider(create: (_) => TrainingModuleProvider()),
          ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ],
        child: const AltrobyteLabApp(),
      ),
    );
  }, (error, stack) {
    debugPrint('Uncaught zone error: $error\n$stack');
    ErrorReporter.send('zone', error, stack);
  });
}

class AltrobyteLabApp extends StatefulWidget {
  const AltrobyteLabApp({super.key});

  @override
  State<AltrobyteLabApp> createState() => _AltrobyteLabAppState();
}

class _AltrobyteLabAppState extends State<AltrobyteLabApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    _router = GoRouter(
      initialLocation: '/',
      redirect: (ctx, state) {
        // Wait for SharedPreferences restore before any redirect decision.
        if (!auth.isInitialized) return null;

        final loggedIn = auth.isLoggedIn;
        final loc = state.matchedLocation;

        // Auto-redirect already-logged-in educator/manager away from root
        if (loc == '/' && loggedIn) {
          // An account that is both — an institute admin who also owns the
          // platform — belongs in its own dashboard, with the platform pages
          // a click away in the sidebar. Only a pure super admin, which has
          // no institute of its own, lands on the platform dashboard.
          if (auth.isSuperAdmin && auth.instituteId == null) {
            return '/super/dashboard';
          }
          return '/dashboard';
        }

        // Only the educator/manager shell routes are login-protected.
        const protected = [
          '/dashboard', '/students', '/batches', '/test-generator',
          '/training-modules', '/experiments', '/attendance', '/fees', '/analytics',
          '/broadcast', '/settings',
          '/live-sessions-admin', '/events-admin', '/jobs-admin', '/enquiries-admin', '/pricing-admin',
          '/platform-users', '/challenges-admin', '/home-strip-admin', '/activity-feed-admin',
          '/showcase-admin',
          '/curriculum-admin',
          '/crm',
          '/wa-messages',
          '/bookings',
          '/errors',
          // Platform pages. They were missing here, so a signed-out visitor
          // reached them and got an empty screen instead of a login page —
          // the backend refuses the data either way, but silence is a worse
          // answer than being asked to sign in.
          '/super',
        ];
        // '/super' covers the platform pages, but '/super/login' is the way
        // in — protecting it would redirect the login page to a login page.
        final isProtected = loc != '/super/login' &&
            protected.any((p) => loc == p || loc.startsWith('$p/'));

        // Educator / Manager login page
        if (loc == '/login') return loggedIn ? '/dashboard' : null;

        if (isProtected && !loggedIn) return '/login';

        // Manager cannot access broadcast or settings
        if (loggedIn && auth.isManager && (loc == '/broadcast' || loc == '/settings')) {
          return '/dashboard';
        }

        // Everything else (/, /:slug branded landing, student/super/manager/test) is public.
        return null;
      },
      // Without this an unmatched URL fails silently and looks like a
      // redirect to the homepage, which is exactly what made a broken link
      // impossible to diagnose. Say what happened and offer a way out.
      errorBuilder: (context, state) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.link_off_rounded, size: 44),
              const SizedBox(height: 12),
              Text('This page does not exist',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(state.uri.toString(), textAlign: TextAlign.center),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () => context.go('/'),
                child: const Text('Go home'),
              ),
            ]),
          ),
        ),
      ),
      refreshListenable: auth,
      routes: [
        // Unified homepage — public feed for everyone, personalized when
        // logged in. Login is contextual (only gates specific actions),
        // never a wall in front of the content itself.
        GoRoute(
          path: '/',
          builder: (_, __) => const StudentHomeScreen(),
        ),
        // Student login / register
        GoRoute(
          path: '/join',
          builder: (_, __) => const RoleSelectionScreen(),
        ),
        // Company Profile — public marketing site, no login.
        GoRoute(path: '/company', builder: (_, __) => const CompanyProfileScreen()),
        GoRoute(
          path: '/about',
          builder: (_, __) => const CompanyPageViewScreen(slug: 'about', fallbackTitle: 'About AltrobyteLab'),
        ),
        GoRoute(
          path: '/founder',
          builder: (_, __) => const CompanyPageViewScreen(slug: 'founder', fallbackTitle: 'Founder & Team'),
        ),
        GoRoute(
          path: '/about-app',
          builder: (_, __) => const CompanyPageViewScreen(slug: 'app', fallbackTitle: 'About the App'),
        ),
        GoRoute(
          path: '/contact',
          builder: (_, __) => const CompanyPageViewScreen(slug: 'contact', fallbackTitle: 'Contact Us'),
        ),
        GoRoute(
          path: '/terms',
          builder: (_, __) => const CompanyPageViewScreen(slug: 'terms', fallbackTitle: 'Terms & Conditions'),
        ),
        GoRoute(
          // Required before the Play Store will accept a listing, and linked
          // from it. Without its own route it fell through to the branded
          // landing page, which answered a policy URL with a stranger's
          // college page.
          path: '/privacy',
          builder: (_, __) => const CompanyPageViewScreen(
              slug: 'privacy', fallbackTitle: 'Privacy Policy'),
        ),
        GoRoute(
          path: '/refunds',
          builder: (_, __) => const CompanyPageViewScreen(slug: 'refunds', fallbackTitle: 'Refunds & Cancellations'),
        ),
        GoRoute(
          path: '/placements',
          builder: (_, __) => const CompanyItemsScreen(category: 'placed', title: 'Placed Profiles', icon: Icons.emoji_events_rounded),
        ),
        GoRoute(
          path: '/institutes',
          builder: (_, __) => const CompanyItemsScreen(category: 'institute', title: 'Affiliated Institutes', icon: Icons.school_rounded),
        ),
        GoRoute(
          path: '/clients',
          builder: (_, __) => const CompanyItemsScreen(category: 'client', title: 'Clients', icon: Icons.handshake_rounded),
        ),
        GoRoute(
          path: '/services',
          builder: (_, __) => const CompanyItemsScreen(category: 'service', title: 'Services', icon: Icons.design_services_rounded),
        ),
        GoRoute(
          path: '/products',
          builder: (_, __) => const CompanyItemsScreen(category: 'product', title: 'Products', icon: Icons.widgets_rounded),
        ),
        GoRoute(
          path: '/blog',
          builder: (_, __) => const CompanyItemsScreen(category: 'blog', title: 'Blog', icon: Icons.article_rounded),
        ),
        // Job Updates — public, no login.
        GoRoute(path: '/jobs', builder: (_, __) => const JobUpdatesScreen()),
        GoRoute(
          path: '/jobs/:id',
          builder: (context, state) => JobDetailScreen(
              jobId: int.tryParse(state.pathParameters['id'] ?? '0') ?? 0),
        ),
        // Events — public, no login.
        GoRoute(path: '/events', builder: (_, __) => const EventsScreen()),
        GoRoute(
          path: '/events/:id',
          builder: (context, state) => EventDetailScreen(
              eventId: int.tryParse(state.pathParameters['id'] ?? '0') ?? 0),
        ),
        // Live Sessions / Workshops — public, no login.
        GoRoute(path: '/live-sessions', builder: (_, __) => const LiveSessionsScreen()),
        GoRoute(
          path: '/live-sessions/:id',
          builder: (context, state) => LiveSessionDetailScreen(
              sessionId: int.tryParse(state.pathParameters['id'] ?? '0') ?? 0),
        ),
        // Partner enquiry — public, no login.
        GoRoute(path: '/partner', builder: (_, __) => const PartnerEnquiryScreen()),
        // Pricing — public, no login.
        GoRoute(path: '/pricing', builder: (_, __) => const PricingScreen()),
        // Deliberately not linked from anywhere. Its URL is the product: it is
        // sent directly to someone who asked, while the public pricing page
        // still quotes programmes on request.
        GoRoute(path: '/program', builder: (_, __) => const ProgramPage()),
        // Public and shareable, like the roadmap: the whole point is that a
        // link turns into a time in the diary without anyone signing in.
        GoRoute(path: '/book', builder: (_, __) => const BookCallScreen()),
        GoRoute(path: '/bookings', builder: (_, __) => const BookingsScreen()),
        GoRoute(path: '/errors', builder: (_, __) => const ErrorsScreen()),
        // Admin: Top Stories + Lab Setups. Login-protected via the list above.
        GoRoute(
            path: '/showcase-admin',
            builder: (_, __) => const ShowcaseAdminScreen()),
        GoRoute(
            path: '/curriculum-admin',
            builder: (_, __) => const RoadmapAdminScreen()),
        GoRoute(path: '/crm', builder: (_, __) => const CrmScreen()),
        GoRoute(
            path: '/wa-messages',
            builder: (_, __) => const WaMessagesScreen()),
        // Public on purpose: the roadmap is the pitch, so it must be
        // shareable as a link to someone who has never signed in.
        // Public like the roadmap: the argument for a path is no use behind
        // a login when the people who most need it have not signed up yet.
        GoRoute(path: '/what-if', builder: (_, __) => const WhatIfScreen()),
        // Public: the link is posted in class WhatsApp groups, so it has to
        // render for somebody who has never signed in.
        GoRoute(
          path: '/test-series/:id',
          builder: (_, state) => TestSeriesPage(
              seriesId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0),
        ),
        GoRoute(
          path: '/roadmap/:slug',
          // ?present=1 for showing this on a screen to a room: no fees, the
          // stages closed so they can be opened one at a time, and type that
          // survives a projector.
          builder: (_, state) => RoadmapScreen(
            slug: state.pathParameters['slug'] ?? '',
            present: state.uri.queryParameters['present'] == '1',
          ),
        ),
        GoRoute(
          path: '/student/login',
          builder: (_, __) => const StudentLoginScreen(),
        ),
        GoRoute(
          path: '/student/home',
          builder: (_, __) => const StudentHomeScreen(),
        ),
        GoRoute(
          path: '/student/experiments',
          builder: (_, __) => const StudentExperimentsScreen(),
        ),
        GoRoute(
          path: '/student/test-series',
          builder: (_, __) => const StudentTestSeriesScreen(),
        ),
        GoRoute(
          path: '/student/mock-interview',
          builder: (_, __) => const MockInterviewScreen(),
        ),
        GoRoute(
          path: '/student/activity',
          builder: (_, __) => const StudentActivityScreen(),
        ),
        GoRoute(
          path: '/student/onboarding',
          builder: (_, __) => const StudentOnboardingScreen(),
        ),
        GoRoute(
          path: '/student/training',
          builder: (_, __) => const StudentTrainingScreen(),
        ),
        GoRoute(
          path: '/student/dev-tools',
          builder: (_, __) => const DevToolsHubScreen(),
        ),
        GoRoute(
          path: '/student/challenges',
          builder: (_, __) => const StudentChallengesScreen(),
        ),
        // Manager login
        GoRoute(
          path: '/manager/login',
          builder: (_, __) => const ManagerLoginScreen(),
        ),
        // Super admin routes (self-guarded)
        GoRoute(
          path: '/super/login',
          builder: (_, __) => const SuperAdminLoginScreen(),
        ),
        GoRoute(
          path: '/super/dashboard',
          builder: (_, __) => const SuperAdminDashboardScreen(),
        ),
        GoRoute(
          path: '/super/commissions',
          builder: (_, __) => const CommissionTrackerScreen(),
        ),
        GoRoute(
          path: '/super/settings',
          builder: (_, __) => const SuperAdminSettingsScreen(),
        ),
        GoRoute(
          path: '/super/job-updates',
          builder: (_, __) => const JobUpdatesAdminScreen(),
        ),
        GoRoute(
          path: '/super/events',
          builder: (_, __) => const EventsAdminScreen(),
        ),
        GoRoute(
          path: '/super/live-sessions',
          builder: (_, __) => const LiveSessionsAdminScreen(),
        ),
        GoRoute(
          path: '/super/enquiries',
          builder: (_, __) => const EnquiriesAdminScreen(),
        ),
        GoRoute(
          path: '/super/pricing',
          builder: (_, __) => const PricingAdminScreen(),
        ),
        GoRoute(
          path: '/super/audits/:instituteId',
          builder: (context, state) {
            final id = int.tryParse(state.pathParameters['instituteId'] ?? '0') ?? 0;
            return AuditLogsScreen(instituteId: id, isSuperAdmin: true);
          },
        ),
        GoRoute(
          path: '/audits/:instituteId',
          builder: (context, state) {
            final id = int.tryParse(state.pathParameters['instituteId'] ?? '0') ?? 0;
            return AuditLogsScreen(instituteId: id, isSuperAdmin: false);
          },
        ),
        // Educator (admin) login
        GoRoute(
          path: '/login',
          builder: (_, __) => const LoginScreen(),
        ),
        GoRoute(
          path: '/forgot-password',
          builder: (_, __) => const ForgotPasswordScreen(),
        ),
        GoRoute(
          path: '/whatsapp-login',
          builder: (_, __) => const WhatsappLoginScreen(),
        ),
        GoRoute(
          path: '/plans',
          builder: (_, __) => const PlanUpgradeScreen(),
        ),
        // Public test route
        GoRoute(
          path: '/test/:id',
          builder: (_, state) => TestAttemptScreen(
              testId: int.parse(state.pathParameters['id'] ?? '0')),
        ),
        // Protected shell — IndexedStack keeps every tab's state alive, so
        // switching tabs never rebuilds/refetches a screen.
        StatefulShellRoute.indexedStack(
          builder: (_, __, navigationShell) =>
              MainLayout(navigationShell: navigationShell),
          branches: [
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/dashboard',
                builder: (_, __) => const DashboardScreen(),
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/students',
                builder: (_, __) => const StudentsScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (_, state) => StudentDetailScreen(
                        studentId:
                            int.parse(state.pathParameters['id'] ?? '0')),
                  ),
                ],
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/platform-users',
                builder: (_, __) => const PlatformUsersScreen(),
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/batches',
                builder: (_, __) => const BatchesScreen(),
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/test-generator',
                builder: (_, __) => const TestGeneratorScreen(),
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/training-modules',
                builder: (_, __) => const TrainingModulesScreen(),
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/experiments',
                builder: (_, __) => const ExperimentsScreen(),
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/live-sessions-admin',
                builder: (_, __) => const LiveSessionsAdminScreen(),
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/challenges-admin',
                builder: (_, __) => const ChallengesAdminScreen(),
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/home-strip-admin',
                builder: (_, __) => const HomeStripAdminScreen(),
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/activity-feed-admin',
                builder: (_, __) => const ActivityFeedAdminScreen(),
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/events-admin',
                builder: (_, __) => const EventsAdminScreen(),
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/jobs-admin',
                builder: (_, __) => const JobUpdatesAdminScreen(),
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/enquiries-admin',
                builder: (_, __) => const EnquiriesAdminScreen(),
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/pricing-admin',
                builder: (_, __) => const PricingAdminScreen(),
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/attendance',
                builder: (_, __) => const AttendanceScreen(),
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/fees',
                builder: (_, __) => const FeeManagementScreen(),
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/analytics',
                builder: (_, __) => const AnalyticsScreen(),
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/broadcast',
                builder: (_, __) => const BroadcastScreen(),
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/settings',
                builder: (_, __) => const SettingsScreen(),
              ),
            ]),
          ],
        ),
        // Per-institute branded landing (PWA). Must be LAST so explicit
        // routes above win; only bare single-segment slugs reach here.
        GoRoute(
          path: '/:slug',
          builder: (_, state) =>
              BrandedLandingScreen(slug: state.pathParameters['slug']!),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    return MaterialApp.router(
      title: 'AltrobyteLab',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      locale: lang.locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: _router,
    );
  }
}
