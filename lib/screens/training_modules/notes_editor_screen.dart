import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';

/// Admin HTML Notes editor with two tabs:
/// 1. HTML Code — raw HTML editing
/// 2. Preview — renders the HTML visually
///
/// Returns {'title': ..., 'html': ...} on save.
class NotesEditorScreen extends StatefulWidget {
  final String initialTitle;
  final String initialHtml;

  const NotesEditorScreen({
    super.key,
    required this.initialTitle,
    required this.initialHtml,
  });

  @override
  State<NotesEditorScreen> createState() => _NotesEditorScreenState();
}

class _NotesEditorScreenState extends State<NotesEditorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtl;
  late TextEditingController _titleCtl;
  late TextEditingController _htmlCtl;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _tabCtl = TabController(length: 2, vsync: this);
    _titleCtl = TextEditingController(text: widget.initialTitle);
    _htmlCtl = TextEditingController(text: widget.initialHtml);

    _titleCtl.addListener(() => setState(() => _hasChanges = true));
    _htmlCtl.addListener(() => setState(() => _hasChanges = true));
  }

  @override
  void dispose() {
    _tabCtl.dispose();
    _titleCtl.dispose();
    _htmlCtl.dispose();
    super.dispose();
  }

  void _save() {
    if (_titleCtl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please enter a title'),
        backgroundColor: Colors.orange,
      ));
      return;
    }
    Navigator.pop(context, {
      'title': _titleCtl.text.trim(),
      'html': _htmlCtl.text,
    });
  }

  void _insertTemplate(String template) {
    final text = _htmlCtl.text;
    final sel = _htmlCtl.selection;
    final pos = sel.isValid ? sel.baseOffset : text.length;
    final newText = text.substring(0, pos) + template + text.substring(pos);
    _htmlCtl.text = newText;
    _htmlCtl.selection =
        TextSelection.collapsed(offset: pos + template.length);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () {
            if (_hasChanges) {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  title: Text('Discard Changes?',
                      style:
                          GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                  content: Text('You have unsaved changes.',
                      style: GoogleFonts.inter(fontSize: 14)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text('Keep Editing',
                          style: GoogleFonts.inter(
                              color: AppColors.textSecondary)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.pop(context);
                      },
                      child: Text('Discard',
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              );
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text('Notes Editor',
            style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 16)),
        actions: [
          TextButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save_rounded, color: Colors.white, size: 20),
            label: Text('Save',
                style: GoogleFonts.inter(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
        bottom: TabBar(
          controller: _tabCtl,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle:
              GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.code_rounded, size: 18), text: 'HTML Code'),
            Tab(
                icon: Icon(Icons.visibility_rounded, size: 18),
                text: 'Preview'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Title input
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _titleCtl,
              decoration: InputDecoration(
                labelText: 'Note Title',
                hintText: 'e.g., Introduction to Arrays',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                prefixIcon: const Icon(Icons.title_rounded),
              ),
              style: GoogleFonts.inter(
                  fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
          const Divider(height: 1),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabCtl,
              children: [
                // Tab 1: HTML Code editor
                Column(
                  children: [
                    // Quick-insert toolbar
                    Container(
                      color: const Color(0xFF2D2D2D),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _ToolbarBtn('H1', () => _insertTemplate(
                                '<h1>Heading</h1>\n')),
                            _ToolbarBtn('H2', () => _insertTemplate(
                                '<h2>Subheading</h2>\n')),
                            _ToolbarBtn('P', () => _insertTemplate(
                                '<p>Paragraph text here...</p>\n')),
                            _ToolbarBtn('UL', () => _insertTemplate(
                                '<ul>\n  <li>Item 1</li>\n  <li>Item 2</li>\n</ul>\n')),
                            _ToolbarBtn('OL', () => _insertTemplate(
                                '<ol>\n  <li>Step 1</li>\n  <li>Step 2</li>\n</ol>\n')),
                            _ToolbarBtn('CODE', () => _insertTemplate(
                                '<pre><code>// Code here\n</code></pre>\n')),
                            _ToolbarBtn('TABLE', () => _insertTemplate(
                                '<table border="1" cellpadding="8">\n  <tr><th>Header 1</th><th>Header 2</th></tr>\n  <tr><td>Cell 1</td><td>Cell 2</td></tr>\n</table>\n')),
                            _ToolbarBtn('IMG', () => _insertTemplate(
                                '<img src="URL" alt="description" width="100%">\n')),
                            _ToolbarBtn('B', () => _insertTemplate(
                                '<strong>bold text</strong>')),
                            _ToolbarBtn('I', () => _insertTemplate(
                                '<em>italic text</em>')),
                            _ToolbarBtn('A', () => _insertTemplate(
                                '<a href="URL">link text</a>')),
                            _ToolbarBtn('HR', () => _insertTemplate(
                                '<hr>\n')),
                            _ToolbarBtn('DIV', () => _insertTemplate(
                                '<div style="padding:16px; background:#f5f5f5; border-radius:8px;">\n  Content here\n</div>\n')),
                          ],
                        ),
                      ),
                    ),
                    // Code editor
                    Expanded(
                      child: Container(
                        color: const Color(0xFF1E1E1E),
                        child: TextField(
                          controller: _htmlCtl,
                          maxLines: null,
                          expands: true,
                          textAlignVertical: TextAlignVertical.top,
                          decoration: InputDecoration(
                            hintText:
                                '<!-- Paste or write your HTML here -->\n<h1>Title</h1>\n<p>Content...</p>',
                            hintStyle: GoogleFonts.firaCode(
                                color: Colors.white24, fontSize: 13),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.all(16),
                          ),
                          style: GoogleFonts.firaCode(
                            color: const Color(0xFFD4D4D4),
                            fontSize: 13,
                            height: 1.5,
                          ),
                          cursorColor: AppColors.accentLight,
                        ),
                      ),
                    ),
                  ],
                ),

                // Tab 2: Preview — real browser rendering via iframe, so
                // any pasted external HTML/CSS renders exactly as intended.
                Container(
                  color: Colors.white,
                  child: _htmlCtl.text.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.preview_rounded,
                                  size: 48, color: Colors.grey[300]),
                              const SizedBox(height: 12),
                              Text('Write some HTML to see preview',
                                  style: GoogleFonts.inter(
                                      color: AppColors.textSecondary)),
                            ],
                          ),
                        )
                      : _HtmlPreview(html: _htmlCtl.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolbarBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _ToolbarBtn(this.label, this.onTap);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Text(label,
                style: GoogleFonts.firaCode(
                    color: AppColors.accentLight,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ),
        ),
      ),
    );
  }
}

