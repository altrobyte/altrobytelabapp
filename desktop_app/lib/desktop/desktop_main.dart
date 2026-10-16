// Entry point of the desktop trainer app (Windows first).
//
//   flutter run -d windows -t lib/desktop/desktop_main.dart
//   flutter build windows --release -t lib/desktop/desktop_main.dart
//
// A separate entry point on purpose: the web app imports browser-only libraries
// (dart:html), which cannot be compiled into a desktop app. Flutter only
// compiles what an entry point reaches, so this one stays clean — keep dart:html
// and package:web out of everything under lib/desktop and what it imports.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../providers/auth_provider.dart';
import 'desktop_login_screen.dart';
import 'desktop_trainer_screen.dart';
import 'helper_client.dart';
import 'helper_controller.dart';
import 'live_tutor_screen.dart' show initLiveEnvironment;
import 'local_tools.dart';
import 'visual_page.dart';

final desktopNavKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initLiveEnvironment(); // before any browser view: lets Altron speak without a tap
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
    return auth.isLoggedIn ? const _HelperHost() : const DesktopLoginScreen();
  }
}

/// Joins the helper running on this computer (the VS Code extension may have started it) or starts the one that ships with
/// this app, then shows the trainer on top of it. Only one helper ever runs, so both windows share settings and the board.
class _HelperHost extends StatefulWidget {
  const _HelperHost();

  @override
  State<_HelperHost> createState() => _HelperHostState();
}

class _HelperHostState extends State<_HelperHost> {
  HelperController? _controller;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    setState(() => _error = null);
    try {
      final exeDir = File(Platform.resolvedExecutable).parent.path;
      final info = await connectHelper(runtime: locateRuntime(exeDir: exeDir));
      final next = HelperController(HelperClient(info), openInEditor: openInVsCode, openPicture: openPicture, starterFolder: starterFolder, folderExists: (p) => Directory(p).existsSync());
      await next.init();
      final old = _controller;
      if (!mounted) {
        next.dispose();
        return;
      }
      setState(() => _controller = next);
      old?.dispose();
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller != null) return DesktopTrainerScreen(key: ValueKey(controller), controller: controller, onReconnect: _connect);
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.error_outline_rounded, size: 44, color: Colors.black38),
              const SizedBox(height: 12),
              Text('Could not start the helper', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 18)),
              const SizedBox(height: 8),
              Text('$_error', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _connect, child: const Text('Try again')),
            ]),
          ),
        ),
      );
    }
    return const Scaffold(body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(), SizedBox(height: 14), Text('Starting…')])));
  }
}
