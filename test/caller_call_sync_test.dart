// The phone's calls reach the CRM by themselves: nobody marks a lead or types a name.

import 'dart:convert';

import 'package:altrobytelab/caller/caller_api.dart';
import 'package:altrobytelab/caller/caller_controller.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime.utc(2026, 10, 17, 10);
  const channel = MethodChannel('altrobyte.caller/native');

  test('new calls are sent once, personal numbers never, and the first run reaches back a week', () async {
    final phoneLog = [
      {'phone': '+91 98111 00001', 'name': 'Tanya', 'type': 'out', 'duration_s': 240, 'started_at_ms': now.subtract(const Duration(hours: 1)).millisecondsSinceEpoch},
      {'phone': '9811100002', 'name': 'Mom', 'type': 'in', 'duration_s': 60, 'started_at_ms': now.subtract(const Duration(hours: 2)).millisecondsSinceEpoch},
      {'phone': '9811100003', 'name': '', 'type': 'missed', 'duration_s': 0, 'started_at_ms': now.subtract(const Duration(days: 2)).millisecondsSinceEpoch},
      {'phone': '9811100004', 'name': 'Old', 'type': 'in', 'duration_s': 30, 'started_at_ms': now.subtract(const Duration(days: 9)).millisecondsSinceEpoch},
      {'phone': '1234', 'name': 'Bank', 'type': 'in', 'duration_s': 10, 'started_at_ms': now.subtract(const Duration(hours: 3)).millisecondsSinceEpoch},
      {'phone': '9811100006', 'name': 'Friend', 'type': 'out', 'duration_s': 600, 'started_at_ms': now.subtract(const Duration(hours: 4)).millisecondsSinceEpoch},
    ];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'recentCalls') return phoneLog;
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));
    SharedPreferences.setMockInitialValues({
      'caller_token': 't',
      'caller_me': jsonEncode({'login': 'asha@team.in', 'name': 'Asha'}),
    });
    final sent = <Map<String, dynamic>>[];
    final c = CallerController(
      api: CallerApi(
          client: MockClient((req) async {
            if (req.url.path == '/crm/calls/sync') {
              final body = jsonDecode(req.body) as Map<String, dynamic>;
              sent.add(body);
              return http.Response(jsonEncode({'synced': (body['calls'] as List).length, 'new_leads': 1}), 200);
            }
            // Tanya is saved in the phone and is a CRM lead; Friend is saved and is not.
            return http.Response(
                jsonEncode({
                  'me': {'login': 'asha@team.in'},
                  'leads': [
                    {'phone': '9811100001', 'name': 'Tanya', 'heat': {'temperature': 'warm', 'score': 30}}
                  ]
                }),
                200);
          }),
          hosts: ['https://crm.test']),
      clock: () => now,
    );
    await c.init();
    await c.refresh();
    await c.setPersonal('9811100002', true); // Mom

    sent.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('caller_synced_upto_ms'); // as on first run, after marking Mom personal
    await c.syncDeviceCalls();
    final calls = (sent.single['calls'] as List).cast<Map>();
    // Oldest first. Not Mom (marked personal), not Friend (a saved contact who is not a lead: never leaves the phone),
    // not the 9-day-old call, not 1234. Tanya is saved too, but she is a CRM lead, so her call goes.
    expect(calls.map((x) => x['phone']), ['9811100003', '+91 98111 00001']);
    expect(calls.first['missed'], isTrue);
    expect(calls.first['direction'], 'in');
    expect(calls.last['contact_name'], 'Tanya');
    expect(calls.last['duration_s'], 240);
    expect(sent.single['add_new'], isTrue);

    sent.clear();
    await c.syncDeviceCalls();
    expect(sent, isEmpty); // nothing new: nothing sent

    await c.setAutoAdd(false);
    phoneLog.insert(0, {'phone': '9811100005', 'name': '', 'type': 'out', 'duration_s': 5, 'started_at_ms': now.millisecondsSinceEpoch});
    await c.syncDeviceCalls();
    expect(sent.single['add_new'], isFalse);
    c.dispose();
  });
}
