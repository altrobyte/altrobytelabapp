// The standard enrolment form must always be something the server accepts: known types, real ids, choices where needed.
import 'package:flutter_test/flutter_test.dart';
import 'package:altrobytelab/screens/enrolment/enrolment_template.dart';

void main() {
  test('every question has a unique id, a known type and the choices its type needs', () {
    final ids = <String>{};
    for (final q in enrolmentTemplate) {
      expect(ids.add('${q['id']}'), true, reason: 'duplicate id ${q['id']}');
      expect(RegExp(r'^[a-z0-9_]{1,40}$').hasMatch('${q['id']}'), true);
      expect(['text', 'long', 'choice', 'multi'], contains(q['type']));
      final options = (q['options'] as List).cast<String>();
      if (q['type'] == 'choice' || q['type'] == 'multi') {
        expect(options.length, greaterThanOrEqualTo(2), reason: '${q['id']} needs choices');
        expect(options.toSet().length, options.length, reason: 'repeated choice in ${q['id']}');
        expect(options.any((o) => o.contains(',')), false, reason: 'a comma would split the choice in the editor');
      } else {
        expect(options, isEmpty);
      }
      expect('${q['label']}'.trim(), isNotEmpty);
    }
    expect(enrolmentTemplate.length, lessThanOrEqualTo(30));
  });

  test('it covers what the team asked for: education, address, interests and duration', () {
    final ids = enrolmentTemplate.map((q) => q['id']).toSet();
    expect(ids, containsAll(['qualification', 'college', 'branch', 'address', 'city', 'state', 'pin', 'interest', 'duration']));
    final interest = enrolmentTemplate.firstWhere((q) => q['id'] == 'interest');
    expect(interest['type'], 'multi');
    expect(interest['options'], containsAll(['IoT', 'Embedded Systems', 'Edge AI', 'Circuit Designing']));
    final duration = enrolmentTemplate.firstWhere((q) => q['id'] == 'duration');
    expect(duration['options'], ['1 month', '2 months', '3 months', '4 months', '6 months']);
  });

  test('sections come in runs, so headings are never repeated', () {
    final seen = <String>[];
    for (final q in enrolmentTemplate) {
      final s = '${q['section']}';
      if (seen.isEmpty || seen.last != s) {
        expect(seen.contains(s), false, reason: 'section "$s" appears twice, apart');
        seen.add(s);
      }
    }
  });
}
