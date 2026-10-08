import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The trainer writes light markdown (**bold**, `code`, "- " bullets). This shows it as a learner
/// expects instead of as raw asterisks and backticks. No packages: a few lines are all it needs.
class ChatText extends StatelessWidget {
  const ChatText(this.text, {super.key, required this.color, this.fontSize = 13.5});
  final String text;
  final Color color;
  final double fontSize;

  static final _inline = RegExp(r'\*\*(.+?)\*\*|`([^`]+)`');

  /// Inline spans for one line of text.
  static List<InlineSpan> spans(String line, TextStyle base, {Color codeBg = const Color(0x14000000)}) {
    final out = <InlineSpan>[];
    var at = 0;
    for (final m in _inline.allMatches(line)) {
      if (m.start > at) out.add(TextSpan(text: line.substring(at, m.start)));
      if (m.group(1) != null) {
        out.add(TextSpan(text: m.group(1), style: const TextStyle(fontWeight: FontWeight.w700)));
      } else {
        out.add(TextSpan(
            text: m.group(2),
            style: TextStyle(fontFamily: 'Consolas', fontFamilyFallback: const ['Courier New', 'monospace'], fontSize: (base.fontSize ?? 13.5) - 1, backgroundColor: codeBg)));
      }
      at = m.end;
    }
    if (at < line.length) out.add(TextSpan(text: line.substring(at)));
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final base = GoogleFonts.inter(fontSize: fontSize, height: 1.45, color: color);
    final rows = <Widget>[];
    for (final raw in text.trim().split('\n')) {
      var line = raw.trimRight();
      if (line.isEmpty) {
        if (rows.isNotEmpty) rows.add(const SizedBox(height: 6));
        continue;
      }
      line = line.replaceFirst(RegExp(r'^#{1,6}\s+'), '');
      final bullet = RegExp(r'^\s*(?:[-*•]|\d+[.)])\s+(.*)$').firstMatch(line);
      if (bullet != null) {
        final number = RegExp(r'^\s*(\d+[.)])').firstMatch(line)?.group(1);
        rows.add(Padding(
          padding: const EdgeInsets.only(left: 4, top: 2),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 20, child: Text(number ?? '•', style: base)),
            Expanded(child: SelectableText.rich(TextSpan(style: base, children: spans(bullet.group(1)!, base)))),
          ]),
        ));
      } else {
        rows.add(SelectableText.rich(TextSpan(style: base, children: spans(line, base))));
      }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: rows);
  }
}
