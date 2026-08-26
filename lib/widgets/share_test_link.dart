import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Send one test to a class group.
///
/// The link is /t/<id> on our own domain rather than the API host: what gets
/// pasted has to open on every reader's network, and at least one could not
/// resolve *.up.railway.app at all. It redirects to a page carrying the real
/// preview — question count and duration — so a group sees what it is before
/// anybody taps.
Future<void> shareTestLink(
  BuildContext context, {
  required int id,
  required String title,
  int minutes = 0,
  int questions = 0,
}) async {
  final url = 'https://altrobytelab.com/t/$id';
  final bits = <String>[
    if (questions > 0) '$questions questions',
    if (minutes > 0) '$minutes min',
  ];
  final text = Uri.encodeComponent('*$title*'
      '${bits.isEmpty ? '' : '\n${bits.join(' · ')}'}'
      '\n\nFree practice test from Altrobyte Lab:\n$url');

  final messenger = ScaffoldMessenger.of(context);
  if (await launchUrl(Uri.parse('https://wa.me/?text=$text'),
      mode: LaunchMode.externalApplication)) {
    return;
  }
  await Clipboard.setData(ClipboardData(text: url));
  messenger.showSnackBar(const SnackBar(content: Text('Link copied')));
}
