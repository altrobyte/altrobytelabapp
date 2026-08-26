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
  final messenger = ScaffoldMessenger.of(context);
  await Clipboard.setData(
      ClipboardData(text: 'https://altrobytelab.com/t/$id'));
  messenger.showSnackBar(SnackBar(
    duration: const Duration(seconds: 2),
    content: Text('Link copied — paste it anywhere ($title)',
        maxLines: 2, overflow: TextOverflow.ellipsis),
  ));
}
