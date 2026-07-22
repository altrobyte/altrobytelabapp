import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';

/// Full-screen HTML notes viewer for students.
/// Renders HTML content with styled typography, code blocks, lists, etc.
class StudentNotesViewerScreen extends StatelessWidget {
  final String title;
  final String htmlContent;
  final String moduleColor;

  const StudentNotesViewerScreen({
    super.key,
    required this.title,
    required this.htmlContent,
    this.moduleColor = '#7C4DFF',
  });

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _parseColor(moduleColor);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: color,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(title,
            style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.text_increase_rounded,
                color: Colors.white70),
            tooltip: 'Font Size',
            onPressed: () {
              // Font size toggle could be implemented
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Font size adjustment coming soon!'),
              ));
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: _RichHtmlContent(html: htmlContent, accentColor: color),
      ),
    );
  }
}

/// Renders HTML content as styled Flutter widgets.
/// Handles common tags: h1-h3, p, ul, ol, li, pre, code, table, strong, em, a, hr, img
class _RichHtmlContent extends StatelessWidget {
  final String html;
  final Color accentColor;

  const _RichHtmlContent({required this.html, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    final widgets = _parseHtml(html);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  List<Widget> _parseHtml(String html) {
    final widgets = <Widget>[];

    // Normalize
    var content = html
        .replaceAll(RegExp(r'\r\n'), '\n')
        .replaceAll(RegExp(r'\r'), '\n');

    // Split by block-level tags
    final blockPattern = RegExp(
      r'<(h[1-3]|p|pre|ul|ol|table|hr|div|blockquote)[^>]*>(.*?)</\1>|<hr\s*/?>',
      dotAll: true,
    );

    int lastEnd = 0;
    for (final match in blockPattern.allMatches(content)) {
      // Handle text between tags
      if (match.start > lastEnd) {
        final between = content.substring(lastEnd, match.start).trim();
        if (between.isNotEmpty) {
          final stripped = _stripTags(between);
          if (stripped.isNotEmpty) {
            widgets.add(_paragraph(stripped));
          }
        }
      }

      final fullMatch = match.group(0) ?? '';
      if (fullMatch.contains('<hr')) {
        widgets.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Divider(color: Colors.grey[300]),
        ));
      } else {
        final tag = match.group(1)?.toLowerCase() ?? '';
        final inner = match.group(2) ?? '';
        widgets.addAll(_renderBlock(tag, inner));
      }
      lastEnd = match.end;
    }

    // Handle remaining text after last block
    if (lastEnd < content.length) {
      final remaining = content.substring(lastEnd).trim();
      if (remaining.isNotEmpty) {
        final stripped = _stripTags(remaining);
        if (stripped.isNotEmpty) {
          widgets.add(_paragraph(stripped));
        }
      }
    }

    // Fallback if no blocks found
    if (widgets.isEmpty) {
      final stripped = _stripTags(content);
      if (stripped.isNotEmpty) {
        widgets.add(SelectableText(stripped,
            style: GoogleFonts.inter(
                fontSize: 15, height: 1.7, color: AppColors.textPrimary)));
      }
    }

    return widgets;
  }

