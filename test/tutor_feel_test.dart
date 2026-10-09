import 'package:flutter_test/flutter_test.dart';
import 'package:altrobytelab/desktop/tutor_feel.dart';

void main() {
  test('text is written out word by word and ends complete', () {
    const text = 'Think of a resistor as a narrow pipe.';
    expect(revealed(text, 0), '');
    expect(revealed(text, 1), text);
    final half = revealed(text, 0.5);
    expect(text.startsWith(half), isTrue);
    expect(half.endsWith(' ') || text[half.length] == ' ' || half.length == text.length, isTrue); // never half a word
    expect(revealed('', 0.3), '');
    var last = 0;
    for (var p = 0.0; p <= 1.0; p += 0.05) {
      final n = revealed(text, p).length;
      expect(n >= last, isTrue); // it only ever grows
      last = n;
    }
  });

  test('writing out is quick for a short line and never drags for a long one', () {
    expect(revealTime(5).inMilliseconds, 250);
    expect(revealTime(60).inMilliseconds, 960);
    expect(revealTime(5000).inMilliseconds, 2600);
  });

  test('the three typing dots rise one after another', () {
    expect(dotLift(0.25, 0), closeTo(1, 0.01)); // the first is at its top
    expect(dotLift(0.25, 2), lessThan(0.2)); // the third has barely started
    expect(dotLift(0.9, 0), 0); // and rests between turns
    for (var t = 0.0; t < 1; t += 0.03) {
      for (var i = 0; i < 3; i++) {
        expect(dotLift(t, i), inInclusiveRange(0, 1));
      }
    }
  });
}
