import 'package:flutter_test/flutter_test.dart';
import 'package:altrobytelab/screens/enrolment/plan_pay.dart';

void main() {
  test('the bill reads fee, GST, total, with the numbers the server sent', () {
    final lines = billLines({'name': 'Plan 2', 'tag': 'With Kit', 'period': 'for 2 months', 'fee': 18000, 'gst_rate': 18.0, 'gst': 3240, 'total': 21240});
    expect(lines, [('Plan 2 (With Kit), for 2 months', '₹18,000'), ('GST 18%', '₹3,240'), ('Total to pay', '₹21,240')]);
    expect(billLines({'name': 'P', 'tag': 't', 'period': 'x', 'fee': 100, 'gst_rate': 12.5, 'gst': 13, 'total': 113})[1].$1, 'GST 12.5%');
  });

  test('rupees are written the Indian way', () {
    expect(rupees(999), '₹999');
    expect(rupees(21240), '₹21,240');
    expect(rupees(125000), '₹1,25,000');
  });
}
