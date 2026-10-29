import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../constants/app_colors.dart';
import '../../desktop/note_bridge.dart';
import '../../widgets/auth_sheet.dart';

/// A note on the website, taught the way the desktop trainer teaches it (29 Oct 2026, founder: the free web version must
/// feel the same): the lesson's steps on the left, the note across the middle, Altron in a slim strip underneath that
/// starts by itself. As Altron moves to a section it glows and the page glides to it, then follows Altron's words; the
/// learner scrolling on their own pauses that. At the end of the lesson the strip closes and the next note opens.
///
/// The note runs in a sandboxed frame (srcdoc, no same-origin), with the same small bridge the desktop app uses; the two
/// frames talk to this page by message only.
class StudentNotesViewerScreen extends StatefulWidget {
  final String title;
  final String htmlContent;
  final String moduleColor;

  /// The note's id: with it, Altron (the AI trainer) teaches this note by voice.
  final int? contentId;

  /// The next note of the module: when this lesson is complete it opens by itself after a short countdown.
  final String? nextTitle;

  const StudentNotesViewerScreen({
    super.key,
    this.contentId,
    required this.title,
    required this.htmlContent,
    this.moduleColor = '#7C4DFF',
    this.nextTitle,
  });

  @override
  State<StudentNotesViewerScreen> createState() => _StudentNotesViewerScreenState();
}

class _StudentNotesViewerScreenState extends State<StudentNotesViewerScreen> {
  static const List<int> _fontSizes = [15, 17, 19];
  int _fontSizeIndex = 0;

  late final String _viewId;
  late final html.IFrameElement _iframe;
  StreamSubscription<html.MessageEvent>? _messages;

  List<String> _steps = [];      // the note's headings, as the note reports them
  int _at = -1;                  // the step Altron (or the learner) is on
  int _reached = -1;             // the furthest step Altron has taught
  String? _liveView;             // the Altron strip, when open
  int? _countdown;               // seconds before the next lesson opens; -1: complete, no next
  Timer? _tick;

