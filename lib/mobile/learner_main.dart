// Altrobyte Lab on Android, the learner app for the Play Store (30 Oct 2026, founder: most learners come on a phone).
// A real app with four tabs (31 Oct 2026, founder: "it looks like the website; it is not only for learning"):
//   Learn    the roadmap and its lessons with Altron (the website's fast /learn pages, so a lesson is the same on the web
//            and in the app; the pages hide their own site bar inside the app)
//   Live     live classes; registering and paying open in the browser (Play's rules on digital content)
//   Tools    the MQTT, HTTP, WebSocket and OTA dev tools, native
//   Profile  the account: WhatsApp sign-in, plans, help, sign out, delete account
// lib/main.dart is web-only and does not build for Android.
//
//   flutter run --flavor lab -t lib/mobile/learner_main.dart
//   flutter build appbundle --release --flavor lab -t lib/mobile/learner_main.dart

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../constants/api_constants.dart';
import '../screens/tools/dev_tools_hub_screen.dart';
import '../services/api_service.dart';

const _ink = Color(0xFF0A1220);
const _panel = Color(0xFF13223A);
const _orange = Color(0xFFFF6A1A);
const _soft = Color(0xFF9DB0C6);
const _site = 'https://altrobytelab.com';
const _whatsapp = 'https://wa.me/917222977927';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: _ink, systemNavigationBarColor: _ink));
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Altrobyte Lab',
    theme: ThemeData(
      colorSchemeSeed: _orange,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: _ink,
      textTheme: GoogleFonts.interTextTheme(ThemeData(brightness: Brightness.dark).textTheme),
    ),
    home: const _Home(),
  ));
}

/// The sign-in, shared by every tab. The website keeps it in localStorage 'flutter.student_token'; the app keeps its
/// own copy and hands it to each page.
class _Auth extends ChangeNotifier {
  String token = '';
  Map<String, dynamic>? me;
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    token = (await SharedPreferences.getInstance()).getString('student_token') ?? '';
    notifyListeners();
    refreshMe();
  }

  Future<void> set(String t) async {
    if (t == token) return;
    final prefs = await SharedPreferences.getInstance();
    if (t.isEmpty) {
      await prefs.remove('student_token');
    } else {
      await prefs.setString('student_token', t);
    }
    token = t;
    me = null;
    notifyListeners();
    refreshMe();
  }

  Future<void> refreshMe() async {
    if (token.isEmpty) return;
    try {
      final r = await http.get(Uri.parse('${ApiConstants.baseUrl}/student/me'), headers: {'Authorization': 'Bearer $token'});
      if (r.statusCode == 401) {
        await set('');   // ended elsewhere (signed out, account deleted)
      } else if (r.statusCode == 200) {
        me = jsonDecode(r.body) as Map<String, dynamic>;
        notifyListeners();
      }
    } catch (_) {}   // offline: the profile shows what it has
  }
}

final _auth = _Auth();

class _Home extends StatefulWidget {
  const _Home();
  @override
  State<_Home> createState() => _HomeState();
}

class _HomeState extends State<_Home> {
  int _tab = 0;
  bool _fullScreen = false;   // a lesson or a live class fills the screen, without the tabs
  final _learn = GlobalKey<_WebTabState>(), _live = GlobalKey<_WebTabState>();

