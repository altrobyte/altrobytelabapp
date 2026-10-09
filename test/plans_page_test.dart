import 'package:flutter_test/flutter_test.dart';
import 'package:altrobytelab/screens/plans_page.dart';

void main() {
  test('the three plans carry the numbers on the poster, and the saving follows from them', () {
    expect(programPlans.map((p) => (p.offer, p.standard, p.months)).toList(), [(10000, 18000, 1), (18000, 32000, 2), (28000, 50000, 3)]);
    expect(programPlans.map((p) => p.percentOff).toList(), [44, 44, 44]);
    expect(programPlans.map((p) => p.saving).toList(), [8000, 14000, 22000]);
    expect(programPlans[1].perMonth, 9000);
    expect(programPlans[2].features, containsAll(['Mini lab set-up kit', 'Placement assistance']));
    expect(programPlans[0].features, isNot(contains('Mini lab set-up kit')));
    expect(programPlans.where((p) => p.recommended).single.name, 'Plan 3');
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

  test('the WhatsApp message names the plan and the price being shown', () {
    expect(enrolMessage(programPlans[2], true), contains('Plan 3 (With Kit + Placement)'));
    expect(enrolMessage(programPlans[2], true), contains('₹28,000 for 3 months + GST'));
    expect(enrolMessage(programPlans[2], false), contains('₹50,000 for 3 months + GST'));
  });
}
