// Two small things that make the tutor feel present instead of slow.
//
// TypingDots: while an answer is on its way, three dots move the way they do when a person is typing. A spinner says "a machine
// is working"; dots say "someone is answering you".
//
// RevealText: a new line from the tutor is written out over a moment instead of appearing as a block, at about the speed the
// voice speaks it. The eye has something to follow from the first instant, and long text does not land all at once.

import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'chat_text.dart';

class TypingDots extends StatefulWidget {
  const TypingDots({super.key});

  @override
  State<TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<TypingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.black.withValues(alpha: 0.08))),
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) => Row(mainAxisSize: MainAxisSize.min, children: [
            for (var i = 0; i < 3; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2.5),
                child: Transform.translate(
                  offset: Offset(0, -4 * dotLift(_c.value, i)),
                  child: Container(width: 7, height: 7, decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.35 + 0.55 * dotLift(_c.value, i)), shape: BoxShape.circle)),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

/// How high dot [i] of three is at time [t] (0..1 through one cycle): each rises and falls in turn.
double dotLift(double t, int i) {
  final phase = (t - i * 0.18) % 1.0;
  if (phase < 0 || phase > 0.5) return 0;
  final x = phase / 0.5; // 0..1 over the rise and fall
  return 1 - (2 * x - 1) * (2 * x - 1);
}

/// How long writing out [length] characters takes: quick for a short line, never tediously long for a long one.
Duration revealTime(int length) => Duration(milliseconds: (length * 16).clamp(250, 2600));

/// How much of [text] is shown at progress [p] (0..1). It stops at the end of a word, so half a word never hangs there.
String revealed(String text, double p) {
  if (p >= 1 || text.isEmpty) return text;
  var n = (text.length * p).floor().clamp(0, text.length);
  while (n < text.length && n > 0 && text[n] != ' ' && text[n - 1] != ' ') {
    n++;
  }
  return text.substring(0, n);
}

class RevealText extends StatefulWidget {
  final String text;
  final Color color;

  /// Called once, when the whole text is on the screen (so it is not written out again when the list is rebuilt).
  final VoidCallback onDone;

  /// Called as more text appears, so the conversation can keep the newest words in view.
  final VoidCallback? onGrow;
  const RevealText(this.text, {super.key, required this.color, required this.onDone, this.onGrow});

  @override
  State<RevealText> createState() => _RevealTextState();
}

class _RevealTextState extends State<RevealText> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: revealTime(widget.text.length));
  int _shownLength = 0;

  @override
  void initState() {
    super.initState();
    _c.addListener(() {
      final now = revealed(widget.text, _c.value).length;
      if (now != _shownLength) {
        _shownLength = now;
        setState(() {});
        if (now % 40 < 8) widget.onGrow?.call();
      }
    });
    _c.forward().whenComplete(widget.onDone);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ChatText(revealed(widget.text, _c.value), color: widget.color);
}
