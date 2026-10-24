// The founder's own Altron (24 Oct 2026): the same live voice as in the notes, answering about the leads and the course
// content. The voice page is /live/v2 in founder mode; the server only lets an admin in, and its tools read the CRM and
// the notes with the admin's sign-in. On the phone it runs inside the app; on the web it opens in its own tab.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

/// The voice page in founder mode. The sign-in goes in the #fragment, which no server receives.
String founderAltronUrl(String token, {String lang = 'hi', String question = ''}) {
  final q = {'founder': '1', 'lang': lang, 'compact': '1', 'autostart': '1', if (question.isNotEmpty) 'q': question};
  final query = q.entries.map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}').join('&');
  return 'https://altrobytelab.com/live/v2/index.html?$query#t=${Uri.encodeComponent(token)}';
}

/// Opens Altron: a screen in the app on a phone, a tab on the web.
Future<void> openFounderAltron(BuildContext context) async {
  final token = (await SharedPreferences.getInstance()).getString('token') ?? '';
  if (kIsWeb) {
    await launchUrl(Uri.parse(founderAltronUrl(token)), webOnlyWindowName: 'altron');
    return;
  }
  if (!context.mounted) return;
  await Navigator.of(context).push(MaterialPageRoute(builder: (_) => FounderAltronScreen(token: token)));
}

class FounderAltronScreen extends StatefulWidget {
  final String token;
  const FounderAltronScreen({super.key, required this.token});

  @override
  State<FounderAltronScreen> createState() => _FounderAltronScreenState();
}

class _FounderAltronScreenState extends State<FounderAltronScreen> {
  WebViewController? _web;
  String? _problem;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    // The phone's own microphone permission first: the page's request is only granted when the app holds it.
    if (!(await Permission.microphone.request()).isGranted) {
      setState(() => _problem = 'Altron needs the microphone. Allow it in Settings → Apps → Altrobyte → Permissions.');
      return;
    }
    final web = WebViewController(onPermissionRequest: (req) => req.grant())
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0F2530));
    final p = web.platform;
    if (p is AndroidWebViewController) await p.setMediaPlaybackRequiresUserGesture(false); // Altron speaks at once
    await web.loadRequest(Uri.parse(founderAltronUrl(widget.token)));
    if (mounted) setState(() => _web = web);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F2530),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F2530),
        foregroundColor: Colors.white,
        title: Text('Altron', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        actions: [
          IconButton(tooltip: 'Start again', onPressed: () => _web?.reload(), icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: _problem != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(_problem!, textAlign: TextAlign.center, style: GoogleFonts.inter(color: Colors.white, fontSize: 15, height: 1.5)),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: openAppSettings, child: const Text('Open Settings')),
                ]),
              ),
            )
          : _web == null
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : WebViewWidget(controller: _web!),
    );
  }
}
