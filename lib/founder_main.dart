// The founder's Altron as its own small Android app (24 Oct 2026). No login screen: the app carries its own key, built
// in at build time, and trades it for a sign-in each time it opens.
//
// It listens for "Altron" all the time (WakeService, offline, on the phone). Saying it brings a thin glowing strip along
// the top of the screen, nothing else (founder, 25 Oct 2026): Altron's live voice (the /live/v2 page in founder mode,
// running out of sight under the strip) answers about the leads and the course. The strip glows brighter while Altron
// speaks. When the talk is over (the page rests after a quiet spell, or the founder taps the strip) it steps aside, the
// microphone is let go, and listening starts again.
//
// Built from this entry point only, so none of the website's browser-only code comes in:
//   python tools/fetch_vosk_model.py
//   flutter build apk --release --flavor altron -t lib/founder_main.dart --dart-define=FOUNDER_KEY=<the key>

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import 'constants/api_constants.dart';
import 'screens/admin/founder_altron_screen.dart' show founderAltronUrl;

const _key = String.fromEnvironment('FOUNDER_KEY');
const _native = MethodChannel('altron/native');

void main() => runApp(const FounderApp());

class FounderApp extends StatelessWidget {
  const FounderApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Altron',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorSchemeSeed: const Color(0xFF14343F), useMaterial3: true, scaffoldBackgroundColor: Colors.transparent),
        home: const _Card(),
      );
}

class _Card extends StatefulWidget {
  const _Card();

  @override
  State<_Card> createState() => _CardState();
}

class _CardState extends State<_Card> with SingleTickerProviderStateMixin {
  String? _token;
  String? _problem;
  WebViewController? _web;
  bool _talking = false;
  bool _speaking = false;                  // Altron is talking: the strip glows brighter
  late final _glow = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _native.setMethodCallHandler((call) async {
      if (call.method == 'woke') _talk();
    });
    _open();
  }

  Future<void> _open() async {
    setState(() => _problem = null);
    try {
      final r = await http
          .post(Uri.parse('${ApiConstants.baseUrl}/founder/key-login'), headers: {'X-Founder-Key': _key})
          .timeout(const Duration(seconds: 20));
      if (r.statusCode != 200) throw r.statusCode == 401 ? 'This app is not set up for you. Ask for a new build.' : 'Could not reach Altrobyte.';
      _token = '${(jsonDecode(r.body) as Map)['token']}';
    } catch (e) {
      setState(() => _problem = e is String ? e : 'No internet? Check it and try again.');
      return;
    }
    if (!(await Permission.microphone.request()).isGranted) {
      setState(() => _problem = 'Altron needs the microphone. Allow it in Settings → Apps → Altron → Permissions.');
      return;
    }
    try {
      await _native.invokeMethod('setup');           // notifications, over other apps, battery; starts listening
    } catch (_) {}
    _talk();                                         // opened by hand, or by a wake: Altron is ready to hear you
  }

  Future<void> _talk() async {
    final t = _token;
    if (t == null || _talking) return;
    final web = WebViewController(onPermissionRequest: (req) => req.grant())
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0F2530))
      ..addJavaScriptChannel('AltronHost', onMessageReceived: (m) {
        try {
          final msg = jsonDecode(m.message) as Map;
          if (msg['type'] != 'state') return;
          if (msg['state'] == 'paused' || msg['state'] == 'error' || msg['state'] == 'out_of_minutes') {
            _rest();
          } else if (mounted) {
            setState(() => _speaking = msg['state'] == 'talk');
          }
        } catch (_) {}
      });
    final p = web.platform;
    if (p is AndroidWebViewController) await p.setMediaPlaybackRequiresUserGesture(false);
    await web.loadRequest(Uri.parse(founderAltronUrl(t)));
    if (mounted) setState(() {
      _web = web;
      _talking = true;
    });
  }

  /// The talk is over: the page lets the microphone go, the card steps aside, and the phone listens for "Altron" again.
  Future<void> _rest() async {
    if (!_talking) return;
    await _web?.loadRequest(Uri.parse('about:blank'));
    setState(() {
      _talking = false;
      _speaking = false;
      _web = null;
    });
    try {
      await _native.invokeMethod('rest');
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    // The window itself is only a strip tall (AltronActivity); the voice page runs under the light, out of sight.
    final bad = _problem != null;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: bad ? _open : _rest,
        child: Stack(children: [
          if (_web != null) Positioned.fill(child: Opacity(opacity: 0.01, child: WebViewWidget(controller: _web!))),
          Align(
            alignment: Alignment.topCenter,
            child: AnimatedBuilder(
              animation: _glow,
              builder: (_, __) {
                final t = _glow.value;
                final colors = bad
                    ? const [Color(0xFFFF5252), Color(0xFFFF8A80), Color(0xFFFF5252)]
                    : const [Color(0xFF00E5FF), Color(0xFF76FF03), Color(0xFF00E5FF)];
                final strong = bad || _speaking;
                return Container(
                  height: strong ? 6 : 4,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: colors,
                      begin: Alignment(-1 + 2 * t - 1, 0),
                      end: Alignment(1 + 2 * t - 1, 0),
                      tileMode: TileMode.mirror,
                    ),
                    boxShadow: [
                      BoxShadow(color: colors[1].withValues(alpha: strong ? 0.9 : 0.55), blurRadius: strong ? 18 : 10, spreadRadius: strong ? 2 : 0),
                    ],
                  ),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}
