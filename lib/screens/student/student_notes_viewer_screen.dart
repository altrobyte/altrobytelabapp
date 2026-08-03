import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';

/// Full-screen HTML notes viewer for students. Renders via a sandboxed
/// iframe (srcdoc) so any HTML/CSS pasted by an admin (including full
/// external pages with <style> blocks) renders exactly as a browser
/// would — a hand-rolled tag parser only understands a handful of flat
/// tags and breaks on anything else (e.g. printing CSS as visible text).
class StudentNotesViewerScreen extends StatefulWidget {
  final String title;
  final String htmlContent;
  final String moduleColor;

  const StudentNotesViewerScreen({
    super.key,
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
          IconButton(
            icon: const Icon(Icons.text_increase_rounded,
                color: Colors.white70),
            tooltip: 'Font Size',
            onPressed: _cycleFontSize,
          ),
        ],
      ),
      body: HtmlElementView(viewType: _viewId),
    );
  }
}