  Future<void> signIn({String next = ''}) async {
    final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const _SignIn()));
    if (ok != true || !mounted) return;
    await Permission.microphone.request();   // Altron listens; asked once, right after signing in
    final path = next.startsWith('/') && !next.startsWith('//') ? next : '';
    if (path.startsWith('/live')) {
      setState(() => _tab = 1);
      _live.currentState?.open(path);
    } else if (path.isNotEmpty) {
      setState(() => _tab = 0);
      _learn.currentState?.open(path);
    }
  }

  void _onPath(String path) {
    final full = RegExp(r'^/learn/\d+/\d+').hasMatch(path) || path.startsWith('/live/') || path.startsWith('/class');
    if (full != _fullScreen) setState(() => _fullScreen = full);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final web = _tab == 0 ? _learn.currentState : _tab == 1 ? _live.currentState : null;
        if (web != null && await web.back()) return;
        if (_tab != 0) {
          setState(() => _tab = 0);
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: _ink,
        body: SafeArea(
          child: IndexedStack(index: _tab, children: [
            _WebTab(key: _learn, start: '/learn', onSignIn: signIn, onPath: _onPath),
            _WebTab(key: _live, start: '/live-sessions', onSignIn: signIn, onPath: _onPath),
            const DevToolsHubScreen(),
            _Profile(onSignIn: signIn, onOpen: (p) { setState(() => _tab = 0); _learn.currentState?.open(p); }),
          ]),
        ),
        bottomNavigationBar: _fullScreen && _tab < 2
            ? null
            : NavigationBar(
                backgroundColor: _panel,
                indicatorColor: _orange.withValues(alpha: .22),
                selectedIndex: _tab,
                onDestinationSelected: (i) => setState(() => _tab = i),
                destinations: const [
                  NavigationDestination(icon: Icon(Icons.route_outlined), selectedIcon: Icon(Icons.route), label: 'Learn'),
                  NavigationDestination(icon: Icon(Icons.live_tv_outlined), selectedIcon: Icon(Icons.live_tv), label: 'Live'),
                  NavigationDestination(icon: Icon(Icons.developer_board_outlined), selectedIcon: Icon(Icons.developer_board), label: 'Tools'),
                  NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
                ],
              ),
      ),
    );
  }
}

/// One tab of the website's fast pages. Its pages stay in the app; sign-in is native; everything else (WhatsApp,
/// registering and paying, other sites) opens outside, in the browser or the app it belongs to.
class _WebTab extends StatefulWidget {
  const _WebTab({super.key, required this.start, required this.onSignIn, required this.onPath});
  final String start;
  final Future<void> Function({String next}) onSignIn;
  final void Function(String path) onPath;
  @override
  State<_WebTab> createState() => _WebTabState();
}

class _WebTabState extends State<_WebTab> {
  late final WebViewController _web;
  bool _loading = true, _offline = false;

  @override
  void initState() {
    super.initState();
    _web = WebViewController(onPermissionRequest: (req) => req.grant())
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(_ink)
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: _route,
        onPageStarted: (_) => setState(() { _loading = true; _offline = false; }),
        onPageFinished: (_) => _handOver(),
        onUrlChange: (c) => widget.onPath(Uri.tryParse(c.url ?? '')?.path ?? ''),
        onWebResourceError: (e) {
          if (e.isForMainFrame ?? true) setState(() { _offline = true; _loading = false; });
        },
      ));
    final p = _web.platform;
    if (p is AndroidWebViewController) p.setMediaPlaybackRequiresUserGesture(false);
    _auth.addListener(_handOver);
    // The pages hide their site bar and dock when the user agent says AltrobyteApp.
    _web.getUserAgent().then((ua) async {
      await _web.setUserAgent('${ua ?? ''} AltrobyteApp/1');
      await _auth.load();
      _web.loadRequest(Uri.parse('$_site${widget.start}'));
    });
  }

  @override
  void dispose() {
    _auth.removeListener(_handOver);
    super.dispose();
  }

  void open(String path) => _web.loadRequest(Uri.parse('$_site$path'));

  Future<bool> back() async {
    if (await _web.canGoBack()) {
      await _web.goBack();
      return true;
    }
    return false;
  }

  /// Gives the page the app's sign-in (or takes it away), and reloads it when that changes what the page shows.
  Future<void> _handOver() async {
    if (mounted) setState(() => _loading = false);
    final t = _auth.token.isEmpty ? 'null' : jsonEncode(jsonEncode(_auth.token));
    try {
      await _web.runJavaScript(
          "if (location.host === 'altrobytelab.com') { var t = $t, k = 'flutter.student_token', c = localStorage.getItem(k);"
          " if (t === null ? c !== null : c !== t) { if (t === null) localStorage.removeItem(k); else localStorage.setItem(k, t);"
          " location.reload(); } }");
    } catch (_) {}
  }

  NavigationDecision _route(NavigationRequest r) {
    final u = Uri.tryParse(r.url);
    if (u == null) return NavigationDecision.prevent;
    final ours = u.host == 'altrobytelab.com' || u.host == 'www.altrobytelab.com';
    if (ours && u.path == '/signin') {
      widget.onSignIn(next: u.queryParameters['next'] ?? '');
      return NavigationDecision.prevent;
    }
    if (ours && u.queryParameters['signed_out'] == '1') _auth.set('');   // the account was deleted on /delete-account
    if (ours && (u.path == '/delete-account' || const ['/learn', '/live-sessions', '/class', '/live/'].any(u.path.startsWith))) {
      return NavigationDecision.navigate;
    }
    if (ours && u.path == '/') {   // the website's home: the app's home is the Learn tab
      open('/learn');
      return NavigationDecision.prevent;
    }
    if (u.scheme == 'about' || u.scheme == 'data') return NavigationDecision.navigate;
    launchUrl(u, mode: LaunchMode.externalApplication);
    return NavigationDecision.prevent;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      WebViewWidget(controller: _web),
      if (_loading) const LinearProgressIndicator(minHeight: 2, color: _orange, backgroundColor: Colors.transparent),
      if (_offline)
        Container(
          color: _ink,
          alignment: Alignment.center,
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.wifi_off_rounded, size: 48, color: Colors.white54),
            const SizedBox(height: 12),
            Text('No internet', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            const Text('Altrobyte Lab needs the internet. Check it and try again.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 18),
            FilledButton(onPressed: () => _web.reload(), style: FilledButton.styleFrom(backgroundColor: _orange), child: const Text('Try again')),
          ]),
        ),
    ]);
  }
}

