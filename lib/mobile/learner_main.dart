// Altrobyte Lab on Android, the learner app for the Play Store (30 Oct 2026, founder: most learners come on a phone).
// The learning itself is the website's fast pages (/learn, its lessons with Altron, live classes), so a lesson is the
// same on the web and in the app; the app adds a native WhatsApp sign-in, the microphone for Altron and the back button.
// lib/main.dart is web-only and does not build for Android.
//
//   flutter run --flavor lab -t lib/mobile/learner_main.dart
//   flutter build appbundle --release --flavor lab -t lib/mobile/learner_main.dart

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../services/api_service.dart';

const _ink = Color(0xFF0A1220);
const _orange = Color(0xFFFF6A1A);
const _site = 'https://altrobytelab.com';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: _ink, systemNavigationBarColor: _ink));
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Altrobyte Lab',
    theme: ThemeData(colorSchemeSeed: _orange, brightness: Brightness.dark, scaffoldBackgroundColor: _ink),
    home: const _Learn(),
  ));
}

class _Learn extends StatefulWidget {
  const _Learn();
  @override
  State<_Learn> createState() => _LearnState();
}

class _LearnState extends State<_Learn> {
  late final WebViewController _web;
  bool _loading = true, _offline = false;
  String _token = '';

  @override
  void initState() {
    super.initState();
    _web = WebViewController(onPermissionRequest: (req) => req.grant())
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(_ink)
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: _route,
        onPageStarted: (_) => setState(() { _loading = true; _offline = false; }),
        onPageFinished: (_) => _afterLoad(),
        onWebResourceError: (e) {
          if (e.isForMainFrame ?? true) setState(() { _offline = true; _loading = false; });
        },
      ));
    final p = _web.platform;
    if (p is AndroidWebViewController) p.setMediaPlaybackRequiresUserGesture(false);
    SharedPreferences.getInstance().then((prefs) {
      _token = prefs.getString('student_token') ?? '';
      _web.loadRequest(Uri.parse('$_site/learn'));
    });
  }

  /// The site keeps the sign-in where its Flutter pages do (localStorage 'flutter.student_token'); the app hands its own
  /// over once, and reloads so the page sees it.
  Future<void> _afterLoad() async {
    setState(() => _loading = false);
    if (_token.isEmpty) return;
    final t = jsonEncode(jsonEncode(_token));
    await _web.runJavaScript(
        "if (location.host === 'altrobytelab.com' && localStorage.getItem('flutter.student_token') !== $t) {"
        " localStorage.setItem('flutter.student_token', $t); location.reload(); }");
  }

  /// The learning pages stay in the app; sign-in is native; everything else (WhatsApp, registering and paying, other
  /// sites) opens outside, in the browser or the app it belongs to.
  NavigationDecision _route(NavigationRequest r) {
    final u = Uri.tryParse(r.url);
    if (u == null) return NavigationDecision.prevent;
    final ours = u.host == 'altrobytelab.com' || u.host == 'www.altrobytelab.com';
    if (ours && u.path == '/signin') {
      _signIn(u.queryParameters['next'] ?? '/learn');
      return NavigationDecision.prevent;
    }
    if (ours && u.queryParameters['signed_out'] == '1') {   // the account was deleted on /delete-account
      _token = '';
      SharedPreferences.getInstance().then((p) => p.remove('student_token'));
    }
    // Registering and paying (/join, /pricing) open in the browser: Play's rules on paying for digital content.
    if (ours && (u.path == '/' || u.path == '/delete-account' ||
        const ['/learn', '/live-sessions', '/class', '/live/'].any(u.path.startsWith))) {
      return NavigationDecision.navigate;
    }
    if (u.scheme == 'about' || u.scheme == 'data') return NavigationDecision.navigate;
    launchUrl(u, mode: LaunchMode.externalApplication);
    return NavigationDecision.prevent;
  }

  Future<void> _signIn(String next) async {
    final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const _SignIn()));
    if (ok != true || !mounted) return;
    _token = (await SharedPreferences.getInstance()).getString('student_token') ?? '';
    await Permission.microphone.request();   // Altron listens; asked once, right after signing in
    final path = next.startsWith('/') && !next.startsWith('//') ? next : '/learn';
    await _web.loadRequest(Uri.parse('$_site$path'));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _web.canGoBack()) {
          await _web.goBack();
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: _ink,
        body: SafeArea(
          child: Stack(children: [
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
                  FilledButton(
                    onPressed: () => _web.reload(),
                    style: FilledButton.styleFrom(backgroundColor: _orange),
                    child: const Text('Try again'),
                  ),
                ]),
              ),
          ]),
        ),
      ),
    );
  }
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
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('student_token', res['token'] as String? ?? '');
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
                : Text(_sent ? 'Sign in' : 'Send code on WhatsApp', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ]),
      ),
    );
  }
}