  List<Widget> _renderBlock(String tag, String inner) {
    switch (tag) {
      case 'h1':
        return [
          Padding(
            padding: const EdgeInsets.only(bottom: 12, top: 16),
            child: Text(_stripTags(inner),
                style: GoogleFonts.poppins(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    height: 1.3)),
          ),
        ];
      case 'h2':
        return [
          Padding(
            padding: const EdgeInsets.only(bottom: 10, top: 14),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 22,
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(_stripTags(inner),
                      style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                          height: 1.3)),
                ),
              ],
            ),
          ),
        ];
      case 'h3':
        return [
          Padding(
            padding: const EdgeInsets.only(bottom: 8, top: 12),
            child: Text(_stripTags(inner),
                style: GoogleFonts.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    height: 1.3)),
          ),
        ];
      case 'p':
        return [_paragraph(_stripTags(inner))];
      case 'pre':
        final code = _stripTags(inner.replaceAll('<code>', '').replaceAll('</code>', ''));
        return [_codeBlock(code)];
      case 'ul':
        return _renderList(inner, ordered: false);
      case 'ol':
        return _renderList(inner, ordered: true);
      case 'table':
        return [_renderTable(inner)];
      case 'div':
        return [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: accentColor.withValues(alpha: 0.15)),
            ),
            child: Text(_stripTags(inner),
                style: GoogleFonts.inter(
                    fontSize: 14,
                    height: 1.6,
                    color: AppColors.textPrimary)),
          ),
        ];
      case 'blockquote':
        return [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              border: Border(
                  left: BorderSide(color: accentColor, width: 4)),
              color: accentColor.withValues(alpha: 0.04),
            ),
            child: Text(_stripTags(inner),
                style: GoogleFonts.inter(
                    fontSize: 14,
                    height: 1.6,
                    fontStyle: FontStyle.italic,
                    color: AppColors.textSecondary)),
          ),
        ];
      default:
        return [_paragraph(_stripTags(inner))];
    }
  }

  Widget _paragraph(String text) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _buildRichText(text),
    );
  }

  /// Parses inline tags like <strong>, <em>, <code> within text
  Widget _buildRichText(String text) {
    // Simple inline parsing
    final spans = <TextSpan>[];
    final inlinePattern = RegExp(
        r'<(strong|b|em|i|code)>(.*?)</\1>', dotAll: true);
    int lastEnd = 0;

    for (final match in inlinePattern.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(
            text: _stripTags(text.substring(lastEnd, match.start))));
      }
      final tag = match.group(1) ?? '';
      final content = _stripTags(match.group(2) ?? '');
      switch (tag) {
        case 'strong':
        case 'b':
          spans.add(TextSpan(
              text: content,
              style: const TextStyle(fontWeight: FontWeight.bold)));
          break;
        case 'em':
        case 'i':
          spans.add(TextSpan(
              text: content,
              style: const TextStyle(fontStyle: FontStyle.italic)));
          break;
        case 'code':
          spans.add(TextSpan(
            text: content,
            style: GoogleFonts.firaCode(
              backgroundColor: const Color(0xFFF5F5F5),
              fontSize: 13,
              color: accentColor,
            ),
          ));
          break;
      }
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(
          TextSpan(text: _stripTags(text.substring(lastEnd))));
    }

    if (spans.isEmpty) {
      return SelectableText(text,
          style: GoogleFonts.inter(
              fontSize: 15,
              height: 1.7,
              color: AppColors.textPrimary));
    }

    return SelectableText.rich(
      TextSpan(
        style: GoogleFonts.inter(
            fontSize: 15, height: 1.7, color: AppColors.textPrimary),
        children: spans,
      ),
    );
  }

  Widget _codeBlock(String code) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(16),
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SelectableText(
        code.trim(),
        style: GoogleFonts.firaCode(
          color: const Color(0xFFD4D4D4),
          fontSize: 13,
          height: 1.6,
        ),
      ),
    );
  }

  List<Widget> _renderList(String inner, {required bool ordered}) {
    final items = RegExp(r'<li[^>]*>(.*?)</li>', dotAll: true)
        .allMatches(inner)
        .map((m) => _stripTags(m.group(1) ?? ''))
        .where((s) => s.isNotEmpty)
        .toList();

    return [
      Padding(
        padding: const EdgeInsets.only(bottom: 10, left: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: items.asMap().entries.map((entry) {
            final idx = entry.key;
            final text = entry.value;
            final bullet = ordered ? '${idx + 1}.' : '•';
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: ordered ? 28 : 20,
                    child: Text(bullet,
                        style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: accentColor)),
                  ),
                  Expanded(child: _buildRichText(text)),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    ];
  }

  Widget _renderTable(String inner) {
    final rows = RegExp(r'<tr[^>]*>(.*?)</tr>', dotAll: true)
        .allMatches(inner)
        .toList();
    if (rows.isEmpty) return const SizedBox.shrink();

    final tableRows = <TableRow>[];
    for (int i = 0; i < rows.length; i++) {
      final rowHtml = rows[i].group(1) ?? '';
      final isHeader = rowHtml.contains('<th');
      final cellPattern = RegExp(r'<t[hd][^>]*>(.*?)</t[hd]>', dotAll: true);
      final cells = cellPattern
          .allMatches(rowHtml)
          .map((m) => _stripTags(m.group(1) ?? ''))
          .toList();

      tableRows.add(TableRow(
        decoration: BoxDecoration(
          color: isHeader
              ? accentColor.withValues(alpha: 0.1)
              : i % 2 == 0
                  ? Colors.grey.withValues(alpha: 0.03)
                  : Colors.white,
        ),
        children: cells
            .map((c) => Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(c,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight:
                            isHeader ? FontWeight.bold : FontWeight.normal,
                        color: AppColors.textPrimary,
                      )),
                ))
            .toList(),
      ));
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Table(
          border: TableBorder.symmetric(
            inside: BorderSide(
                color: Colors.grey.withValues(alpha: 0.15)),
          ),
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: tableRows,
        ),
      ),
    );
  }

  String _stripTags(String html) {
    return html
        .replaceAll(RegExp(r'<br\s*/?>'), '\n')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&quot;', '"')
        .trim();
  }
}