/// The account: who is signed in, plans, help, sign out, delete account.
class _Profile extends StatelessWidget {
  const _Profile({required this.onSignIn, required this.onOpen});
  final Future<void> Function({String next}) onSignIn;
  final void Function(String path) onOpen;

  void _out(String url) => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _auth,
      builder: (context, _) {
        final signedIn = _auth.token.isNotEmpty;
        final me = _auth.me ?? const {};
        final name = (me['name'] as String? ?? '').trim();
        final phone = (me['phone'] as String? ?? '').trim();
        return ListView(padding: const EdgeInsets.fromLTRB(20, 24, 20, 32), children: [
          Row(children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(color: _orange.withValues(alpha: .18), borderRadius: BorderRadius.circular(16)),
              alignment: Alignment.center,
              child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'A',
                  style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.w700, color: _orange)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(signedIn ? (name.isEmpty ? 'Welcome' : name) : 'Altrobyte Lab',
                    style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700)),
                Text(signedIn ? (phone.length >= 10 ? '+91 ${phone.substring(phone.length - 10)}' : 'Signed in') : 'Learn embedded & IoT by building',
                    style: const TextStyle(color: _soft)),
              ]),
            ),
          ]),
          const SizedBox(height: 22),
          if (!signedIn) ...[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(16)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Sign in to save your progress', style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                const Text('Altron explains every lesson by voice once you sign in. A code comes on WhatsApp, no password.',
                    style: TextStyle(color: _soft)),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: () => onSignIn(),
                  style: FilledButton.styleFrom(backgroundColor: _orange, minimumSize: const Size.fromHeight(48)),
                  child: const Text('Sign in with WhatsApp', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ]),
            ),
            const SizedBox(height: 18),
          ],
          _group([
            _tile(Icons.route, 'My roadmap', 'Continue where you left off', () => onOpen('/learn')),
            _tile(Icons.workspace_premium_outlined, 'Plans', '₹4,999 / month, every step and a weekly live class', () => _out('$_site/pricing')),
          ]),
          const SizedBox(height: 14),
          _group([
            _tile(Icons.chat_outlined, 'Help on WhatsApp', 'Talk to our team', () => _out(_whatsapp)),
            _tile(Icons.mail_outline, 'Email us', 'pawan@altrobytelab.com', () => _out('mailto:pawan@altrobytelab.com')),
            _tile(Icons.privacy_tip_outlined, 'Privacy policy', null, () => _out('$_site/privacy')),
          ]),
          if (signedIn) ...[
            const SizedBox(height: 14),
            _group([
              _tile(Icons.logout, 'Sign out', null, () async {
                final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
                  title: const Text('Sign out?'),
                  content: const Text('Your progress stays saved. Sign in again with the same number to carry on.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                    TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Sign out')),
                  ],
                ));
                if (ok == true) {
                  http.post(Uri.parse('${ApiConstants.baseUrl}/student/logout'), headers: {'Authorization': 'Bearer ${_auth.token}'}).ignore();
                  await _auth.set('');
                }
              }),
              _tile(Icons.delete_outline, 'Delete account', 'Removes your account and data', () => onOpen('/delete-account'), danger: true),
            ]),
          ],
          const SizedBox(height: 26),
          const Center(child: Text('Altrobyte Lab · Altrobyte Automation, Indore', style: TextStyle(color: _soft, fontSize: 12))),
        ]);
      },
    );
  }

  Widget _group(List<Widget> tiles) => Container(
        decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: Column(children: tiles),
      );

  Widget _tile(IconData icon, String title, String? sub, VoidCallback onTap, {bool danger = false}) => ListTile(
        leading: Icon(icon, color: danger ? const Color(0xFFFF8A80) : _orange),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: danger ? const Color(0xFFFF8A80) : null)),
        subtitle: sub == null ? null : Text(sub, style: const TextStyle(color: _soft, fontSize: 13)),
        trailing: const Icon(Icons.chevron_right, color: _soft),
        onTap: onTap,
      );
}