  String get _partKey => 'note_part_${widget.contentId}';

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppColors.primary;
    }
  }

  @override
  void initState() {
    super.initState();
    _viewId = 'student-notes-viewer-${identityHashCode(this)}';
    _iframe = html.IFrameElement()
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%'
      // No allow-top-navigation: pasted content (e.g. a link with
      // target="_top") must not be able to hijack the app's own router.
      ..setAttribute('sandbox', 'allow-scripts allow-popups allow-forms')
      ..srcdoc = _page();
    ui_web.platformViewRegistry.registerViewFactory(_viewId, (int viewId) => _iframe);
    _messages = html.window.onMessage.listen(_onMessage);
    if (widget.contentId != null) _autoStart();
  }

  @override
  void dispose() {
    _messages?.cancel();
    _tick?.cancel();
    super.dispose();
  }

  String _page() => tutorPage(_wrap(widget.htmlContent, _fontSizes[_fontSizeIndex]));

  void _cycleFontSize() {
    setState(() {
      _fontSizeIndex = (_fontSizeIndex + 1) % _fontSizes.length;
      _iframe.srcdoc = _page();
    });
  }

  String _wrap(String content, int baseFontSize) {
    if (content.toLowerCase().contains('<html')) return content;
    return '''
<!DOCTYPE html>
<html><head><meta charset="utf-8">
<style>
  body { font-family: Inter, -apple-system, sans-serif; padding: 20px;
         color: #1a1a2e; line-height: 1.7; font-size: ${baseFontSize}px; }
  h1, h2, h3 { font-family: Poppins, sans-serif; }
  img { max-width: 100%; }
  pre { background:#1e1e1e; color:#d4d4d4; padding:14px; border-radius:8px;
        overflow:auto; font-family: 'Fira Code', monospace; font-size: 0.85em; }
  table { border-collapse: collapse; width: 100%; }
  th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
</style>
</head><body>$content</body></html>''';
  }

  /// Tells the note something (which section to light up, what Altron said).
  void _toNote(Map<String, Object> m) {
    try {
      _iframe.contentWindow?.postMessage(jsonEncode(m), '*');
    } catch (_) {}
  }

  // ── messages: from the note (heads, section in view, a link) and from Altron's strip (typed) ──
  void _onMessage(html.MessageEvent e) {
    if (e.data is! String) return;
    Map? m;
    try {
      m = jsonDecode(e.data as String) as Map?;
    } catch (_) {
      return;
    }
    if (m == null || !mounted) return;
    final type = m['type'];
    if (type == null) {                                     // the note
      if (m['heads'] is List) setState(() => _steps = [for (final h in m!['heads'] as List) '$h']);
      if (m['section'] is num && _liveView == null) setState(() => _at = (m!['section'] as num).toInt());
      final open = m['open'];
      if (open is String && (open.startsWith('https://') || open.startsWith('http://'))) {
        launchUrl(Uri.parse(open), mode: LaunchMode.externalApplication);
      }
      return;
    }
    if (e.origin != html.window.location.origin) return;  // Altron's strip is our own page
    if (type == 'section' && m['part'] is num) {
      final i = (m['part'] as num).toInt() - 1;
      setState(() {
        _at = i;
        if (i > _reached) _reached = i;
      });
      _toNote({'show': i});
      SharedPreferences.getInstance().then((p) => p.setInt(_partKey, i + 1));   // opening it again carries on here
    } else if (type == 'said' && m['text'] is String) {
      _toNote({'said': m['text'] as String});
    } else if (type == 'state' && m['state'] == 'done') {   // the lesson is complete
      SharedPreferences.getInstance().then((p) => p.remove(_partKey));
      Future.delayed(const Duration(seconds: 3), () {
        if (!mounted) return;
        setState(() => _liveView = null);
        _lessonDone();
      });
    } else if (type == 'state' && m['state'] == 'out_of_minutes') {
      setState(() => _liveView = null);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        duration: const Duration(seconds: 10),
        content: Text('${m['text'] ?? "Today's time with Altron is used up."}'),
        action: SnackBarAction(label: 'Unlock', onPressed: () => GoRouter.of(context).push('/unlock')),
      ));
    }
  }

  // ── Altron ──
  /// Signed in: Altron starts by itself, like the desktop trainer. Signed out: the button asks for WhatsApp first.
  Future<void> _autoStart() async {
    final prefs = await SharedPreferences.getInstance();
    if ((prefs.getString('student_token') ?? '').isNotEmpty && mounted) _openAltron(prefs.getInt(_partKey) ?? 0);
  }

  Future<void> _explain() async {
    final prefs = await SharedPreferences.getInstance();
    if ((prefs.getString('student_token') ?? '').isEmpty) {
      if (!mounted) return;
      final ok = await showAuthSheet(context, reason: 'to learn with Altron', phoneOnly: true);
      if (!ok || !mounted) return;
    }
    _openAltron(prefs.getInt(_partKey) ?? 0);
  }

  void _openAltron(int fromPart) {
    final id = 'altron-live-${identityHashCode(this)}-${DateTime.now().millisecondsSinceEpoch}';
    final frame = html.IFrameElement()
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%'
      ..allow = 'microphone; autoplay'
      ..src = '/live/v2/index.html?note=${widget.contentId}&teach=1&strip=1&lang=en&compact=1&autostart=1'
          '${fromPart > 1 ? '&from=$fromPart' : ''}';
    ui_web.platformViewRegistry.registerViewFactory(id, (int _) => frame);
    setState(() {
      _liveView = id;
      _countdown = null;
    });
  }

  // ── the end of the lesson ──
  void _lessonDone() {
    if (widget.nextTitle == null) {
      setState(() => _countdown = -1);
      return;
    }
    setState(() => _countdown = 5);
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      if ((_countdown ?? 0) <= 1) {
        t.cancel();
        Navigator.of(context).pop('next');
        return;
      }
      setState(() => _countdown = _countdown! - 1);
    });
  }

  Widget _doneBar() => Material(
        color: const Color(0xFF0F5132),
        child: SizedBox(
          height: 60,
          child: Row(children: [
            const SizedBox(width: 16),
            const Icon(Icons.check_circle_rounded, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                  widget.nextTitle == null
                      ? 'Lesson complete. That was the last note of this module.'
                      : 'Lesson complete. Next: ${widget.nextTitle}, starting in ${_countdown ?? 5} s…',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
            if (widget.nextTitle != null) ...[
              TextButton(
                  onPressed: () {
                    _tick?.cancel();
                    setState(() => _countdown = null);
                  },
                  child: const Text('Stay here', style: TextStyle(color: Colors.white70))),
              const SizedBox(width: 6),
              FilledButton(
                  onPressed: () {
                    _tick?.cancel();
                    Navigator.of(context).pop('next');
                  },
                  style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF0F5132)),
                  child: const Text('Start now')),
            ],
            const SizedBox(width: 14),
          ]),
        ),
      );

  // ── the lesson's steps ──
  Widget _stepsPanel(Color color) => Container(
        width: 270,
        decoration: const BoxDecoration(color: Color(0xFFF8FAFC), border: Border(right: BorderSide(color: Color(0xFFE5E7EB)))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
            child: Text('LESSON STEPS',
                style: GoogleFonts.inter(fontSize: 11.5, letterSpacing: 1.2, fontWeight: FontWeight.w700, color: Colors.black54)),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 16),
              itemCount: _steps.length,
              itemBuilder: (_, i) {
                final now = i == _at, done = i < _reached || (i <= _reached && i != _at);
                return InkWell(
                  onTap: () {
                    setState(() => _at = i);
                    _toNote({'show': i});
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: now ? color.withValues(alpha: .10) : null,
                      border: Border(left: BorderSide(color: now ? color : Colors.transparent, width: 3)),
                    ),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(
                        width: 22,
                        height: 22,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                            color: done ? AppColors.success : (now ? color : Colors.white),
                            shape: BoxShape.circle,
                            border: Border.all(color: done ? AppColors.success : (now ? color : const Color(0xFFCBD5E1)))),
                        child: done
                            ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                            : Text('${i + 1}',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: now ? Colors.white : Colors.black54)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(_steps[i],
                            style: GoogleFonts.inter(
                                fontSize: 13.5,
                                height: 1.35,
                                fontWeight: now ? FontWeight.w700 : FontWeight.w500,
                                color: now ? AppColors.textPrimary : Colors.black87)),
                      ),
                    ]),
                  ),
                );
              },
            ),
          ),
        ]),
      );

  Widget _altronStrip() => Material(
        color: const Color(0xFF0D1726),
        child: SizedBox(
          height: 64,
          child: Row(children: [
            Expanded(child: HtmlElementView(key: ValueKey(_liveView), viewType: _liveView!)),
            IconButton(
              tooltip: 'Stop Altron',
              onPressed: () => setState(() => _liveView = null),
              icon: const Icon(Icons.close_rounded, color: Colors.white70),
            ),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final color = _parseColor(widget.moduleColor);
    final wide = MediaQuery.of(context).size.width >= 1000;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: color,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.title, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
        actions: [
          if (widget.contentId != null && _liveView == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: FilledButton.icon(
                onPressed: _explain,
                style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: color),
                icon: const Icon(Icons.record_voice_over_rounded, size: 18),
                label: Text(_reached >= 0 ? 'Continue with Altron' : 'Learn with Altron'),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.text_increase_rounded, color: Colors.white70),
            tooltip: 'Font Size',
            onPressed: _cycleFontSize,
          ),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (wide && _steps.length > 1) _stepsPanel(color),
            Expanded(child: HtmlElementView(viewType: _viewId)),
          ]),
        ),
        if (_liveView != null) _altronStrip(),
        if (_liveView == null && _countdown != null) _doneBar(),
      ]),
    );
  }
}
