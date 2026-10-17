import 'package:flutter_test/flutter_test.dart';
import 'package:altrobytelab/screens/plans_page.dart';

void main() {
  test('monthly leads, three months together saves against monthly, and every plan has the kit', () {
    expect(programPlans.map((p) => (p.offer, p.standard, p.months)).toList(), [(9999, 9999, 1), (27999, 29997, 3)]);
    expect(programPlans.map((p) => p.saving).toList(), [0, 1998]); // the only struck-out price is a real saving
    expect(programPlans.every((p) => p.features.contains('Mini lab set-up kit')), isTrue);
    expect(programPlans[1].features, contains('Placement assistance'));
    expect(programPlans[0].features, isNot(contains('Placement assistance')));
    expect(programPlans.where((p) => p.recommended).single.name, 'Monthly');
  });

  test('rupees are written the Indian way', () {
    expect(inr(999), '₹999');
    expect(inr(10000), '₹10,000');
    expect(inr(150000), '₹1,50,000');
    expect(inr(12345678), '₹1,23,45,678');
  });

  test('the countdown runs to the end of the set day in India and is gone after it', () {
    final end = offerEnd('2026-10-31')!;
    expect(end, DateTime.utc(2026, 10, 31, 18, 29, 59)); // 23:59:59 IST
    final left = offerLeft('2026-10-31', DateTime.utc(2026, 10, 30, 18, 29, 59))!;
    expect(left.inHours, 24);
    expect(offerLeft('2026-10-31', DateTime.utc(2026, 10, 31, 18, 30)), isNull); // midnight IST has passed
    expect(offerRunning('2026-10-31', DateTime.utc(2026, 10, 31, 18, 30)), isFalse); // so the standard fee is the price
    expect(offerRunning('2026-10-31', DateTime.utc(2026, 10, 1)), isTrue);
  });

  test('no date, or a date that cannot be read, means no countdown but the offer stands', () {
    for (final s in ['', '  ', null, 'soon', '31-10-2026', '2026-13-01']) {
      expect(offerLeft(s, DateTime.utc(2026, 10, 1)), isNull, reason: '$s');
      expect(offerRunning(s, DateTime.utc(2026, 10, 1)), isTrue, reason: '$s');
    }
  });

  test('Enrol goes to the enrolment form with the plan, and never anywhere else when a form is open', () {
    expect(enrolPath('embedded-batch-x1', programPlans[1]), '/enroll/embedded-batch-x1?plan=plan3');
    expect(enrolPath('  ', programPlans[1]), isNull); // no form open: the page falls back to WhatsApp, not to another form
    expect(programPlans.map((p) => p.key).toList(), ['plan1', 'plan3']);
  });

  test('plans from the server replace the built-in ones only when they are complete', () {
    final ok = ProgramPlan.fromJson({'key': 'plan2', 'name': 'Plan 2', 'tag': 'With Kit', 'offer': 18000, 'standard': 32000, 'months': 2, 'period': 'for 2 months', 'features': ['Kit'], 'recommended': false})!;
    expect((ok.key, ok.offer, ok.perMonth), ('plan2', 18000, 9000));
    expect(ok.features, ['Kit']);
    expect(ProgramPlan.fromJson({'key': 'plan2', 'name': 'Plan 2', 'offer': 18000}), isNull);
    expect(ProgramPlan.fromJson({'key': 'p', 'name': 'P', 'offer': 50000, 'standard': 100, 'months': 1}), isNull); // an offer above the standard fee is not an offer
  });

  test('the WhatsApp message names the plan and the price being shown', () {
    expect(enrolMessage(programPlans[1], true), contains('3 months together (Kit + placement, pay once)'));
    expect(enrolMessage(programPlans[1], true), contains('₹27,999 for 3 months + GST'));
    expect(enrolMessage(programPlans[1], false), contains('₹29,997 for 3 months + GST'));
    expect(enrolMessage(programPlans[0], true), contains('₹9,999 per month + GST'));
  });
}
