import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../desktop/industrial_flow.dart' show IndProgramme, indInk, indGold, indPanel;
import '../desktop/note_bridge.dart' show tutorPage, showSectionScript;
import '../services/api_service.dart';

/// A programme's lesson on the plant's tablet (30 Oct 2026): the note with its drills fills the screen and Altron teaches
/// it from a strip at the bottom, in the worker mode. The same messages as on the desktop pass between the two: the part
/// Altron is on (the note glides there), its words (the note follows them), what the worker did on a drill (Altron
/// reacts), and which parts have an activity (Altron does not move on before it is done). Pops when the lesson is complete.
class TabletLessonScreen extends StatefulWidget {
  final IndProgramme programme;
  const TabletLessonScreen({super.key, required this.programme});

  @override
  State<TabletLessonScreen> createState() => _TabletLessonScreenState();
}

class _TabletLessonScreenState extends State<TabletLessonScreen> {
  WebViewController? _note, _live;
  String? _problem;
  String? _needs;
  bool _needsSent = false, _done = false;
  String _state = 'Altron is getting ready…';

  @override
  void initState() {
    super.initState();
    _start();
  }

  WebViewController _controller() {
    final c = WebViewController(onPermissionRequest: (req) => req.grant())..setJavaScriptMode(JavaScriptMode.unrestricted);
    final p = c.platform;
    if (p is AndroidWebViewController) p.setMediaPlaybackRequiresUserGesture(false);
    return c;
  }

  Future<void> _start() async {
    try {
      await Permission.microphone.request();
      final note = await ApiService.noteTutor(widget.programme.contentId, 'hi');
      final html = (note['html'] as String?) ?? '';
      final n = _controller()
        ..addJavaScriptChannel('AltronHost', onMessageReceived: (m) => _fromNote(m.message))
        ..setBackgroundColor(const Color(0xFFF6F3EC));
      await n.loadHtmlString(tutorPage(html), baseUrl: 'https://altrobytelab.com/');
      final token = (await SharedPreferences.getInstance()).getString('student_token') ?? '';
      final q = {
        'note': '${widget.programme.contentId}', 'teach': '1', 'strip': '1', 'lang': 'hi', 'compact': '1', 'autostart': '1', 'aud': 'worker',
      }.entries.map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}').join('&');
      final l = _controller()
        ..addJavaScriptChannel('AltronHost', onMessageReceived: (m) => _fromAltron(m.message))
        ..setBackgroundColor(indInk);
      await l.loadRequest(Uri.parse('https://altrobytelab.com/live/v2/index.html?$q#t=${Uri.encodeComponent(token)}'));
      if (mounted) setState(() { _note = n; _live = l; });
    } catch (e) {
      if (mounted) setState(() => _problem = 'The lesson could not open. Check the internet and try again.');
    }
  }

  Map<String, dynamic>? _json(String s) {
    try {
      final v = jsonDecode(s);
      return v is Map<String, dynamic> ? v : null;
    } catch (_) {
      return null;
    }
  }

  void _fromNote(String raw) {
    final m = _json(raw);
    if (m == null) return;
    final needs = m['needs'];
    if (needs is List) _needs = jsonEncode(needs);
    final did = m['did'];
    if (did is String) _live?.runJavaScript('window.altronDid && window.altronDid(${jsonEncode(did)})');
  }

  void _fromAltron(String raw) {
    final m = _json(raw);
    if (m == null) return;
    if (!_needsSent && _needs != null) {
      _needsSent = true;
      _live?.runJavaScript('window.altronNeeds && window.altronNeeds(${_needs!})');
    }
    switch (m['type']) {
      case 'section':
        final part = (m['part'] as num?)?.toInt();
        if (part != null && part >= 1) _note?.runJavaScript(showSectionScript(part - 1, bring: true));
      case 'said':
        _note?.runJavaScript('window.__altroSaid && window.__altroSaid(${jsonEncode(m['text'] ?? '')})');
      case 'state':
        final st = '${m['state']}';
        if (st == 'done' && !_done) {
          _done = true;
          Future.delayed(const Duration(seconds: 3), () { if (mounted) Navigator.of(context).pop(true); });
        }
        if (mounted) {
          setState(() => _state = switch (st) {
                'talking' => 'Altron is explaining',
                'listening' => 'Altron is listening: speak or do the activity',
                'done' => 'Lesson complete. The test is next.',
                'out_of_minutes' => 'Today\'s training time is used up.',
                'error' => 'Altron lost the connection. Tap the play button below.',
                _ => _state,
              });
        }
    }
  }

  Future<bool> _leave() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Leave the lesson?'),
        content: const Text('The test comes after the lesson. Leave now and go to the test?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Stay')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Go to the test')),
        ],
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _leave() && context.mounted) Navigator.of(context).pop(true);
      },
      child: Scaffold(
        backgroundColor: indInk,
        appBar: AppBar(
          backgroundColor: indInk,
          foregroundColor: Colors.white,
          title: Row(children: [
            Icon(widget.programme.icon, color: indGold),
            const SizedBox(width: 10),
            Text(widget.programme.title, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ]),
          actions: [
            Center(child: Text(_state, style: GoogleFonts.inter(color: Colors.white70, fontSize: 13))),
            const SizedBox(width: 16),
          ],
        ),
        body: _problem != null
            ? Center(child: Text(_problem!, style: GoogleFonts.inter(color: Colors.white)))
            : _note == null
                ? const Center(child: CircularProgressIndicator(color: indGold))
                : Column(children: [
                    Expanded(child: WebViewWidget(controller: _note!)),
                    Container(height: 96, color: indPanel, child: WebViewWidget(controller: _live!)),
                  ]),
      ),
    );
  }
}
