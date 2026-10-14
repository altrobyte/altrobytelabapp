// "Help": a message to a mentor on WhatsApp, already saying where the learner is (the lesson, the step, the note), so the
// mentor does not have to ask before they can help. It opens WhatsApp on this computer (the app or WhatsApp Web) with the
// message written; the learner presses send. Each press is also counted, so we can see where people get stuck.

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import 'visual_page.dart';

/// The WhatsApp link for a help message. [where] is what the learner is doing ("Course: Set up · Step: Install the drivers").
String helpLink(String number, String where) {
  final text = 'Hi, I need help with the Altrobyte AI Trainer.\n${where.isEmpty ? '' : 'Where I am: $where\n'}My problem: ';
  final digits = number.replaceAll(RegExp(r'\D'), '');
  return digits.isEmpty
      ? 'https://wa.me/?text=${Uri.encodeComponent(text)}'
      : 'https://wa.me/$digits?text=${Uri.encodeComponent(text)}';
}

class HelpButton extends StatelessWidget {
  /// Where the learner is, worked out when the button is pressed (it changes as they move on).
  final String Function() where;
  final Color color;
  const HelpButton({super.key, required this.where, this.color = Colors.white});

  static String? _number; // asked for once per run

  Future<void> _help(BuildContext context) async {
    final here = where();
    ApiService.trainerEvent('help_clicked', detail: here);
    try {
      _number ??= await ApiService.trainerHelpNumber();
    } catch (_) {}
    final ok = await openExternal(helpLink(_number ?? '', here));
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('WhatsApp did not open. Message your mentor on WhatsApp and say which lesson and step you are on.')));
    }
  }

  @override
  Widget build(BuildContext context) => TextButton.icon(
        onPressed: () => _help(context),
        icon: Icon(Icons.support_agent_rounded, color: color, size: 19),
        label: Text('Help', style: TextStyle(color: color)),
      );
}
