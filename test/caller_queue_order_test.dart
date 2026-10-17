// The Today queue's order, the same rule as the server's (crm_calls.bucket), so a call logged offline moves its lead
// at once.

import 'package:altrobytelab/caller/models.dart';
import 'package:altrobytelab/caller/queue_order.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 10, 17, 10);
  Lead lead(String name, {String temp = 'cold', int score = 0, String stage = 'new', DateTime? follow, DateTime? called}) =>
      Lead(
          phone: '98000000${name.length.toString().padLeft(2, '0')}${name.codeUnitAt(0)}',
          name: name,
          stage: stage,
          heat: Heat(temperature: temp, score: score),
          nextFollowupAt: follow,
          lastCalledAt: called);

  test('due follow-ups first, then hot, warm, new and uncalled, the rest, later follow-ups, converted', () {
    final leads = [
      lead('Rest', stage: 'contacted', called: now.subtract(const Duration(days: 3)), score: 5),
      lead('Due', follow: now.subtract(const Duration(minutes: 30))),
      lead('Hot', temp: 'hot', score: 70),
      lead('Hotter', temp: 'hot', score: 90),
      lead('Warm', temp: 'warm', score: 25),
      lead('New'),
      lead('Later', follow: now.add(const Duration(days: 1)), temp: 'hot', score: 80),
      lead('Due earlier', follow: now.subtract(const Duration(hours: 5))),
      lead('Paid', temp: 'customer'),
      lead('Stopped', temp: 'out'),
    ];
    final order = sortQueue(leads, now);
    expect(order.map((l) => l.name), [
      'Due earlier', 'Due', 'Hotter', 'Hot', 'Warm', 'New', 'Rest', 'Later', 'Paid', //
    ]);
    expect(order.map((l) => bucketOf(l, now)), ['due', 'due', 'hot', 'hot', 'warm', 'new', 'rest', 'later', 'converted']);
  });

  test('a follow-up becomes due the minute its time comes', () {
    final l = lead('Soon', follow: now.add(const Duration(minutes: 1)));
    expect(bucketOf(l, now), 'later');
    expect(bucketOf(l, now.add(const Duration(minutes: 1))), 'due');
  });

  test('a call logged offline moves the lead at once', () {
    final fresh = lead('Fresh');
    final log = CallLog(
        clientId: 'x', phone: fresh.phone, startedAt: now, outcome: 'no_answer', nextFollowupAt: now.add(const Duration(hours: 2)));
    final after = log.applyTo(fresh, me: 'asha@team.in');
    expect(bucketOf(fresh, now), 'new');
    expect(bucketOf(after, now), 'later');
    expect(after.lastCalledBy, 'asha@team.in');

    final talked = CallLog(clientId: 'y', phone: fresh.phone, startedAt: now, outcome: 'connected').applyTo(fresh);
    expect(talked.stage, 'contacted');
    expect(bucketOf(talked, now), 'rest');

    final wrong = CallLog(clientId: 'z', phone: fresh.phone, startedAt: now, outcome: 'wrong_number').applyTo(fresh);
    expect(sortQueue([wrong], now), isEmpty);
  });

  test('duplicates are matched on the last ten digits, as in the CRM', () {
    for (final typed in ['9876543210', '+91 98765 43210', '919876543210', '09876543210']) {
      expect(last10(typed), '9876543210');
    }
  });
}
