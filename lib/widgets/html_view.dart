import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

/// Renders HTML via a sandboxed iframe (srcdoc) so admin-authored content
/// (including full external pages with <style> blocks) renders exactly as
/// a browser would. Sandbox intentionally omits allow-top-navigation so
/// a link inside the content can never hijack the app's own router.
class HtmlView extends StatefulWidget {
  final String html;
  final double? height;
  final int fontSize;

  const HtmlView({super.key, required this.html, this.height, this.fontSize = 15});

  @override
  State<HtmlView> createState() => _HtmlViewState();
}

class _HtmlViewState extends State<HtmlView> {
  late final String _viewId;
  late final html.IFrameElement _iframe;

  @override
  void initState() {
    super.initState();
    _viewId = 'html-view-${identityHashCode(this)}';
    _iframe = html.IFrameElement()
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%'
      ..setAttribute('sandbox', 'allow-scripts allow-popups allow-forms')
      ..srcdoc = _wrap(widget.html);
    ui_web.platformViewRegistry.registerViewFactory(_viewId, (int viewId) => _iframe);
  }

  @override
  void didUpdateWidget(covariant HtmlView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.html != widget.html || oldWidget.fontSize != widget.fontSize) {
      _iframe.srcdoc = _wrap(widget.html);
    }
  }

  String _wrap(String content) {
    if (content.toLowerCase().contains('<html')) return content;
    return '''
<!DOCTYPE html>
<html><head><meta charset="utf-8">
<style>
  body { font-family: Inter, -apple-system, sans-serif; padding: 16px;
         color: #1a1a2e; line-height: 1.7; font-size: ${widget.fontSize}px; margin: 0;
         white-space: pre-wrap; }
  p, div, ul, ol, table { white-space: normal; }
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
    final view = HtmlElementView(viewType: _viewId);
    return widget.height != null ? SizedBox(height: widget.height, child: view) : view;
  }
}
