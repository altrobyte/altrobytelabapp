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
        backgroundColor: const Color(0xFF7C4DFF),
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
                          cursorColor: const Color(0xFF7C4DFF),
                        ),
                      ),
                    ),
                  ],
                ),

                // Tab 2: Preview
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
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: _HtmlPreview(html: _htmlCtl.text),
                        ),
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
                    color: const Color(0xFF7C4DFF),
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ),
        ),
      ),
    );
  }
}

/// Simple HTML-to-Widget preview. Uses basic parsing to render common
/// HTML tags without needing a WebView or heavy package dependency.
class _HtmlPreview extends StatelessWidget {
  final String html;
  const _HtmlPreview({required this.html});

  @override
  Widget build(BuildContext context) {
    // Split HTML into simple renderable chunks by line-based parsing
    final widgets = <Widget>[];
    // Strip tags and render as styled text blocks
    final clean = html
        .replaceAll(RegExp(r'<br\s*/?>'), '\n')
        .replaceAll('</p>', '\n\n')
        .replaceAll('</div>', '\n')
        .replaceAll('</li>', '\n');

    // Parse heading/paragraph blocks
    final tagPattern = RegExp(r'<(\w+)[^>]*>(.*?)</\1>', dotAll: true);
    final matches = tagPattern.allMatches(clean);

    if (matches.isEmpty) {
      // Fallback: strip all tags and show as text
      final stripped = clean.replaceAll(RegExp(r'<[^>]*>'), '').trim();
      return SelectableText(stripped,
          style: GoogleFonts.inter(fontSize: 14, height: 1.6));
    }

    for (final match in matches) {
      final tag = match.group(1)?.toLowerCase() ?? '';
      final content =
          (match.group(2) ?? '').replaceAll(RegExp(r'<[^>]*>'), '').trim();
      if (content.isEmpty) continue;

      switch (tag) {
        case 'h1':
          widgets.add(Padding(
            padding: const EdgeInsets.only(bottom: 12, top: 8),
            child: Text(content,
                style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
          ));
          break;
        case 'h2':
          widgets.add(Padding(
            padding: const EdgeInsets.only(bottom: 10, top: 8),
            child: Text(content,
                style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
          ));
          break;
        case 'h3':
          widgets.add(Padding(
            padding: const EdgeInsets.only(bottom: 8, top: 6),
            child: Text(content,
                style: GoogleFonts.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
          ));
          break;
        case 'pre':
        case 'code':
          widgets.add(Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(10),
            ),
            width: double.infinity,
            child: SelectableText(content,
                style: GoogleFonts.firaCode(
                    color: const Color(0xFFD4D4D4),
                    fontSize: 13,
                    height: 1.5)),
          ));
          break;
        case 'strong':
        case 'b':
          widgets.add(Text(content,
              style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)));
          break;
        case 'li':
          widgets.add(Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('•  ',
                    style: GoogleFonts.inter(
                        fontSize: 14, color: AppColors.primary)),
                Expanded(
                  child: Text(content,
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          height: 1.5,
                          color: AppColors.textPrimary)),
                ),
              ],
            ),
          ));
          break;
        default:
          widgets.add(Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SelectableText(content,
                style: GoogleFonts.inter(
                    fontSize: 14,
                    height: 1.6,
                    color: AppColors.textPrimary)),
          ));
      }
    }

    return Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: widgets);
  }
}
