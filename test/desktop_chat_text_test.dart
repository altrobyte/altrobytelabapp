import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:altrobytelab/desktop/chat_text.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  test('bold and code are shown without their markers', () {
    final spans = ChatText.spans('The board is **COM6**, use `esp32dev`.', const TextStyle(fontSize: 13));
    final plain = spans.map((s) => (s as TextSpan).text).join();
    expect(plain, 'The board is COM6, use esp32dev.');
    expect((spans[1] as TextSpan).style!.fontWeight, FontWeight.w700);
  });

  testWidgets('bullets and headings render without raw markdown', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: ChatText('## Steps\n- first **one**\n2. second', color: Colors.black))));
    expect(find.textContaining('##', findRichText: true), findsNothing);
    expect(find.textContaining('**', findRichText: true), findsNothing);
    expect(find.textContaining('first one', findRichText: true), findsOneWidget);
    expect(find.text('•'), findsOneWidget);
    expect(find.text('2.'), findsOneWidget);
  });
}
