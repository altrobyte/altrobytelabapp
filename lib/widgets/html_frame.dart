import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

/// Shows an HTML fragment (a picture the AI Lab assistant drew from a module's notes) inside a sandboxed frame.
///
/// The server has already cleaned the fragment. The frame adds a second wall: no scripts, no forms, no navigation
/// and a policy that allows no network, so a picture can only ever look like something.
class HtmlFrame extends StatefulWidget {
  final String body;
  final double height;
  const HtmlFrame({super.key, required this.body, this.height = 320});

  @override
  State<HtmlFrame> createState() => _HtmlFrameState();
}

class _HtmlFrameState extends State<HtmlFrame> {
  late final String _viewId;
  late final html.IFrameElement _frame;

  static String page(String body) => '''<!DOCTYPE html><html><head><meta charset="utf-8">
<meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; img-src data:;">
<style>
  body { font-family: Inter, Arial, sans-serif; margin: 0; padding: 14px; color: #212121; line-height: 1.5; background: #fff; }
  svg { max-width: 100%; height: auto; } table { border-collapse: collapse; } td, th { border: 1px solid #ccc; padding: 4px 8px; }
</style></head><body>$body</body></html>''';

  @override
  void initState() {
    super.initState();
    _viewId = 'html-frame-${identityHashCode(this)}';
    _frame = html.IFrameElement()
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%'
      ..setAttribute('sandbox', '')
      ..srcdoc = page(widget.body);
    ui_web.platformViewRegistry.registerViewFactory(_viewId, (int viewId) => _frame);
  }

  @override
  void didUpdateWidget(HtmlFrame old) {
    super.didUpdateWidget(old);
    if (old.body != widget.body) _frame.srcdoc = page(widget.body);
  }

  @override
  Widget build(BuildContext context) => SizedBox(height: widget.height, child: HtmlElementView(viewType: _viewId));
}
