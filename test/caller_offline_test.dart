// A caller with no signal loses nothing: logs wait on the phone, show at once, and reach the CRM once (never twice) when
// the connection is back.

import 'dart:convert';

import 'package:altrobytelab/caller/caller_api.dart';
import 'package:altrobytelab/caller/caller_controller.dart';
import 'package:altrobytelab/caller/caller_native.dart';
import 'package:altrobytelab/caller/models.dart';
import 'package:altrobytelab/caller/queue_order.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime.utc(2026, 10, 17, 10);

  final queue = {
    'me': {'login': 'asha@team.in', 'name': 'Asha', 'team_lead': false},
    'leads': [
      {'phone': '9800000001', 'name': 'Meera', 'stage': 'new', 'heat': {'temperature': 'hot', 'score': 70, 'pct': 70}},
      {'phone': '9800000002', 'name': 'Nikhil', 'stage': 'new', 'heat': {'temperature': 'cold', 'score': 0, 'pct': 0}},
    ],
  };

  late bool online;
  late List<Map<String, dynamic>> logged;
  late Set<String> seenIds;

  CallerController make() {
    final client = MockClient((req) async {
      if (!online) throw http.ClientException('no network');
      final path = req.url.path;
      if (path == '/crm/my-queue') return http.Response(jsonEncode(queue), 200);
      if (path.endsWith('/calls')) {
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        final dup = !seenIds.add('${body['client_id']}');
        if (!dup) logged.add(body);
        return http.Response(
            jsonEncode({
              'call_id': logged.length,
              'duplicate': dup,
              'lead': {
                'phone': body['phone'],
                'name': 'Meera',
                'stage': 'contacted',
                'heat': {'temperature': 'hot', 'score': 85, 'pct': 85},
                'next_followup_at': body['next_followup_at'],
                'last_called_at': body['started_at'],
              }
            }),
            200);
      }
      if (path == '/crm/labels') return http.Response(jsonEncode({'labels': ['student']}), 200);
      if (path == '/crm/quick-wa') return http.Response(jsonEncode({'messages': []}), 200);
      if (path.startsWith('/crm/caller-id/')) return http.Response(jsonEncode({'known': false}), 200);
      return http.Response('{"detail": "no"}', 404);
    });
    return CallerController(api: CallerApi(client: client, hosts: ['https://crm.test']), clock: () => now);
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'caller_token': 't',
      'caller_me': jsonEncode({'login': 'asha@team.in', 'name': 'Asha', 'team_lead': false}),
    });
    online = true;
    logged = [];
    seenIds = {};
  });

  test('a log made offline is kept, applied at once, and sent once when back online', () async {
    final c = make();
    await c.init();
    await c.refresh();
    expect(c.leads.map((l) => l.name), ['Meera', 'Nikhil']);

    online = false;
    final log = CallLog(
        clientId: 'offline-1',
        phone: '9800000001',
        startedAt: now,
        outcome: 'no_answer',
        nextFollowupAt: now.add(const Duration(hours: 2)));
    await c.save(log);
    expect(c.outbox.length, 1);
    expect(c.offline, isTrue);
    expect(bucketOf(c.leads.firstWhere((l) => l.phone == '9800000001'), now), 'later');
    expect(c.leads.first.name, 'Nikhil'); // Meera moved down to "later"

    // The app is closed and opened again, still offline: the log is still there.
    final again = make();
    await again.init();
    expect(again.outbox.length, 1);
    expect(again.leads.firstWhere((l) => l.phone == '9800000001').nextFollowupAt, isNotNull);

    online = true;
    await again.refresh();
    expect(again.outbox.length, 0);
    expect(logged, hasLength(1));
    expect(logged.single['client_id'], log.clientId);
    c.dispose();
    again.dispose();
  });

  test('a log sent twice (the answer was lost on the way back) is one call', () async {
    final c = make();
    await c.init();
    final log = c.newLog(phone: '9800000001', outcome: 'connected', durationS: 60);
    await c.api.logCall(log.toJson()); // reached the server, but the phone never heard back
    await c.save(log); // so it goes again from the outbox
    expect(logged, hasLength(1));
    expect(c.outbox.length, 0);
    c.dispose();
  });

  test('a call that just ended opens the log sheet for that lead', () async {
    final c = make();
    await c.init();
    await c.refresh();
    await c.handleCallEnded(CallEnded(phone: '+91 98000 00002', durationS: 12, type: 'out', startedAt: now));
    expect(c.pendingLog?.lead.name, 'Nikhil');
    expect(c.pendingLog?.call?.durationS, 12);
    c.takePendingLog();

    await c.handleCallEnded(CallEnded(phone: '9800000002', durationS: 0, type: 'missed', startedAt: now));
    expect(c.pendingLog, isNull); // a missed call is not a call to log

    await c.handleCallEnded(CallEnded(phone: '9811111111', durationS: 40, type: 'in', startedAt: now));
    expect(c.pendingLog?.isNew, isTrue); // someone new rang and they talked: offer to add them
    c.takePendingLog();

    await c.handleCallEnded(CallEnded(phone: '9822222222', durationS: 40, type: 'out', startedAt: now));
    expect(c.pendingLog, isNull); // a personal call dialled outside the app is left alone
    c.dispose();
  });

  test('a refused log is dropped with a plain message, not retried for ever', () async {
    final c = CallerController(
        api: CallerApi(
            client: MockClient((req) async => req.url.path.endsWith('/calls')
                ? http.Response(jsonEncode({'detail': 'This lead is with ravi@team.in. Ask your team lead to move it to you.'}), 403)
                : http.Response(jsonEncode(queue), 200)),
            hosts: ['https://crm.test']),
        clock: () => now);
    await c.init();
    await c.save(c.newLog(phone: '9800000001', outcome: 'busy'));
    expect(c.outbox.length, 0);
    expect(c.notice, contains('ravi@team.in'));
    c.dispose();
  });

  test('server errors read as plain sentences', () {
    expect(CallerApi.plainError(500, 'Traceback psycopg2...'), 'The CRM is having a problem. We will keep trying.');
    expect(CallerApi.plainError(400, "outcome must be one of ('connected', 'no_answer')"),
        'That did not go through. Please check and try again.');
    expect(CallerApi.plainError(401, null), 'Your login has ended. Please sign in again.');
    expect(CallerApi.plainError(409, 'They asked not to get WhatsApp messages.'), 'They asked not to get WhatsApp messages.');
  });
}
