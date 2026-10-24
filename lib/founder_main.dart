// The founder's Altron as its own small Android app (24-25 Oct 2026).
//
// Everything Altron does lives in the phone's own code (android/app/src/altron, WakeService): it listens for "Altron"
// offline, shows a thin glowing strip over any app, runs the live voice out of sight under it, and stops the voice the
// moment the talk is over. The × on the strip or Stop in the notification turns it all off.
//
// This screen only asks for the microphone, hands the app's key to that code and steps away. No login: the key, built
// in at build time, is traded for a sign-in each time Altron wakes.
//
//   python tools/fetch_vosk_model.py
//   flutter build apk --release --flavor altron -t lib/founder_main.dart --dart-define=FOUNDER_KEY=<the key>

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import 'constants/api_constants.dart';

const _key = String.fromEnvironment('FOUNDER_KEY');
const _native = MethodChannel('altron/native');

void main() => runApp(const MaterialApp(debugShowCheckedModeBanner: false, home: _Start()));

class _Start extends StatefulWidget {
  const _Start();

  @override
  State<_Start> createState() => _StartState();
}

class _StartState extends State<_Start> {
  String _line = '';

  @override
  void initState() {
    super.initState();
    _go();
  }

  Future<void> _go() async {
    if (!(await Permission.microphone.request()).isGranted) {
      setState(() => _line = 'Altron needs the microphone. Allow it in Settings → Apps → Altron → Permissions, then open Altron again.');
      return;
    }
    // For "Altron, Ravi ko call karo". Saying no only means Altron cannot place calls.
    await [Permission.contacts, Permission.phone].request();
    try {
      final r = await _native.invokeMethod('start', {'key': _key, 'api': ApiConstants.baseUrl});
      if (r == 'needs_overlay' && mounted) setState(() => _line = 'Turn on "Display over other apps" for Altron, then come back.');
    } catch (_) {
      if (mounted) setState(() => _line = 'Altron could not start. Open it again.');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.transparent,
        body: _line.isEmpty
            ? const SizedBox.shrink()
            : Center(
                child: Container(
                  margin: const EdgeInsets.all(24),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(color: const Color(0xFF0F2530), borderRadius: BorderRadius.circular(16)),
                  child: Text(_line, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.4)),
                ),
              ),
      );
}
