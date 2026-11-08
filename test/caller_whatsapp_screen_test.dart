// The owner's WhatsApp tab: who sent each message, the replies, and the totals (demo data, no server).
import 'package:altrobytelab/caller/caller_api.dart';
import 'package:altrobytelab/caller/caller_controller.dart';
import 'package:altrobytelab/caller/demo_client.dart';
import 'package:altrobytelab/caller/whatsapp_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('shows who sent each message and filters Jarvis', (tester) async {
    final c = CallerController(api: CallerApi(client: DemoClient(), hosts: ['https://demo.local']), demo: true);
    await tester.binding.setSurfaceSize(const Size(480, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(ChangeNotifierProvider.value(value: c, child: const MaterialApp(home: Scaffold(body: WhatsAppScreen()))));
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();
    expect(find.text('Jarvis'), findsWidgets);
    expect(find.text('Reply from them'), findsOneWidget);
    expect(find.text('Follow-up automation'), findsOneWidget);
    expect(find.text('Not sent'), findsWidgets);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Jarvis'));
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();
    expect(find.text('Follow-up automation'), findsNothing);
    expect(find.textContaining('Saturday 6 pm'), findsOneWidget);
  });
}
