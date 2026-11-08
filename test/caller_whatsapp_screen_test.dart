// The owner's WhatsApp, laid out like WhatsApp: one row per person with who sent the last message and the unread count;
// a chat with our messages on the right, each with who sent it (demo data, no server).
import 'package:altrobytelab/caller/caller_api.dart';
import 'package:altrobytelab/caller/caller_controller.dart';
import 'package:altrobytelab/caller/demo_client.dart';
import 'package:altrobytelab/caller/whatsapp_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('chats like WhatsApp, Jarvis filter, a chat says who sent each message', (tester) async {
    final c = CallerController(api: CallerApi(client: DemoClient(), hosts: ['https://demo.local']), demo: true);
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    Future<void> settle() async {
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    await tester.pumpWidget(ChangeNotifierProvider.value(value: c, child: const MaterialApp(home: Scaffold(body: WhatsAppScreen()))));
    await settle();
    expect(find.text('Riya (sample)'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);                                // unread count
    expect(find.text('WhatsApp AI: '), findsOneWidget);                   // who sent the last message
    await tester.tap(find.text('Jarvis'));
    await settle();
    expect(find.text('Aman (sample)'), findsNothing);
    await tester.tap(find.text('Riya (sample)'));
    await settle();
    await settle();
    expect(find.text('Jarvis'), findsOneWidget);                           // the bubble's sender
    expect(find.textContaining('Saturday 6 pm'), findsOneWidget);
    expect(find.text('Message'), findsOneWidget);                          // the box to write
  });
}
