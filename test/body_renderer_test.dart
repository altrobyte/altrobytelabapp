// The spec-line parser behind the lab setup product page.
//
// Admins type plain text; the page infers which lines are components so it can
// right-align quantities. Getting the split wrong is invisible until someone
// reads the page and sees a component called "LEDs" costing "Red, Green,
// Yellow — 1 each", so the cases are pinned here.

import 'package:flutter_test/flutter_test.dart';

/// Mirror _specLine and _columnLine in showcase_screens.dart.
final specLine = RegExp(r'^\s*[•\-\*]\s*(.+)\s+[—–-]\s+(.+)$');
final columnLine = RegExp(r'^\s*(\S.*?\S)\s{2,}(\d[\w. ]{0,11})\s*$');

({String name, String qty})? parse(String line) {
  final m = specLine.firstMatch(line) ?? columnLine.firstMatch(line);
  if (m == null) return null;
  return (name: m.group(1)!.trim(), qty: m.group(2)!.trim());
}

void main() {
  group('component lines', () {
    test('plain name and quantity', () {
      final r = parse('• STM32 Board — 1')!;
      expect(r.name, 'STM32 Board');
      expect(r.qty, '1');
    });

    test('splits at the LAST separator, not the first', () {
      // The regression: a non-greedy name turned this into a component called
      // "LEDs" with a quantity of "Red, Green, Yellow — 1 each".
      final r = parse('• LEDs — Red, Green, Yellow — 1 each')!;
      expect(r.name, 'LEDs — Red, Green, Yellow');
      expect(r.qty, '1 each');
    });

    test('hyphens inside a name are not separators', () {
      final r = parse('• Jumper Wires M-M / M-F / F-F — 5 each')!;
      expect(r.name, 'Jumper Wires M-M / M-F / F-F');
      expect(r.qty, '5 each');
    });

    test('units and symbols survive', () {
      final r = parse('• Resistors 220Ω / 1kΩ / 10kΩ — 3 each')!;
      expect(r.name, 'Resistors 220Ω / 1kΩ / 10kΩ');
      expect(r.qty, '3 each');

      final o = parse('• OLED Display 0.96" I2C — 1')!;
      expect(o.name, 'OLED Display 0.96" I2C');
      expect(o.qty, '1');
    });

    test('a set is a quantity like any other', () {
      final r = parse('• Soldering Kit (complete) — 1 set')!;
      expect(r.qty, '1 set');
    });

    test('accepts the dash and asterisk bullets people actually type', () {
      expect(parse('- Breadboard — 1')?.name, 'Breadboard');
      expect(parse('* Breadboard — 1')?.name, 'Breadboard');
    });
  });

  group('space-aligned lists (pasted from a spec sheet)', () {
    // The format that was already in the database. The first renderer only
    // understood bullets, so a list like this changed not at all.
    test('name, run of spaces, quantity', () {
      final r = parse('  STM32 Board                      1')!;
      expect(r.name, 'STM32 Board');
      expect(r.qty, '1');
    });

    test('multi-word quantities', () {
      expect(parse('  Jumper Wires M-M                 05 pcs')?.qty, '05 pcs');
      expect(parse('  Soldering Kit Complete           1 set')?.qty, '1 set');
    });

    test('names holding symbols and slashes', () {
      final r = parse('  Resistors 220Ω / 1kΩ              3 each')!;
      expect(r.name, 'Resistors 220Ω / 1kΩ');
      expect(r.qty, '3 each');
    });

    test('a single space is not a column', () {
      // Otherwise "OLED Display 0.96 inch" splits into a name and a quantity.
      expect(parse('OLED Display 0.96 1'), isNull);
    });

    test('prose with a double space is not a row', () {
      expect(parse('This is the box.  Every session uses it.'), isNull);
    });

    test('a trailing word that is not a quantity is not a row', () {
      expect(parse('Boards and programming        tools'), isNull);
    });
  });

  group('lines that are not components', () {
    test('a heading is not parsed as a component', () {
      expect(parse('Sensors & display'), isNull);
      expect(parse("WHAT'S INSIDE"), isNull);
    });

    test('a bullet with no quantity stays a bullet', () {
      expect(parse('• Everything you need to build'), isNull);
    });

    test('prose containing a dash is not a component', () {
      // Body copy is full of em-dashes; only bulleted lines may become rows.
      expect(
          parse('This is the box the programme is built around — every session uses it'),
          isNull);
    });

    test('blank and whitespace lines', () {
      expect(parse(''), isNull);
      expect(parse('   '), isNull);
    });
  });
}
