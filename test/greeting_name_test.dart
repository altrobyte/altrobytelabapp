// The name shown after "Hi," on the home header.
//
// Students append a tagline to their display name — "Pawan Meena :
// Electroholic Engineer" — which read badly in the greeting. The tagline is
// theirs and stays on the profile; only the greeting is shortened.

import 'package:flutter_test/flutter_test.dart';
import 'package:altrobytelab/utils/formatters.dart';

void main() {
  group('greetingName', () {
    test('drops a tagline after a colon', () {
      expect(Fmt.greetingName('Pawan Meena : Electroholic Engineer'), 'Pawan Meena');
    });

    test('handles the other separators people use', () {
      expect(Fmt.greetingName('Arjun | Founder'), 'Arjun');
      expect(Fmt.greetingName('Meera Nair, PhD'), 'Meera Nair');
      expect(Fmt.greetingName('Ravi (Batch 3)'), 'Ravi');
      expect(Fmt.greetingName('Sana — Embedded Dev'), 'Sana');
    });

    test('leaves an ordinary name alone', () {
      expect(Fmt.greetingName('Rahul Kumar'), 'Rahul Kumar');
    });

    test('never splits on characters that belong inside a name', () {
      // An earlier version of the same logic elsewhere cut "Anne-Marie" to
      // "Anne", which is worse than the tagline it was trying to remove.
      expect(Fmt.greetingName('Anne-Marie D\'Souza'), 'Anne-Marie D\'Souza');
      expect(Fmt.greetingName('Jean-Pierre'), 'Jean-Pierre');
    });

    test('falls back rather than greeting nobody', () {
      expect(Fmt.greetingName(''), 'Student');
      expect(Fmt.greetingName(null), 'Student');
      expect(Fmt.greetingName('   '), 'Student');
    });

    test('keeps the whole name when the part before a separator is too short', () {
      // "A : B" is more likely a typo than a tagline; cutting it to "A" would
      // greet someone by a single letter.
      expect(Fmt.greetingName('A : Engineer'), 'A : Engineer');
    });
  });
}
