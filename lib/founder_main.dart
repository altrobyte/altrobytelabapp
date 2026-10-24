// The founder's Altron as its own small Android app (24 Oct 2026). No login screen: the app carries its own key, built
// in at build time, and trades it for a sign-in each time it opens.
//
// It listens for "Altron" all the time (WakeService, offline, on the phone). Saying it opens a card over whatever app is
// open: Altron's live voice (the /live/v2 page in founder mode) answers about the leads and the course. When the talk
// is over (the page rests after a quiet spell, or the founder taps outside the card) the card steps aside, the
// microphone is let go, and listening starts again.
//
// Built from this entry point only, so none of the website's browser-only code comes in:
//   python tools/fetch_vosk_model.py
//   flutter build apk --release --flavor altron -t lib/founder_main.dart --dart-define=FOUNDER_KEY=<the key>

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
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

class _CardState extends State<_Card> {
  String? _token;
  String? _problem;
  WebViewController? _web;
  bool _talking = false;

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
    if (t == null) return;
    final web = WebViewController(onPermissionRequest: (req) => req.grant())
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0F2530))
      ..addJavaScriptChannel('AltronHost', onMessageReceived: (m) {
        try {
          final msg = jsonDecode(m.message) as Map;
          if (msg['type'] == 'state' && (msg['state'] == 'paused' || msg['state'] == 'error' || msg['state'] == 'out_of_minutes')) _rest();
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
      _web = null;
    });
    try {
      await _native.invokeMethod('rest');
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(children: [
        // Tapping outside the card ends the talk.
        Positioned.fill(child: GestureDetector(onTap: _rest, child: Container(color: Colors.black.withValues(alpha: 0.35)))),
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            height: h * 0.62,
            margin: const EdgeInsets.fromLTRB(10, 0, 10, 14),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: const Color(0xFF0F2530),
              borderRadius: BorderRadius.circular(22),
              boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 24)],
            ),
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 6, 0),
                child: Row(children: [
                  Text('Altron', style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  IconButton(tooltip: 'Done', onPressed: _rest, icon: const Icon(Icons.close_rounded, color: Colors.white70)),
                ]),
              ),
              Expanded(
                child: _problem != null
                    ? Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Text(_problem!, textAlign: TextAlign.center, style: GoogleFonts.inter(color: Colors.white, fontSize: 15)),
                          const SizedBox(height: 14),
                          FilledButton(onPressed: _open, child: const Text('Try again')),
                        ]),
                      )
                    : _web == null
                        ? Center(
                            child: Text(_talking ? '' : 'Say "Altron"', style: GoogleFonts.inter(color: Colors.white70, fontSize: 15)))
                        : WebViewWidget(controller: _web!),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}
