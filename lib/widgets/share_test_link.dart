import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Copy the link to one test.
///
/// This used to open WhatsApp Web, which on a desktop means a new tab, a QR
/// screen and a message you did not ask to compose. Copying is what "share"
/// means here: the link goes wherever the person was already going to put it.
///
/// The link is /t/<id> on our own domain rather than the API host — what gets
/// pasted has to open on every reader's network, and at least one could not
/// resolve *.up.railway.app at all. It redirects to a page carrying the real
/// preview, so a group sees the question count and duration before anybody
/// taps.
Future<void> shareTestLink(
  BuildContext context, {
  required int id,
  required String title,
  int minutes = 0,
  int questions = 0,
}) async {
  final url = 'https://altrobytelab.com/t/$id';
  final facts = <String>[
    if (questions > 0) '$questions questions',
    if (minutes > 0) '$minutes min',
  ];

  // The whole message, not the bare link. A URL pasted on its own says
  // nothing until somebody opens it, and most people in a group will not.
  final message = [
    title,
    if (facts.isNotEmpty) facts.join(' · '),
    '',
    'Free practice test from Altrobyte Lab:',
    url,
  ].join(String.fromCharCode(10));

  final messenger = ScaffoldMessenger.of(context);
  await Clipboard.setData(ClipboardData(text: message));
  messenger.showSnackBar(const SnackBar(
    duration: Duration(seconds: 2),
    content: Text('Message copied — paste it in any chat'),
  ));
}
