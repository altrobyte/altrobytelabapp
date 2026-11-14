import 'package:altrobytelab/screens/admin/tasks_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('task times read like a person says them', () {
    final now = DateTime(2026, 11, 14, 20, 0);
    expect(taskWhen(DateTime(2026, 11, 14, 11, 0), now), 'Today 11:00 AM');
    expect(taskWhen(DateTime(2026, 11, 15, 21, 5), now), 'Tomorrow 9:05 PM');
    expect(taskWhen(DateTime(2026, 11, 13, 0, 30), now), 'Yesterday 12:30 AM');
    expect(taskWhen(DateTime(2026, 11, 22, 10, 0), now), 'Sun 22 Nov, 10:00 AM');
  });
  test('a picked time goes to the server as India time without a zone', () {
    expect(taskIso(DateTime(2026, 1, 5, 9, 7)), '2026-01-05T09:07');
  });
}
