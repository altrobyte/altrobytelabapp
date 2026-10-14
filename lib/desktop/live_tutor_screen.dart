// Altron with the camera, inside the trainer: it looks at the learner's bench through the computer's camera and talks them
// through the topic they are on (Gemini Live). The page itself is the website's /live page, shown in the app's own browser
// view; the app hands it the learner's sign-in in the address's #fragment, which never reaches any server, and lets that
// one site use the camera and the microphone.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_windows/webview_windows.dart';

import '../constants/app_colors.dart';
import '../services/api_service.dart';
import 'visual_page.dart';

const liveOrigin = 'https://altrobytelab.com';

/// The address of the camera tutor for a topic (a note), an experiment, or a module. [token] goes in the fragment.
String liveTutorUrl({int? noteId, int? labId, int? moduleId, String token = ''}) {
  final q = <String, String>{
    'embed': '1',
    if (noteId != null) 'note': '$noteId',
    if (labId != null) 'lab': '$labId',
    if (moduleId != null) 'module': '$moduleId',
  };
  final query = q.entries.map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}').join('&');
  return '$liveOrigin/live/?$query${token.isEmpty ? '' : '#t=${Uri.encodeComponent(token)}'}';
}

/// Camera and microphone are allowed for our own site only; nothing else may ask for them.
WebviewPermissionDecision livePermission(String url, WebviewPermissionKind kind) {
  final ours = url.startsWith('$liveOrigin/');
  final needed = kind == WebviewPermissionKind.camera || kind == WebviewPermissionKind.microphone;
  return ours && needed ? WebviewPermissionDecision.allow : WebviewPermissionDecision.deny;
}

class LiveTutorScreen extends StatefulWidget {
  final int? noteId;
  final int? labId;
  final int? moduleId;
  final String title;
  const LiveTutorScreen({super.key, this.noteId, this.labId, this.moduleId, this.title = ''});

  @override
  State<LiveTutorScreen> createState() => _LiveTutorScreenState();
}

class _LiveTutorScreenState extends State<LiveTutorScreen> {
  final _web = WebviewController();
  bool _ready = false;
  String? _problem;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      if (await WebviewController.getWebViewVersion() == null) {
        setState(() => _problem = 'This computer is missing Microsoft Edge WebView2, which the camera tutor needs.');
        return;
      }
      await _web.initialize();
      await _web.setBackgroundColor(const Color(0xFF0D1726));
      await _web.setPopupWindowPolicy(WebviewPopupWindowPolicy.deny);
      final token = await ApiService.learnerToken() ?? '';
      await _web.loadUrl(liveTutorUrl(noteId: widget.noteId, labId: widget.labId, moduleId: widget.moduleId, token: token));
      if (mounted) setState(() => _ready = true);
    } catch (e) {
      if (mounted) setState(() => _problem = 'The camera tutor could not open here.');
    }
  }

  @override
  void dispose() {
    _web.dispose(); // closing the screen ends the session and lets go of the camera
    super.dispose();
  }

  void _inBrowser() =>
      openExternal(liveTutorUrl(noteId: widget.noteId, labId: widget.labId, moduleId: widget.moduleId).replaceFirst('embed=1&', ''));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1726),
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Text(widget.title.isEmpty ? 'Altron · camera' : 'Altron · ${widget.title}',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16, color: Colors.white)),
        actions: [
          TextButton.icon(
            onPressed: _inBrowser,
            icon: const Icon(Icons.phone_android_rounded, color: Colors.white70, size: 18),
            label: const Text('Use my phone instead', style: TextStyle(color: Colors.white70)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _problem != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.videocam_off_rounded, size: 40, color: Colors.white54),
                  const SizedBox(height: 12),
                  Text(_problem!, textAlign: TextAlign.center, style: GoogleFonts.inter(color: Colors.white, fontSize: 15)),
                  const SizedBox(height: 16),
                  FilledButton.icon(onPressed: _inBrowser, icon: const Icon(Icons.open_in_browser_rounded), label: const Text('Open in the browser')),
                ]),
              ),
            )
          : !_ready
              ? const Center(child: CircularProgressIndicator())
              : Webview(_web, permissionRequested: (url, kind, userInitiated) => livePermission(url, kind)),
    );
  }
}
