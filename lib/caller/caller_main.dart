// Entry point of Altrobyte Caller, the telecallers' Android app.
//
//   flutter run --flavor caller -t lib/caller/caller_main.dart
//   flutter build apk --release --flavor caller -t lib/caller/caller_main.dart
//
// A separate entry point and Android flavor on purpose (like lib/desktop): the web app imports browser-only libraries,
// and the call permissions belong to this app alone. Keep dart:html and package:web out of everything under lib/caller.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../constants/app_colors.dart';
import 'caller_api.dart';
import 'caller_controller.dart';
import 'calls_screen.dart';
import 'demo_client.dart';
import 'lead_screen.dart';
import 'log_call_sheet.dart';
import 'login_screen.dart';
import 'models.dart';
import 'permissions_screen.dart';
import 'team_screen.dart';
import 'today_screen.dart';

final callerNavKey = GlobalKey<NavigatorState>();

/// --dart-define=CALLER_DEMO=true: no login, sample leads, nothing sent anywhere (see demo_client.dart).
const callerDemo = bool.fromEnvironment('CALLER_DEMO');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (callerDemo) {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('caller_token', 'demo');
    await prefs.setString('caller_me', jsonEncode({'login': 'you@demo', 'name': 'You (demo)', 'team_lead': true}));
  }
  final c = callerDemo
      ? CallerController(api: CallerApi(client: DemoClient(), hosts: ['https://demo.local']), demo: true)
      : CallerController();
  await c.init();
  final seen = await PermissionsScreen.seen();
  runApp(ChangeNotifierProvider.value(value: c, child: CallerApp(permissionsSeen: seen)));
}

class CallerApp extends StatefulWidget {
  final bool permissionsSeen;
  const CallerApp({super.key, required this.permissionsSeen});

  @override
  State<CallerApp> createState() => _CallerAppState();
}

class _CallerAppState extends State<CallerApp> {
  late bool _seen = widget.permissionsSeen;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<CallerController>();
    return MaterialApp(
      title: 'Altrobyte Caller',
      navigatorKey: callerNavKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary, primary: AppColors.primary),
        scaffoldBackgroundColor: AppColors.background,
        useMaterial3: true,
      ),
      home: !c.ready
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : !c.signedIn
              ? const CallerLoginScreen()
              : !_seen
                  ? PermissionsScreen(onDone: () => setState(() => _seen = true))
                  : const CallerHome(),
    );
  }
}

class CallerHome extends StatefulWidget {
  const CallerHome({super.key});

  @override
  State<CallerHome> createState() => _CallerHomeState();
}

class _CallerHomeState extends State<CallerHome> with WidgetsBindingObserver {
  int _tab = 0;
  bool _sheetOpen = false;
  late final CallerController _c;

  @override
  void initState() {
    super.initState();
    _c = context.read<CallerController>();
    _c.addListener(_react);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _react());
  }

  @override
  void dispose() {
    _c.removeListener(_react);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _c.native.deliverPending(); // a call that ended while we were in the background
      _c.refresh(quiet: true);
    }
  }

  /// Opens the log sheet when a call has ended, a lead when a reminder was tapped, and shows any plain notice.
  Future<void> _react() async {
    if (!mounted) return;
    final notice = _c.notice;
    if (notice != null) {
      _c.notice = null;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(notice), duration: const Duration(seconds: 6)));
    }
    final phone = _c.openPhone;
    if (phone != null) {
      _c.openPhone = null;
      callerNavKey.currentState?.push(MaterialPageRoute(builder: (_) => LeadScreen(phone: phone)));
    }
    if (_sheetOpen || _c.pendingLog == null) return;
    final p = _c.takePendingLog()!;
    final nav = callerNavKey.currentContext;
    if (nav == null) return;
    _sheetOpen = true;
    final log = await showLogCallSheet(
      nav,
      LogCallSheet(
        lead: p.lead,
        call: p.call,
        isNew: p.isNew,
        labels: _c.labels,
        quickMessages: _c.quickMessages,
        now: _c.now,
        newId: () => p.call != null ? deviceCallId(p.lead.phone, p.call!.startedAt) : const Uuid().v4(),
        onQuickWa: (kind) => _c.quickWa(p.lead.phone, kind),
        onSpeech: _c.speechToText,
      ),
    );
    _sheetOpen = false;
    await _c.finishLog(log);
    if (_c.pendingLog != null) _react();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<CallerController>();
    final lead = c.me?.teamLead ?? false;
    final tabs = [('Today', Icons.today), ('Calls', Icons.history), if (lead) ('Team', Icons.leaderboard)];
    final tab = _tab.clamp(0, tabs.length - 1);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Text('${tabs[tab].$1}${c.demo ? ' · demo' : ''}'),
        actions: [
          if (c.syncing)
            const Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
          else
            IconButton(tooltip: 'Refresh', onPressed: c.refresh, icon: const Icon(Icons.refresh)),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'perms') {
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (ctx) => PermissionsScreen(onDone: () => Navigator.of(ctx).pop())));
              }
              if (v == 'out') c.signOut();
              if (v == 'auto') c.setAutoAdd(!c.autoAdd);
            },
            itemBuilder: (_) => [
              PopupMenuItem(enabled: false, child: Text(c.me?.name ?? '')),
              CheckedPopupMenuItem(value: 'auto', checked: c.autoAdd, child: const Text('Add new numbers as leads')),
              const PopupMenuItem(value: 'perms', child: Text('Permissions')),
              if (!c.demo) const PopupMenuItem(value: 'out', child: Text('Sign out')),
            ],
          ),
        ],
      ),
      body: switch (tabs[tab].$1) {
        'Calls' => const CallsScreen(),
        'Team' => const TeamScreen(),
        _ => const TodayScreen(),
      },
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [for (final t in tabs) NavigationDestination(icon: Icon(t.$2), label: t.$1)],
      ),
    );
  }
}
