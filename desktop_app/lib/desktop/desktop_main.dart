// Entry point of the desktop trainer app (Windows first).
//
//   flutter run -d windows -t lib/desktop/desktop_main.dart
//   flutter build windows --release -t lib/desktop/desktop_main.dart
//
// A separate entry point on purpose: the web app imports browser-only libraries
// (dart:html), which cannot be compiled into a desktop app. Flutter only
// compiles what an entry point reaches, so this one stays clean — keep dart:html
// and package:web out of everything under lib/desktop and what it imports.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../providers/auth_provider.dart';
import 'desktop_login_screen.dart';
import 'desktop_trainer_screen.dart';

final desktopNavKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final auth = AuthProvider();
  await auth.tryAutoLogin();
  runApp(ChangeNotifierProvider.value(value: auth, child: const DesktopApp()));
}

class DesktopApp extends StatelessWidget {
  const DesktopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Altrobyte AI Trainer',
      navigatorKey: desktopNavKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        scaffoldBackgroundColor: AppColors.background,
        textTheme: GoogleFonts.interTextTheme(),
        useMaterial3: true,
      ),
      home: const _Gate(),
    );
  }
}

class _Gate extends StatelessWidget {
  const _Gate();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!auth.isInitialized) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return auth.isLoggedIn ? const DesktopTrainerScreen() : const DesktopLoginScreen();
  }
}
