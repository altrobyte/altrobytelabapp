import 'package:flutter/material.dart';
import 'l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/brand_provider.dart';
import 'providers/institute_provider.dart';
import 'providers/language_provider.dart';
import 'providers/test_provider.dart';
import 'providers/training_module_provider.dart';
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
import 'screens/manager/manager_login_screen.dart';
import 'screens/training_modules/training_modules_screen.dart';
import 'screens/super_admin/super_admin_login_screen.dart';
import 'screens/super_admin/super_admin_dashboard_screen.dart';
import 'screens/super_admin/commission_tracker_screen.dart';
import 'screens/super_admin/super_admin_settings_screen.dart';
import 'screens/audit_logs_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/auth/whatsapp_login_screen.dart';
import 'screens/plan_upgrade_screen.dart';
import 'theme/app_theme.dart';

void main() {
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
          if (auth.isSuperAdmin) return '/super/dashboard';
          return '/dashboard';
        }

        // Only the educator/manager shell routes are login-protected.
        const protected = [
          '/dashboard', '/students', '/batches', '/test-generator',
          '/training-modules', '/attendance', '/fees', '/analytics',
          '/broadcast', '/settings',
        ];
        final isProtected = protected.any((p) => loc == p || loc.startsWith('$p/'));

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
        // Student routes (self-guarded)
        GoRoute(
          path: '/student/login',
          builder: (_, __) => const StudentLoginScreen(),
        ),
        GoRoute(
          path: '/student/home',
          builder: (_, __) => const StudentHomeScreen(),
        ),
        GoRoute(
          path: '/student/onboarding',
          builder: (_, __) => const StudentOnboardingScreen(),
        ),
        GoRoute(
          path: '/student/training',
          builder: (_, __) => const StudentTrainingScreen(),
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
