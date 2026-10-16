// An interactive lesson page (a course's own page, or the note an experiment was made from) shown inside the app.
// The same closed web view as the note tutor: the page may run its own script but can reach nothing. When the Windows web
// view is missing the page opens in the browser instead.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_windows/webview_windows.dart';
import '../constants/app_colors.dart';
import 'note_tutor.dart' show tutorProblem;
import 'visual_page.dart';
import 'web_scroll.dart';

class LessonScreen extends StatefulWidget {
  final String title;

  /// Fetches the page. It is called when the screen opens, so nothing is downloaded before the learner asks for it.
  final Future<String> Function() load;

  /// The section to open and show first (a course page's "section 3"), when the step the learner is on points to one.
  final int? section;
  const LessonScreen({super.key, required this.title, required this.load, this.section});

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  final _web = WebviewController();
  late final _pan = PanScroller((script) => _web.executeScript(script));
  StreamSubscription? _messages;
  String? _html;
  String? _problem; // the page could not be fetched
  bool _ready = false;
  bool _inBrowser = false; // no web view here: the page was opened in the browser

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    setState(() => _problem = null);
    try {
      _html = await widget.load();
      if ((_html ?? '').trim().isEmpty) throw Exception('This lesson has no page yet.');
    } catch (e) {
      if (mounted) setState(() => _problem = tutorProblem(e));
      return;
    }
    try {
      if (await WebviewController.getWebViewVersion() == null) throw Exception('missing');
      await _web.initialize();
      await _web.setBackgroundColor(Colors.white);
      await _web.setPopupWindowPolicy(WebviewPopupWindowPolicy.deny);
      _messages = _web.webMessage.listen((m) {
        if (m is Map && m['open'] is String) openExternal(m['open'] as String); // a link in the page: the browser opens it
      });
      await _web.loadStringContent(tutorPage(_html!));
      if (mounted) setState(() => _ready = true);
      if (widget.section != null) unawaited(_showSection(widget.section!));
    } catch (_) {
      await openLessonHtml(_html!);
      if (mounted) setState(() => _inBrowser = true);
    }
  }

  /// Opens section [n] of a course page (its boxes are <section id="sN">, opened by the page's own toggle) and scrolls to
  /// it. Tried a few times while the page finishes loading; a page without such a section is left as it is.
  Future<void> _showSection(int n) async {
    final script = "(function(){var c=document.getElementById('s$n');if(!c)return false;"
        "if(!c.classList.contains('open')&&typeof toggle==='function')toggle('s$n');"
        "c.scrollIntoView({behavior:'smooth',block:'start'});return true;})()";
    for (var i = 0; i < 6; i++) {
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      try {
        if (await _web.executeScript(script) == true) return;
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _messages?.cancel();
    _pan.dispose();
    _web.dispose();
    super.dispose();
  }

  Widget _body() {
    if (_problem != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline_rounded, size: 40, color: Colors.black38),
          const SizedBox(height: 10),
          Text(_problem!, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _start, child: const Text('Try again')),
        ]),
      );
    }
    if (_inBrowser) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.open_in_browser_rounded, size: 40, color: AppColors.primary),
          const SizedBox(height: 10),
          Text('The lesson opened in your browser.', style: GoogleFonts.inter()),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: () => openLessonHtml(_html ?? ''), child: const Text('Open it again')),
        ]),
      );
    }
    if (!_ready) return const Center(child: CircularProgressIndicator());
    // A two-finger swipe on a touchpad reaches Flutter, not the web view, so it is handed on as a scroll of the page.
    return Listener(
      onPointerPanZoomUpdate: (e) => _pan.add(e.panDelta),
      onPointerPanZoomEnd: (_) => _pan.end(),
      child: Webview(_web),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Text(widget.title, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16)),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 18),
            label: const Text('Back to my trainer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: _body(),
    );
  }
}
