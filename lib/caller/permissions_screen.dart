// Shown on first launch (and from the menu): every permission the app asks for, why, in plain words. Nothing is asked
// for before the caller has read what it is for.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_colors.dart';
import 'caller_native.dart';

class Need {
  final String key;
  final IconData icon;
  final String title;
  final String why;
  final bool required;
  const Need(this.key, this.icon, this.title, this.why, {this.required = false});
}

const needs = [
  Need('call_phone', Icons.call, 'Make calls',
      'So tapping Call rings the lead straight away, without typing the number. The app never calls anyone by itself.',
      required: true),
  Need('phone_state', Icons.phone_in_talk, 'Know when a call ends',
      'So the "Log this call" sheet opens by itself the moment you hang up.', required: true),
  Need('call_log', Icons.history, 'Read the call log',
      'To fill in how long the call lasted and whether they picked up, and to see who is ringing. '
      'The app only looks at calls with leads; nothing about your other calls is sent anywhere. No call is ever recorded.'),
  Need('notifications', Icons.notifications_active, 'Show reminders', 'To remind you when a follow-up is due. Tap it to open the lead.'),
  Need('overlay', Icons.picture_in_picture, 'Show caller ID over other apps',
      'When a lead calls you, a small card shows their name, heat, stage and last note while the phone rings. '
      'Android opens a settings page for this one: find Altrobyte Caller and switch it on.'),
];

class PermissionsScreen extends StatefulWidget {
  final VoidCallback onDone;
  const PermissionsScreen({super.key, required this.onDone});

  static Future<bool> seen() async => (await SharedPreferences.getInstance()).getBool('caller_perm_intro') ?? false;

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> with WidgetsBindingObserver {
  Map<String, bool> _have = const {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check(); // back from a settings page
  }

  Future<void> _check() async {
    final have = await CallerNative.instance.permissions();
    if (mounted) setState(() => _have = have);
  }

  Future<void> _done() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('caller_perm_intro', true);
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Before you start'), backgroundColor: AppColors.primary, foregroundColor: Colors.white),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Altrobyte Caller needs a few permissions. Here is what each one is for.',
            style: TextStyle(fontSize: 15)),
        const SizedBox(height: 12),
        for (final n in needs)
          Card(
            child: ListTile(
              leading: Icon(n.icon, color: AppColors.primary),
              title: Text(n.title, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(n.why),
              isThreeLine: true,
              trailing: _have[n.key] == true
                  ? const Icon(Icons.check_circle, color: AppColors.success)
                  : TextButton(
                      onPressed: () async {
                        await CallerNative.instance.requestPermission(n.key);
                        await _check();
                      },
                      child: const Text('Allow'),
                    ),
            ),
          ),
        const SizedBox(height: 8),
        const Text('You can change any of these later in Android settings. The app works without the optional ones; '
            'you will just type a little more.', style: TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 16),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.accent, minimumSize: const Size.fromHeight(50)),
          onPressed: _done,
          child: const Text('Continue', style: TextStyle(fontSize: 16)),
        ),
      ]),
    );
  }
}
