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
import 'screens/login_screen.dart' deferred as d0;
import 'screens/main_layout.dart' deferred as d1;
import 'screens/dashboard_screen.dart' deferred as d2;
import 'screens/settings_screen.dart' deferred as d3;
import 'screens/students/students_screen.dart' deferred as d4;
import 'screens/students/student_detail_screen.dart' deferred as d5;
import 'screens/test_generator/test_generator_screen.dart' deferred as d6;
import 'screens/test_generator/test_attempt_screen.dart' deferred as e0;
import 'screens/attendance/attendance_screen.dart' deferred as d7;
import 'screens/fees/fee_management_screen.dart' deferred as d8;
import 'screens/invoices/invoices_screen.dart' deferred as d9;
import 'screens/enrolment/enrol_screen.dart' deferred as e1;
import 'screens/connect/connect_vscode_screen.dart' deferred as e2;
import 'screens/connect/download_app_screen.dart' deferred as e3;
import 'screens/enrolment/enrolment_forms_screen.dart' deferred as d10;
import 'screens/trainer/trainer_admin_screen.dart' deferred as d11;
import 'screens/trainer/trainer_usage_screen.dart' deferred as d12;
import 'screens/analytics/analytics_screen.dart' deferred as d13;
import 'screens/batches/batches_screen.dart' deferred as d14;
import 'screens/broadcast/broadcast_screen.dart' deferred as d15;
import 'screens/role_selection_screen.dart' deferred as d16;
import 'screens/branded_landing_screen.dart' deferred as d17;
import 'screens/student/student_home_screen.dart';
import 'screens/student/student_onboarding_screen.dart';
import 'screens/student/student_training_screen.dart' deferred as e4;
import 'screens/tools/dev_tools_hub_screen.dart' deferred as d19;
import 'screens/manager/manager_login_screen.dart' deferred as d20;
import 'screens/training_modules/training_modules_screen.dart' deferred as d21;
import 'screens/experiments/experiments_screen.dart' deferred as d22;
import 'screens/experiments/student_experiments_screen.dart' deferred as e7;
import 'screens/student/student_test_series_screen.dart' deferred as e5;
import 'screens/student/student_activity_screen.dart' deferred as e6;
import 'screens/jobs/job_updates_screen.dart' deferred as e8;
import 'screens/jobs/job_detail_screen.dart' deferred as e9;
import 'screens/jobs/job_updates_admin_screen.dart' deferred as d23;
import 'screens/events/events_screen.dart' deferred as e10;
import 'screens/events/event_detail_screen.dart' deferred as e11;
import 'screens/events/events_admin_screen.dart' deferred as d24;
import 'screens/live_sessions/live_sessions_screen.dart' deferred as e12;
import 'screens/live_sessions/live_session_detail_screen.dart' deferred as e13;
import 'screens/live_sessions/live_sessions_admin_screen.dart' deferred as d25;
import 'screens/students/platform_users_screen.dart' deferred as d26;
import 'screens/enquiries/partner_enquiry_screen.dart' deferred as e14;
import 'screens/enquiries/enquiries_admin_screen.dart' deferred as d27;
import 'screens/mock_interview/mock_interview_screen.dart' deferred as e15;
import 'screens/pricing/pricing_screen.dart' deferred as e16;
import 'screens/learn/learn_screen.dart';
import 'screens/learn/sign_in_screen.dart';
import 'screens/learn/unlock_screen.dart';
import 'screens/program_page.dart' deferred as e17;
import 'screens/plans_page.dart' deferred as e18;
import 'screens/book_call_screen.dart' deferred as e19;
import 'screens/admin/bookings_screen.dart' deferred as d28;
import 'screens/admin/errors_screen.dart' deferred as d29;
import 'screens/student/roadmap_screen.dart' deferred as e20;
import 'screens/student/what_if_screen.dart' deferred as e21;
import 'screens/student/scholarship_screen.dart' deferred as e22;
import 'services/page_seo.dart';
import 'screens/admin/testimonials_admin_screen.dart' deferred as d30;
import 'screens/admin/company_items_admin_screen.dart' deferred as d31;
import 'screens/admin/scholarship_admin_screen.dart' deferred as d32;
import 'screens/student/test_series_page.dart' deferred as e23;
import 'screens/admin/showcase_admin_screen.dart' deferred as d33;
import 'screens/admin/roadmap_admin_screen.dart' deferred as d34;
import 'screens/admin/crm_screen.dart' deferred as d35;
import 'screens/admin/access_screen.dart' deferred as d36;
import 'screens/admin/scholars_screen.dart' deferred as d37;
import 'screens/admin/wa_messages_screen.dart' deferred as d38;
import 'screens/pricing/pricing_admin_screen.dart' deferred as d39;
import 'screens/company/company_profile_screen.dart' deferred as d40;
import 'screens/company/company_page_view_screen.dart' deferred as e24;
import 'screens/company/company_items_screen.dart' deferred as d41;
import 'screens/challenges/student_challenges_screen.dart' deferred as e25;
import 'screens/challenges/challenges_admin_screen.dart' deferred as d42;
import 'screens/home_strip/home_strip_admin_screen.dart' deferred as d43;
import 'screens/home_strip/activity_feed_admin_screen.dart' deferred as d44;
import 'screens/super_admin/super_admin_login_screen.dart' deferred as d45;
import 'screens/super_admin/super_admin_dashboard_screen.dart' deferred as d46;
import 'screens/super_admin/commission_tracker_screen.dart' deferred as d47;
import 'screens/super_admin/super_admin_settings_screen.dart' deferred as d48;
import 'screens/audit_logs_screen.dart' deferred as d49;
import 'screens/auth/forgot_password_screen.dart' deferred as d50;
import 'screens/auth/whatsapp_login_screen.dart' deferred as d51;
import 'screens/plan_upgrade_screen.dart' deferred as d52;
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
        // Every navigation passes through here, which makes it the one place
        // that always knows the current route. The app is one index.html for
        // twenty-five sitemap URLs, so without this they all carry the same
        // title and read as copies of each other to a search engine.
        PageSeo.apply(state.matchedLocation);

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
          '/access',
          '/scholars',
          '/invoices',
          '/enrolment-forms',
          '/trainer-admin',
          '/trainer-usage',
          '/reviews-admin',
          '/company-admin',
          '/scholarship-admin',
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
        if (loggedIn && auth.isManager && (loc == '/broadcast' || loc == '/settings' || loc == '/trainer-admin')) {
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
          builder: (_, __) => _Lazy(d16.loadLibrary, () => d16.RoleSelectionScreen()),
        ),
        // Company Profile — public marketing site, no login.
        GoRoute(path: '/company', builder: (_, __) => _Lazy(d40.loadLibrary, () => d40.CompanyProfileScreen())),
        GoRoute(
          path: '/about',
          builder: (_, __) => _Lazy(e24.loadLibrary, () => e24.CompanyPageViewScreen(slug: 'about', fallbackTitle: 'About AltrobyteLab')),
        ),
        GoRoute(
          path: '/founder',
          builder: (_, __) => _Lazy(e24.loadLibrary, () => e24.CompanyPageViewScreen(slug: 'founder', fallbackTitle: 'Founder & Team')),
        ),
        GoRoute(
          path: '/about-app',
          builder: (_, __) => _Lazy(e24.loadLibrary, () => e24.CompanyPageViewScreen(slug: 'app', fallbackTitle: 'About the App')),
        ),
        GoRoute(
          path: '/contact',
          builder: (_, __) => _Lazy(e24.loadLibrary, () => e24.CompanyPageViewScreen(slug: 'contact', fallbackTitle: 'Contact Us')),
        ),
        GoRoute(
          path: '/terms',
          builder: (_, __) => _Lazy(e24.loadLibrary, () => e24.CompanyPageViewScreen(slug: 'terms', fallbackTitle: 'Terms & Conditions')),
        ),
        GoRoute(
          // Required before the Play Store will accept a listing, and linked
          // from it. Without its own route it fell through to the branded
          // landing page, which answered a policy URL with a stranger's
          // college page.
          path: '/privacy',
          builder: (_, __) => _Lazy(e24.loadLibrary, () => e24.CompanyPageViewScreen(
              slug: 'privacy', fallbackTitle: 'Privacy Policy')),
        ),
        GoRoute(
          path: '/refunds',
          builder: (_, __) => _Lazy(e24.loadLibrary, () => e24.CompanyPageViewScreen(slug: 'refunds', fallbackTitle: 'Refunds & Cancellations')),
        ),
        GoRoute(
          path: '/placements',
          builder: (_, __) => _Lazy(d41.loadLibrary, () => d41.CompanyItemsScreen(category: 'placed', title: 'Placed Profiles', icon: Icons.emoji_events_rounded)),
        ),
        GoRoute(
          path: '/institutes',
          builder: (_, __) => _Lazy(d41.loadLibrary, () => d41.CompanyItemsScreen(category: 'institute', title: 'Affiliated Institutes', icon: Icons.school_rounded)),
        ),
        GoRoute(
          path: '/clients',
          builder: (_, __) => _Lazy(d41.loadLibrary, () => d41.CompanyItemsScreen(category: 'client', title: 'Clients', icon: Icons.handshake_rounded)),
        ),
        GoRoute(
          path: '/services',
          builder: (_, __) => _Lazy(d41.loadLibrary, () => d41.CompanyItemsScreen(category: 'service', title: 'Services', icon: Icons.design_services_rounded)),
        ),
        GoRoute(
          path: '/products',
          builder: (_, __) => _Lazy(d41.loadLibrary, () => d41.CompanyItemsScreen(category: 'product', title: 'Products', icon: Icons.widgets_rounded)),
        ),
        GoRoute(
          path: '/blog',
          builder: (_, __) => _Lazy(d41.loadLibrary, () => d41.CompanyItemsScreen(category: 'blog', title: 'Blog', icon: Icons.article_rounded)),
        ),
        // Job Updates — public, no login.
        GoRoute(path: '/jobs', builder: (_, __) => _Lazy(e8.loadLibrary, () => e8.JobUpdatesScreen())),
        GoRoute(
          path: '/jobs/:id',
          builder: (context, state) => _Lazy(e9.loadLibrary, () => e9.JobDetailScreen(
              jobId: int.tryParse(state.pathParameters['id'] ?? '0') ?? 0)),
        ),
        // How a learner connects VS Code to Altrobyte, once. Shared by link, so public.
        GoRoute(path: '/connect-vscode', builder: (_, __) => _Lazy(e2.loadLibrary, () => e2.ConnectVsCodeScreen())),
        GoRoute(path: '/download', builder: (_, __) => _Lazy(e3.loadLibrary, () => e3.DownloadAppScreen())),
        // An enrolment form shared by link — public; the person signs in with Google on the page itself.
        GoRoute(
          path: '/enroll/:slug',
          builder: (context, state) => _Lazy(e1.loadLibrary, () => e1.EnrolScreen(slug: state.pathParameters['slug'] ?? '', plan: state.uri.queryParameters['plan'])),
        ),
        // Events — public, no login.
        GoRoute(path: '/events', builder: (_, __) => _Lazy(e10.loadLibrary, () => e10.EventsScreen())),
        GoRoute(
          path: '/events/:id',
          builder: (context, state) => _Lazy(e11.loadLibrary, () => e11.EventDetailScreen(
              eventId: int.tryParse(state.pathParameters['id'] ?? '0') ?? 0)),
        ),
        // Live Sessions / Workshops — public, no login.
        GoRoute(path: '/live-sessions', builder: (_, __) => _Lazy(e12.loadLibrary, () => e12.LiveSessionsScreen())),
        GoRoute(
          path: '/live-sessions/:id',
          builder: (context, state) => _Lazy(e13.loadLibrary, () => e13.LiveSessionDetailScreen(
              sessionId: int.tryParse(state.pathParameters['id'] ?? '0') ?? 0)),
        ),
        // Partner enquiry — public, no login.
        GoRoute(path: '/partner', builder: (_, __) => _Lazy(e14.loadLibrary, () => e14.PartnerEnquiryScreen())),
        // Pricing — public, no login.
        GoRoute(path: '/pricing', builder: (_, __) => _Lazy(e16.loadLibrary, () => e16.PricingScreen())),
        // The roadmap with a free start, and every plan after it: public, no login (29 Oct 2026).
        GoRoute(path: '/learn', builder: (_, __) => const LearnScreen()),
        GoRoute(path: '/signin', builder: (_, __) => const SignInScreen()),
        GoRoute(path: '/unlock', builder: (_, __) => const UnlockScreen()),
        // Deliberately not linked from anywhere. Its URL is the product: it is
        // sent directly to someone who asked, while the public pricing page
        // still quotes programmes on request.
        GoRoute(path: '/program', builder: (_, __) => _Lazy(e17.loadLibrary, () => e17.ProgramPage())),
        GoRoute(path: '/plans', builder: (_, __) => _Lazy(e18.loadLibrary, () => e18.PlansPage())),
        // Public and shareable, like the roadmap: the whole point is that a
        // link turns into a time in the diary without anyone signing in.
        GoRoute(path: '/book', builder: (_, __) => _Lazy(e19.loadLibrary, () => e19.BookCallScreen())),
        GoRoute(path: '/bookings', builder: (_, __) => _Lazy(d28.loadLibrary, () => d28.BookingsScreen())),
        GoRoute(path: '/errors', builder: (_, __) => _Lazy(d29.loadLibrary, () => d29.ErrorsScreen())),
        // Admin: Top Stories + Lab Setups. Login-protected via the list above.
        GoRoute(
            path: '/showcase-admin',
            builder: (_, __) => _Lazy(d33.loadLibrary, () => d33.ShowcaseAdminScreen())),
        GoRoute(
            path: '/curriculum-admin',
            builder: (_, __) => _Lazy(d34.loadLibrary, () => d34.RoadmapAdminScreen())),
        GoRoute(path: '/crm', builder: (_, __) => _Lazy(d35.loadLibrary, () => d35.CrmScreen())),
        GoRoute(path: '/access', builder: (_, __) => _Lazy(d36.loadLibrary, () => d36.AccessScreen())),
        GoRoute(
            path: '/scholars',
            builder: (_, __) => _Lazy(d37.loadLibrary, () => d37.ScholarsScreen())),
        GoRoute(
            path: '/reviews-admin',
            builder: (_, __) => _Lazy(d30.loadLibrary, () => d30.TestimonialsAdminScreen())),
        GoRoute(
            path: '/company-admin',
            builder: (_, __) => _Lazy(d31.loadLibrary, () => d31.CompanyItemsAdminScreen())),
        GoRoute(
            path: '/scholarship-admin',
            builder: (_, __) => _Lazy(d32.loadLibrary, () => d32.ScholarshipAdminScreen())),
        // Public lists that had pages and a backend but no way to fill them.
        GoRoute(
          path: '/colleges',
          builder: (_, __) => _Lazy(d41.loadLibrary, () => d41.CompanyItemsScreen(
              category: 'college',
              title: 'Colleges We Have Taught At',
              icon: Icons.school_rounded)),
        ),
        GoRoute(
          path: '/projects',
          builder: (_, __) => _Lazy(d41.loadLibrary, () => d41.CompanyItemsScreen(
              category: 'project',
              title: 'Projects',
              icon: Icons.memory_rounded)),
        ),
        GoRoute(
            path: '/wa-messages',
            builder: (_, __) => _Lazy(d38.loadLibrary, () => d38.WaMessagesScreen())),
        // Public on purpose: the roadmap is the pitch, so it must be
        // shareable as a link to someone who has never signed in.
        // Public like the roadmap: the argument for a path is no use behind
        // a login when the people who most need it have not signed up yet.
        GoRoute(path: '/what-if', builder: (_, __) => _Lazy(e21.loadLibrary, () => e21.WhatIfScreen())),
        // The page the poster's QR code points at. Public: a candidate who
        // has never signed in has to be able to read what it is worth before
        // being asked for anything.
        GoRoute(
            path: '/scholarship',
            builder: (_, __) => _Lazy(e22.loadLibrary, () => e22.ScholarshipScreen())),
        // Public: the link is posted in class WhatsApp groups, so it has to
        // render for somebody who has never signed in.
        GoRoute(
          path: '/test-series/:id',
          builder: (_, state) => _Lazy(e23.loadLibrary, () => e23.TestSeriesPage(
              seriesId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0)),
        ),
        // The same roadmap at a second address: /roadmap/product-engineering is now the admissions page (firebase.json),
        // so the full roadmap and the projector view (?present=1) live here.
        GoRoute(
          path: '/curriculum/:slug',
          builder: (_, state) => _Lazy(e20.loadLibrary, () => e20.RoadmapScreen(
            slug: state.pathParameters['slug'] ?? '',
            present: state.uri.queryParameters['present'] == '1',
          )),
        ),
        // The short link (/roadmap) is the admissions page too (firebase.json); this only catches a visitor whose
        // browser still runs an old copy of the app, and sends them there.
        GoRoute(
          path: '/roadmap',
          builder: (_, __) => _Lazy(e20.loadLibrary, () => e20.RoadmapScreen(slug: 'product-engineering', toAdmissions: true)),
        ),
        GoRoute(
          path: '/roadmap/:slug',
          // ?present=1 for showing this on a screen to a room: no fees, the
          // stages closed so they can be opened one at a time, and type that
          // survives a projector.
          builder: (_, state) => _Lazy(e20.loadLibrary, () => e20.RoadmapScreen(
            slug: state.pathParameters['slug'] ?? '',
            present: state.uri.queryParameters['present'] == '1',
            toAdmissions: true,
          )),
        ),
        GoRoute(
          path: '/student/login',
          // The coaching-institute login is retired (founder, 30 Oct 2026); old links land on the learner sign-in.
          redirect: (_, __) => '/signin',
        ),
        GoRoute(
          path: '/student/home',
          builder: (_, __) => const StudentHomeScreen(),
        ),
        GoRoute(
          path: '/student/experiments',
          builder: (_, __) => _Lazy(e7.loadLibrary, () => e7.StudentExperimentsScreen()),
        ),
        GoRoute(
          path: '/student/test-series',
          builder: (_, __) => _Lazy(e5.loadLibrary, () => e5.StudentTestSeriesScreen()),
        ),
        GoRoute(
          path: '/student/mock-interview',
          builder: (_, __) => _Lazy(e15.loadLibrary, () => e15.MockInterviewScreen()),
        ),
        GoRoute(
          path: '/student/activity',
          builder: (_, __) => _Lazy(e6.loadLibrary, () => e6.StudentActivityScreen()),
        ),
        GoRoute(
          path: '/student/onboarding',
          builder: (_, __) => const StudentOnboardingScreen(),
        ),
        GoRoute(
          path: '/student/training',
          builder: (_, __) => _Lazy(e4.loadLibrary, () => e4.StudentTrainingScreen()),
        ),
        GoRoute(
          path: '/student/dev-tools',
          builder: (_, __) => _Lazy(d19.loadLibrary, () => d19.DevToolsHubScreen()),
        ),
        GoRoute(
          path: '/student/challenges',
          builder: (_, __) => _Lazy(e25.loadLibrary, () => e25.StudentChallengesScreen()),
        ),
        // Manager login
        GoRoute(
          path: '/manager/login',
          builder: (_, __) => _Lazy(d20.loadLibrary, () => d20.ManagerLoginScreen()),
        ),
        // Super admin routes (self-guarded)
        GoRoute(
          path: '/super/login',
          builder: (_, __) => _Lazy(d45.loadLibrary, () => d45.SuperAdminLoginScreen()),
        ),
        GoRoute(
          path: '/super/dashboard',
          builder: (_, __) => _Lazy(d46.loadLibrary, () => d46.SuperAdminDashboardScreen()),
        ),
        GoRoute(
          path: '/super/commissions',
          builder: (_, __) => _Lazy(d47.loadLibrary, () => d47.CommissionTrackerScreen()),
        ),
        GoRoute(
          path: '/super/settings',
          builder: (_, __) => _Lazy(d48.loadLibrary, () => d48.SuperAdminSettingsScreen()),
        ),
        GoRoute(
          path: '/super/job-updates',
          builder: (_, __) => _Lazy(d23.loadLibrary, () => d23.JobUpdatesAdminScreen()),
        ),
        GoRoute(
          path: '/super/events',
          builder: (_, __) => _Lazy(d24.loadLibrary, () => d24.EventsAdminScreen()),
        ),
        GoRoute(
          path: '/super/live-sessions',
          builder: (_, __) => _Lazy(d25.loadLibrary, () => d25.LiveSessionsAdminScreen()),
        ),
        GoRoute(
          path: '/super/enquiries',
          builder: (_, __) => _Lazy(d27.loadLibrary, () => d27.EnquiriesAdminScreen()),
        ),
        GoRoute(
          path: '/super/pricing',
          builder: (_, __) => _Lazy(d39.loadLibrary, () => d39.PricingAdminScreen()),
        ),
        GoRoute(
          path: '/super/audits/:instituteId',
          builder: (context, state) {
            final id = int.tryParse(state.pathParameters['instituteId'] ?? '0') ?? 0;
            return _Lazy(d49.loadLibrary, () => d49.AuditLogsScreen(instituteId: id, isSuperAdmin: true));
          },
        ),
        GoRoute(
          path: '/audits/:instituteId',
          builder: (context, state) {
            final id = int.tryParse(state.pathParameters['instituteId'] ?? '0') ?? 0;
            return _Lazy(d49.loadLibrary, () => d49.AuditLogsScreen(instituteId: id, isSuperAdmin: false));
          },
        ),
        // Educator (admin) login
        GoRoute(
          path: '/login',
          builder: (_, __) => _Lazy(d0.loadLibrary, () => d0.LoginScreen()),
        ),
        GoRoute(
          path: '/forgot-password',
          builder: (_, __) => _Lazy(d50.loadLibrary, () => d50.ForgotPasswordScreen()),
        ),
        GoRoute(
          path: '/whatsapp-login',
          builder: (_, __) => _Lazy(d51.loadLibrary, () => d51.WhatsappLoginScreen()),
        ),
        GoRoute(
          path: '/plans',
          builder: (_, __) => _Lazy(d52.loadLibrary, () => d52.PlanUpgradeScreen()),
        ),
        // Public test route
        GoRoute(
          path: '/test/:id',
          builder: (_, state) => _Lazy(e0.loadLibrary, () => e0.TestAttemptScreen(
              testId: int.parse(state.pathParameters['id'] ?? '0'))),
        ),
        // Protected shell — IndexedStack keeps every tab's state alive, so
        // switching tabs never rebuilds/refetches a screen.
        StatefulShellRoute.indexedStack(
          builder: (_, __, navigationShell) =>
              _Lazy(d1.loadLibrary, () => d1.MainLayout(navigationShell: navigationShell)),
          branches: [
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/dashboard',
                builder: (_, __) => _Lazy(d2.loadLibrary, () => d2.DashboardScreen()),
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/students',
                builder: (_, __) => _Lazy(d4.loadLibrary, () => d4.StudentsScreen()),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (_, state) => _Lazy(d5.loadLibrary, () => d5.StudentDetailScreen(
                        studentId:
                            int.parse(state.pathParameters['id'] ?? '0'))),
                  ),
                ],
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/platform-users',
                builder: (_, __) => _Lazy(d26.loadLibrary, () => d26.PlatformUsersScreen()),
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/batches',
                builder: (_, __) => _Lazy(d14.loadLibrary, () => d14.BatchesScreen()),
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/test-generator',
                builder: (_, __) => _Lazy(d6.loadLibrary, () => d6.TestGeneratorScreen()),
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/training-modules',
                builder: (_, __) => _Lazy(d21.loadLibrary, () => d21.TrainingModulesScreen()),
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/experiments',
                builder: (_, __) => _Lazy(d22.loadLibrary, () => d22.ExperimentsScreen()),
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/live-sessions-admin',
                builder: (_, __) => _Lazy(d25.loadLibrary, () => d25.LiveSessionsAdminScreen()),
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/challenges-admin',
                builder: (_, __) => _Lazy(d42.loadLibrary, () => d42.ChallengesAdminScreen()),
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/home-strip-admin',
                builder: (_, __) => _Lazy(d43.loadLibrary, () => d43.HomeStripAdminScreen()),
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/activity-feed-admin',
                builder: (_, __) => _Lazy(d44.loadLibrary, () => d44.ActivityFeedAdminScreen()),
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/events-admin',
                builder: (_, __) => _Lazy(d24.loadLibrary, () => d24.EventsAdminScreen()),
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/jobs-admin',
                builder: (_, __) => _Lazy(d23.loadLibrary, () => d23.JobUpdatesAdminScreen()),
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/enquiries-admin',
                builder: (_, __) => _Lazy(d27.loadLibrary, () => d27.EnquiriesAdminScreen()),
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/pricing-admin',
                builder: (_, __) => _Lazy(d39.loadLibrary, () => d39.PricingAdminScreen()),
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/attendance',
                builder: (_, __) => _Lazy(d7.loadLibrary, () => d7.AttendanceScreen()),
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/fees',
                builder: (_, __) => _Lazy(d8.loadLibrary, () => d8.FeeManagementScreen()),
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/analytics',
                builder: (_, __) => _Lazy(d13.loadLibrary, () => d13.AnalyticsScreen()),
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/broadcast',
                builder: (_, __) => _Lazy(d15.loadLibrary, () => d15.BroadcastScreen()),
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/settings',
                builder: (_, __) => _Lazy(d3.loadLibrary, () => d3.SettingsScreen()),
              ),
            ]),
            // Last on purpose: MainLayout's bottom nav addresses branches by
            // index (attendance=12, settings=16), so inserting earlier would
            // silently repoint those tabs.
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/invoices',
                builder: (_, __) => _Lazy(d9.loadLibrary, () => d9.InvoicesScreen()),
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/trainer-admin',
                builder: (_, __) => _Lazy(d11.loadLibrary, () => d11.TrainerAdminScreen()),
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/trainer-usage',
                builder: (_, __) => _Lazy(d12.loadLibrary, () => d12.TrainerUsageScreen()),
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/enrolment-forms',
                builder: (_, __) => _Lazy(d10.loadLibrary, () => d10.EnrolmentFormsScreen()),
              ),
            ]),
          ],
        ),
        // Per-institute branded landing (PWA). Must be LAST so explicit
        // routes above win; only bare single-segment slugs reach here.
        GoRoute(
          path: '/:slug',
          builder: (_, state) =>
              _Lazy(d17.loadLibrary, () => d17.BrandedLandingScreen(slug: state.pathParameters['slug']!)),
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


/// An admin or team screen whose code downloads only when it is opened (30 Oct 2026, founder: every page took too long
/// to load). Learners never pay for the admin, CRM and super-admin code in their first load.
class _Lazy extends StatelessWidget {
  const _Lazy(this.load, this.build_);
  final Future<void> Function() load;
  final Widget Function() build_;
  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
        future: load(),
        builder: (_, snap) => snap.connectionState == ConnectionState.done && !snap.hasError
            ? build_()
            : Scaffold(
                body: Center(
                  child: snap.hasError
                      ? TextButton(onPressed: () => (context as Element).markNeedsBuild(), child: const Text('Could not open this page. Tap to try again.'))
                      : const CircularProgressIndicator(),
                ),
              ),
      );
}