/// Sign in with the WhatsApp number (the only way learners sign in): a code comes on WhatsApp.
class _SignIn extends StatefulWidget {
  const _SignIn();
  @override
  State<_SignIn> createState() => _SignInState();
}

class _SignInState extends State<_SignIn> {
  final _phone = TextEditingController(), _otp = TextEditingController();
  bool _sent = false, _busy = false;
  String _error = '';

  String get _digits {
    final d = _phone.text.replaceAll(RegExp(r'\D'), '');
    return d.length > 10 ? d.substring(d.length - 10) : d;
  }

  Future<void> _go() async {
    setState(() { _busy = true; _error = ''; });
    try {
      if (!_sent) {
        if (_digits.length != 10) throw 'Enter your 10-digit WhatsApp number.';
        await ApiService.standaloneRequestOtp(phone: _digits);
        setState(() => _sent = true);
      } else {
        if (_otp.text.trim().isEmpty) throw 'Enter the code we sent on WhatsApp.';
        final res = await ApiService.standaloneVerifyOtp(phone: _digits, otp: _otp.text.trim());
        await _auth.set(res['token'] as String? ?? '');
        if (mounted) Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() => _error = e is String ? e : (e is ApiException ? e.message : 'Could not sign in. Check the internet and try again.'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _ink,
      appBar: AppBar(backgroundColor: _ink, elevation: 0),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(24, 8, 24, 24), children: [
          Text('Sign in with WhatsApp', style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(_sent ? 'We sent a code to +91 $_digits on WhatsApp.' : 'We send a code to your WhatsApp. No password.',
              style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 24),
          TextField(
            controller: _phone,
            enabled: !_sent,
            autofocus: true,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'WhatsApp number', prefixText: '+91 ', border: OutlineInputBorder()),
          ),
          if (_sent) ...[
            const SizedBox(height: 14),
            TextField(
              controller: _otp,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Code from WhatsApp', border: OutlineInputBorder()),
              onSubmitted: (_) => _go(),
            ),
            TextButton(onPressed: _busy ? null : () => setState(() { _sent = false; _otp.clear(); }), child: const Text('Change number')),
          ],
          if (_error.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(_error, style: const TextStyle(color: Color(0xFFFF8A80))),
          ],
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _busy ? null : _go,
            style: FilledButton.styleFrom(backgroundColor: _orange, minimumSize: const Size.fromHeight(52)),
            child: _busy
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(_sent ? 'Sign in' : 'Send code on WhatsApp', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          ),
        ]),
      ),
    );
  }
}
