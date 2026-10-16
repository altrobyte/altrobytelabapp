// A live class with Altron, inside the trainer: the board on the left, Altron's voice and captions on the right. The page
// is the class player (web/class, shipped inside the app as assets/class) served from the app's own folder; it holds the
// class and checks every answer itself, and keeps the learner's progress on the server. "Back to my learning path" on the
// page closes this screen.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_windows/webview_windows.dart';

import '../constants/app_colors.dart';
import '../services/api_service.dart';
import 'help_button.dart';
import 'live_tutor_screen.dart';

class ClassScreen extends StatefulWidget {
  /// A built-in class ("roadmap") or a module note written as a class.
  final String? classId;
  final int? noteId;
  final String title;
  const ClassScreen({super.key, this.classId, this.noteId, required this.title});

  @override
  State<ClassScreen> createState() => _ClassScreenState();
}

class _ClassScreenState extends State<ClassScreen> {
  WebviewController? _web;
  StreamSubscription? _messages;
  String? _problem;

  @override
  void initState() {
    super.initState();
    _open();
    ApiService.trainerEvent('camera_opened', detail: 'class: ${widget.title}');
  }

  Future<void> _open() async {
    try {
      if (await WebviewController.getWebViewVersion() == null) {
        setState(() => _problem = 'This computer is missing Microsoft Edge WebView2, which the live class needs.');
        return;
      }
      final lang = (await SharedPreferences.getInstance()).getString('tutor_lang') == 'hi' ? 'hi' : 'en';
      final web = WebviewController();
      await web.initialize();
      await web.setBackgroundColor(const Color(0xFFF4F6FA));
      await web.setPopupWindowPolicy(WebviewPopupWindowPolicy.deny);
      _messages = web.webMessage.listen((raw) {
        final m = liveMessage(raw);
        if (m?['type'] == 'close' && mounted) Navigator.of(context).maybePop();
      });
      await loadClass(web, classId: widget.classId, noteId: widget.noteId, lang: lang);
      if (!mounted) {
        web.dispose();
        return;
      }
      setState(() => _web = web);
    } catch (_) {
      if (mounted) setState(() => _problem = 'The live class could not open here.');
    }
  }

  @override
  void dispose() {
    _messages?.cancel();
    final web = _web;
    // Pause first, so the page reports the talk it used and saves where the learner is; then let go of the microphone.
    if (web != null) {
      web.executeScript('window.altronPause && window.altronPause()').catchError((_) => null).whenComplete(
          () => Future.delayed(const Duration(milliseconds: 500), web.dispose));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Text('Live class · ${widget.title}', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16, color: Colors.white)),
        actions: [HelpButton(where: () => 'Live class: ${widget.title}'), const SizedBox(width: 6)],
      ),
      body: _problem != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(_problem!, textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 15)),
              ),
            )
          : _web == null
              ? const Center(child: CircularProgressIndicator())
              : Webview(_web!, permissionRequested: (url, kind, userInitiated) => livePermission(url, kind)),
    );
  }
}
