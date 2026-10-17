// The Today screen shows the queue in the order to call it, grouped, with what a caller needs on each card.

import 'dart:convert';

import 'package:altrobytelab/caller/caller_api.dart';
import 'package:altrobytelab/caller/caller_controller.dart';
import 'package:altrobytelab/caller/today_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final now = DateTime.utc(2026, 10, 17, 10);
  Map<String, dynamic> lead(String phone, String name, String temp, int score,
          {String stage = 'new', DateTime? follow, DateTime? called, bool converted = false, String note = ''}) =>
      {
        'phone': phone,
        'name': name,
        'stage': stage,
        'labels': name == 'Hot Hari' ? ['wants EMI'] : [],
        'heat': {'temperature': temp, 'score': score, 'pct': score.clamp(0, 100)},
        'next_followup_at': follow?.toIso8601String(),
        'last_called_at': called?.toIso8601String(),
        'converted': converted,
        'last_note': note,
      };

  testWidgets('the queue reads top to bottom in the order to call', (tester) async {
    // The server's order is deliberately scrambled: the screen must not depend on it.
    final leads = [
      lead('9800000006', 'Paid Priya', 'customer', 0, converted: true),
      lead('9800000005', 'Later Lata', 'hot', 80, follow: now.add(const Duration(days: 1))),
      lead('9800000004', 'Rest Rohan', 'cold', 5, stage: 'contacted', called: now.subtract(const Duration(days: 2))),
      lead('9800000003', 'New Neha', 'cold', 0),
      lead('9800000002', 'Hot Hari', 'hot', 70, note: 'Asked about fees'),
      lead('9800000001', 'Due Divya', 'warm', 30, follow: now.subtract(const Duration(minutes: 20))),
    ];
    SharedPreferences.setMockInitialValues({
      'caller_token': 't',
      'caller_me': jsonEncode({'login': 'asha@team.in', 'name': 'Asha'}),
    });
    final c = CallerController(
      api: CallerApi(
          client: MockClient((req) async => http.Response(jsonEncode({'me': {'login': 'asha@team.in'}, 'leads': leads}), 200)),
          hosts: ['https://crm.test']),
      clock: () => now,
    );
    await tester.runAsync(() async {
      await c.init();
      await c.refresh();
    });
    await tester.binding.setSurfaceSize(const Size(480, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: c, child: const MaterialApp(home: Scaffold(body: TodayScreen()))));
    await tester.pump();

    double y(String text) => tester.getTopLeft(find.text(text)).dy;
    final names = ['Due Divya', 'Hot Hari', 'New Neha', 'Rest Rohan', 'Later Lata', 'Paid Priya'];
    for (var i = 1; i < names.length; i++) {
      expect(y(names[i - 1]) < y(names[i]), isTrue, reason: '${names[i - 1]} should come before ${names[i]}');
    }
    expect(find.text('Follow-ups due now  ·  1'), findsOneWidget);
    expect(find.text('Converted 🎉  ·  1'), findsOneWidget);
    expect(find.text('Converted 🎉'), findsOneWidget); // the badge on Priya's card
    expect(find.text('🔥 Hot · 70%'), findsOneWidget);
    expect(find.text('wants EMI'), findsOneWidget);
    expect(find.text('Asked about fees'), findsOneWidget);
    expect(find.textContaining('Due 17 Oct'), findsOneWidget);
    expect(find.byKey(const ValueKey('call_9800000002')), findsOneWidget);
    c.dispose();
  });
}
