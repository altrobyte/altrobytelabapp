import 'package:altrobytelab/desktop/help_button.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the help message goes to the mentor number and already says where the learner is', () {
    final link = Uri.parse(helpLink('+91 91115 30407', 'Lesson: Set up · Step: Install the USB driver'));
    expect(link.host, 'wa.me');
    expect(link.path, '/919111530407');
    final text = link.queryParameters['text']!;
    expect(text, contains('Where I am: Lesson: Set up · Step: Install the USB driver'));
    expect(text, endsWith('My problem: '));
  });

  test('with no number set, WhatsApp still opens with the message, to pick a chat', () {
    final link = Uri.parse(helpLink('', 'On the home screen'));
    expect(link.path, '/');
    expect(link.queryParameters['text'], contains('On the home screen'));
  });
}
