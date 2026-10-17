// "Log this call": filled in from the call that just ended, every choice a tap, and the usual log one tap on Save.

import 'package:altrobytelab/caller/caller_native.dart';
import 'package:altrobytelab/caller/log_call_sheet.dart';
import 'package:altrobytelab/caller/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final now = DateTime(2026, 10, 17, 10, 0);
const meera = Lead(phone: '9800000001', name: 'Meera', stage: 'new', labels: ['working'], heat: Heat(temperature: 'warm', pct: 35));
const labels = ['student', 'working', 'wants EMI'];

class Opened {
  CallLog? log;
  bool closed = false;
}

Future<Opened> open(WidgetTester tester,
    {Lead lead = meera,
    CallEnded? call,
    bool isNew = false,
    Future<String> Function(String)? onQuickWa,
    List<Map<String, dynamic>> quick = const []}) async {
  await tester.binding.setSurfaceSize(const Size(480, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final got = Opened();
  var n = 0;
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () async {
              got.log = await showLogCallSheet(
                  context,
                  LogCallSheet(
                      lead: lead,
                      call: call,
                      isNew: isNew,
                      labels: labels,
                      now: now,
                      newId: () => 'id-${n++}',
                      quickMessages: quick,
                      onQuickWa: onQuickWa));
              got.closed = true;
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return got;
}

bool selected(WidgetTester tester, String key) => tester.widget<ChoiceChip>(find.byKey(ValueKey(key))).selected;

Future<void> tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(ValueKey(key)));
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a connected call opens filled in, and one tap on Save logs it', (tester) async {
    final got = await open(tester,
        call: CallEnded(phone: '+919800000001', durationS: 245, type: 'out', startedAt: now.toUtc(), expected: true));
    expect(find.text('Log this call'), findsOneWidget);
    expect(find.text('You called · talked 4m 05s'), findsOneWidget);
    expect(selected(tester, 'outcome_connected'), isTrue);
    expect(selected(tester, 'stage_contacted'), isTrue); // a new lead who picked up is now contacted
    expect(selected(tester, 'follow_None'), isTrue);

    await tap(tester, 'save');
    final log = got.log!;
    expect(log.clientId, 'id-0');
    expect(log.outcome, 'connected');
    expect(log.durationS, 245);
    expect(log.direction, 'out');
    expect(log.stage, 'contacted');
    expect(log.labels, isNull); // untouched labels are left as they are
    expect(log.nextFollowupAt, isNull);
  });

  testWidgets('nobody picked up: no answer, and a follow-up in two hours, already chosen', (tester) async {
    final got = await open(tester, call: CallEnded(phone: '9800000001', durationS: 0, type: 'out', startedAt: now.toUtc()));
    expect(find.text('You called · not picked up'), findsOneWidget);
    expect(selected(tester, 'outcome_no_answer'), isTrue);
    expect(selected(tester, 'follow_In 2 h'), isTrue);
    expect(selected(tester, 'stage_new'), isTrue);
    await tap(tester, 'save');
    expect(got.log!.outcome, 'no_answer');
    expect(got.log!.stage, ''); // unchanged
    expect(got.log!.nextFollowupAt, now.add(const Duration(hours: 2)).toUtc());
  });

  testWidgets('every field is a tap: interest, stage, labels, call back tomorrow, a note', (tester) async {
    final got = await open(tester);
    expect(tester.widget<FilledButton>(find.byKey(const ValueKey('save'))).onPressed, isNull); // say what happened first
    await tap(tester, 'outcome_call_back');
    expect(selected(tester, 'follow_Tomorrow 11 am'), isTrue);
    await tap(tester, 'interest_hot');
    await tap(tester, 'stage_demo_booked');
    await tap(tester, 'label_wants EMI');
    await tap(tester, 'label_working'); // off again
    await tester.enterText(find.byKey(const ValueKey('note')), 'Wants the weekend batch');
    await tap(tester, 'save');
    final log = got.log!;
    expect([log.outcome, log.interest, log.stage], ['call_back', 'hot', 'demo_booked']);
    expect(log.labels, ['wants EMI']);
    expect(log.nextFollowupAt, DateTime(2026, 10, 18, 11).toUtc());
    expect(log.note, 'Wants the weekend batch');
  });

  testWidgets('a lead marked lost needs a reason before it can be saved', (tester) async {
    final got = await open(tester);
    await tap(tester, 'outcome_connected');
    await tap(tester, 'stage_lost');
    expect(find.text('Pick why it was lost'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const ValueKey('save'))).onPressed, isNull);
    await tap(tester, 'lost_Joined elsewhere');
    await tap(tester, 'save');
    expect(got.log!.stage, 'lost');
    expect(got.log!.lostReason, 'Joined elsewhere');
  });

  testWidgets('a call from a number that is not a lead offers to add it, with a name', (tester) async {
    final got = await open(tester,
        lead: const Lead(phone: '9811111111'),
        isNew: true,
        call: CallEnded(phone: '9811111111', durationS: 30, type: 'in', startedAt: now.toUtc()));
    expect(find.text('Add as a lead?'), findsOneWidget);
    expect(find.text('They called · talked 30s'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('name')), 'Sana');
    await tap(tester, 'save');
    expect(got.log!.name, 'Sana');
    expect(got.log!.direction, 'in');
    expect(got.log!.outcome, 'connected');
  });

  testWidgets('without the call log the sheet does not guess whether they picked up', (tester) async {
    await open(tester, call: CallEnded(phone: '9800000001', durationS: 40, type: 'out', startedAt: now.toUtc(), known: false));
    expect(find.text('You called · how did it go?'), findsOneWidget);
    expect(selected(tester, 'outcome_connected'), isFalse);
    expect(selected(tester, 'outcome_no_answer'), isFalse);
  });

  testWidgets('a quick WhatsApp goes with a tap and says how it went', (tester) async {
    final sent = <String>[];
    await open(tester,
        quick: const [
          {'kind': 'roadmap', 'text': 'Here is the roadmap'}
        ],
        onQuickWa: (kind) async {
          sent.add(kind);
          return 'Sent on WhatsApp.';
        });
    await tap(tester, 'wa_roadmap');
    expect(sent, ['roadmap']);
    expect(find.text('Sent on WhatsApp.'), findsOneWidget);
  });

  testWidgets('a tap on the after-call card fills the sheet in with that choice', (tester) async {
    final got = await open(tester,
        call: CallEnded(phone: '9800000001', durationS: 120, type: 'out', startedAt: now.toUtc(), preset: 'interested'));
    expect(selected(tester, 'outcome_connected'), isTrue);
    expect(selected(tester, 'interest_hot'), isTrue);
    expect(selected(tester, 'stage_interested'), isTrue);
    await tap(tester, 'save');
    expect([got.log!.outcome, got.log!.interest, got.log!.stage], ['connected', 'hot', 'interested']);
  });

  testWidgets('call back on the card means call back tomorrow at 11', (tester) async {
    await open(tester, call: CallEnded(phone: '9800000001', durationS: 40, type: 'in', startedAt: now.toUtc(), preset: 'call_back'));
    expect(selected(tester, 'outcome_call_back'), isTrue);
    expect(selected(tester, 'follow_Tomorrow 11 am'), isTrue);
  });

  testWidgets('swiping the sheet away logs nothing', (tester) async {
    final got = await open(tester);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(got.closed, isTrue);
    expect(got.log, isNull);
  });
}
