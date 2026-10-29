import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants/app_colors.dart';
import '../../widgets/auth_sheet.dart';

/// Full-screen HTML notes viewer for students. Renders via a sandboxed
/// iframe (srcdoc) so any HTML/CSS pasted by an admin (including full
/// external pages with <style> blocks) renders exactly as a browser
/// would — a hand-rolled tag parser only understands a handful of flat
/// tags and breaks on anything else (e.g. printing CSS as visible text).
class StudentNotesViewerScreen extends StatefulWidget {
  final String title;
  final String htmlContent;
  final String moduleColor;

  /// The note's id: with it, Altron (the AI trainer) can explain this note by voice on the website.
  final int? contentId;

  const StudentNotesViewerScreen({
    super.key,
    this.contentId,
    required this.title,
    required this.htmlContent,
    this.moduleColor = '#7C4DFF',
  });

  @override
  State<StudentNotesViewerScreen> createState() =>
      _StudentNotesViewerScreenState();
}

class _StudentNotesViewerScreenState extends State<StudentNotesViewerScreen> {
  static const List<int> _fontSizes = [15, 17, 19];
  int _fontSizeIndex = 0;

  late final String _viewId;
  late final html.IFrameElement _iframe;

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
      ..srcdoc = _wrap(widget.htmlContent, _fontSizes[_fontSizeIndex]);
    ui_web.platformViewRegistry
        .registerViewFactory(_viewId, (int viewId) => _iframe);
  }

  // ── Altron explains the note: the Live page in a slim strip under it (29 Oct 2026, free start on the web) ──
  String? _liveView;
  StreamSubscription<html.MessageEvent>? _messages;

  Future<void> _explain() async {
    final prefs = await SharedPreferences.getInstance();
    if ((prefs.getString('student_token') ?? '').isEmpty) {
      if (!mounted) return;
      final ok = await showAuthSheet(context, reason: 'to learn with Altron', phoneOnly: true);
      if (!ok || !mounted) return;
    }
    final id = 'altron-live-${identityHashCode(this)}-${DateTime.now().millisecondsSinceEpoch}';
    final frame = html.IFrameElement()
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%'
      ..allow = 'microphone; autoplay'
      ..src = '/live/v2/index.html?note=${widget.contentId}&teach=1&strip=1&lang=en&compact=1&autostart=1';
    ui_web.platformViewRegistry.registerViewFactory(id, (int _) => frame);
    _messages ??= html.window.onMessage.listen((e) {
      if (e.origin != html.window.location.origin || e.data is! String) return;
      Map? m;
      try {
        m = jsonDecode(e.data as String) as Map?;
      } catch (_) {
        return;
      }
      if (m?['type'] == 'state' && m?['state'] == 'done') {     // the lesson is complete: the strip goes away
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _liveView = null);
        });
      }
      // No time left today, or the module needs a plan: the strip goes and the plans are offered.
      if (m?['type'] == 'state' && m?['state'] == 'out_of_minutes' && mounted) {
        setState(() => _liveView = null);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          duration: const Duration(seconds: 10),
          content: Text('${m?['text'] ?? "Today's free time with Altron is used up."}'),
          action: SnackBarAction(label: 'Unlock', onPressed: () => GoRouter.of(context).push('/unlock')),
        ));
      }
    });
    setState(() => _liveView = id);
  }

  @override
  void dispose() {
    _messages?.cancel();
    super.dispose();
  }

  void _cycleFontSize() {
    setState(() {
      _fontSizeIndex = (_fontSizeIndex + 1) % _fontSizes.length;
      _iframe.srcdoc = _wrap(widget.htmlContent, _fontSizes[_fontSizeIndex]);
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

  @override
  Widget build(BuildContext context) {
    final color = _parseColor(widget.moduleColor);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: color,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.title,
            style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 16)),
        actions: [
          if (widget.contentId != null && _liveView == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: FilledButton.icon(
                onPressed: _explain,
                style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: color),
                icon: const Icon(Icons.record_voice_over_rounded, size: 18),
                label: const Text('Explain with Altron'),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.text_increase_rounded,
                color: Colors.white70),
            tooltip: 'Font Size',
            onPressed: _cycleFontSize,
          ),
        ],
      ),
      body: Column(children: [
        Expanded(child: HtmlElementView(viewType: _viewId)),
        if (_liveView != null)
          Material(
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
          ),
      ]),
    );
  }
}