/// Renders HTML exactly as a browser would, via a sandboxed iframe
/// (srcdoc) — handles full external HTML documents (doctype, head,
/// style blocks, scripts, nested/malformed markup) correctly, unlike a
/// hand-rolled tag parser which only understands a few flat tags.
class _HtmlPreview extends StatefulWidget {
  final String html;
  const _HtmlPreview({required this.html});

  @override
  State<_HtmlPreview> createState() => _HtmlPreviewState();
}

class _HtmlPreviewState extends State<_HtmlPreview> {
  late final String _viewId;
  late final html.IFrameElement _iframe;

  @override
  void initState() {
    super.initState();
    _viewId = 'notes-html-preview-${identityHashCode(this)}';
    _iframe = html.IFrameElement()
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%'
      // No allow-top-navigation: pasted content must not hijack the app's router.
      ..setAttribute('sandbox', 'allow-scripts allow-popups allow-forms')
      ..srcdoc = _wrap(widget.html);
    ui_web.platformViewRegistry
        .registerViewFactory(_viewId, (int viewId) => _iframe);
  }

  @override
  void didUpdateWidget(covariant _HtmlPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.html != widget.html) {
      _iframe.srcdoc = _wrap(widget.html);
    }
  }

  String _wrap(String content) {
    // If it's already a full document (external paste), render it as-is.
    if (content.toLowerCase().contains('<html')) return content;
    return '''
<!DOCTYPE html>
<html><head><meta charset="utf-8">
<style>
  body { font-family: Inter, -apple-system, sans-serif; padding: 20px;
         color: #1a1a2e; line-height: 1.6; }
  img { max-width: 100%; }
  pre { background:#1e1e1e; color:#d4d4d4; padding:14px; border-radius:8px;
        overflow:auto; font-family: 'Fira Code', monospace; font-size: 13px; }
  table { border-collapse: collapse; width: 100%; }
  th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
</style>
</head><body>$content</body></html>''';
  }

  @override
  Widget build(BuildContext context) => HtmlElementView(viewType: _viewId);
}
