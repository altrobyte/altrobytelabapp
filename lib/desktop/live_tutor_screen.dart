// Altron by voice, inside the trainer (Gemini Live): it talks the learner through the topic or the course they are on, and
// looks at their bench when they turn the camera on (it starts off). The page is shipped inside the app (assets/live, copied
// from web/live/v2 by tools/sync_desktop_app.py) and served to the app's browser view from that folder under a private
// name, so a website deploy can never break it; when the folder is missing the website's copy (/live/v2/) is used. The app
// hands the page the learner's sign-in in the address's #fragment, which never reaches any server, and lets only that page
// use the camera and the microphone.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_windows/webview_windows.dart';

import '../constants/app_colors.dart';
import '../services/api_service.dart';
import 'visual_page.dart';

const liveOrigin = 'https://altrobytelab.com';
const liveAppHost = 'live.altron.example'; // the private name the app serves its own copy of the page under
const classAppHost = 'class.altron.example'; // and the class player's

/// Lets Altron speak as soon as a session starts: the page plays sound without waiting for a tap. Called once, before any
/// browser view is made; a failure only means the learner taps ▶ once.
Future<void> initLiveEnvironment() async {
  try {
    await WebviewController.initializeEnvironment(additionalArguments: '--autoplay-policy=no-user-gesture-required');
  } catch (_) {}
}

/// A page the app ships (next to the exe, in data/flutter_assets/assets/<name>/index.html): its folder, or null.
String? bundledFolder(String name) {
  try {
    final sep = Platform.pathSeparator;
    final dir = [File(Platform.resolvedExecutable).parent.path, 'data', 'flutter_assets', 'assets', name].join(sep);
    return File('$dir${sep}index.html').existsSync() ? dir : null;
  } catch (_) {
    return null;
  }
}

/// The app's own copy of the Live page, or null.
String? bundledLiveFolder() => bundledFolder('live');

/// Opens the class player in [web] for a built-in class or a module note written as a class: the app's own copy when it
/// is there, else the website's. It starts at once (the app lets it play sound without a tap).
Future<void> loadClass(WebviewController web, {String? classId, int? noteId, String lang = 'en'}) async {
  final token = await ApiService.learnerToken() ?? '';
  var base = '$liveOrigin/class/index.html';
  final folder = bundledFolder('class');
  if (folder != null) {
    try {
      await web.addVirtualHostNameMapping(classAppHost, folder, WebviewHostResourceAccessKind.allow);
      base = 'https://$classAppHost/index.html';
    } catch (_) {}
  }
  final q = <String, String>{if (classId != null) 'id': classId, if (noteId != null) 'note': '$noteId', 'lang': lang, 'embed': '1', 'autostart': '1'};
  final query = q.entries.map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}').join('&');
  await web.loadUrl('$base?$query${token.isEmpty ? '' : '#t=${Uri.encodeComponent(token)}'}');
}

/// The address of the Live page (version 2) at [base], for a course, a topic (note) or an experiment.
String liveV2Url(String base,
    {String? course, int? noteId, int? labId, bool steps = false, bool teach = false, int fromPart = 0, String lang = 'en', bool compact = true, bool autostart = true, String token = ''}) {
  final q = <String, String>{
    if (course != null) 'course': course,
    if (noteId != null) 'note': '$noteId',
    if (labId != null) 'lab': '$labId',
    if (steps) 'steps': '1',
    if (teach) 'teach': '1',
    if (fromPart > 1) 'from': '$fromPart',
    'lang': lang,
    if (compact) 'compact': '1',
    if (autostart) 'autostart': '1',
  };
  final query = q.entries.map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}').join('&');
  return '$base?$query${token.isEmpty ? '' : '#t=${Uri.encodeComponent(token)}'}';
}

/// Opens the Live page in [web]: the app's own copy when it is there, else the website's.
Future<void> loadLive(WebviewController web,
    {String? course, int? noteId, int? labId, bool steps = false, bool teach = false, int fromPart = 0, String lang = 'en', bool compact = true, bool autostart = true}) async {
  final token = await ApiService.learnerToken() ?? '';
  var base = '$liveOrigin/live/v2/index.html';
  final folder = bundledLiveFolder();
  if (folder != null) {
    try {
      await web.addVirtualHostNameMapping(liveAppHost, folder, WebviewHostResourceAccessKind.allow);
      base = 'https://$liveAppHost/index.html';
    } catch (_) {}
  }
  await web.loadUrl(liveV2Url(base, course: course, noteId: noteId, labId: labId, steps: steps, teach: teach, fromPart: fromPart, lang: lang, compact: compact, autostart: autostart, token: token));
}

/// A message the Live page posted (window.chrome.webview.postMessage of a JSON string), as a map; null if it is not one.
Map<String, dynamic>? liveMessage(dynamic m) {
  try {
    final v = m is String ? jsonDecode(m) : m;
    return v is Map ? Map<String, dynamic>.from(v) : null;
  } catch (_) {
    return null;
  }
}

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

/// Camera and microphone are allowed for our own page only (the app's copy or the website's); nothing else may ask for them.
WebviewPermissionDecision livePermission(String url, WebviewPermissionKind kind) {
  final ours = url.startsWith('$liveOrigin/') || url.startsWith('https://$liveAppHost/') || url.startsWith('https://$classAppHost/');
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
    ApiService.trainerEvent('camera_opened', detail: widget.title);
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
      await loadLive(_web, noteId: widget.noteId, labId: widget.labId, compact: false);
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
