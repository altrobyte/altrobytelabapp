// Altrobyte Industrial on a tablet, for the team to try (30 Oct 2026). Sign in with a team WhatsApp number, then the same
// Industrial page as the desktop: train a worker, the test, the certificate, the plant's record.
//
//   flutter run --flavor industrial -t lib/industrial/industrial_main.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../desktop/industrial_flow.dart';
import '../desktop/industrial_home.dart';
import '../services/api_service.dart';
import 'tablet_lesson.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  indShareFile = (path, mime, subject) => Share.shareXFiles([XFile(path, mimeType: mime)], subject: subject);
  indOpenUrl = (url) => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Altrobyte Industrial',
    theme: ThemeData(colorSchemeSeed: indGold, brightness: Brightness.dark, scaffoldBackgroundColor: indInk),
    home: const _Gate(),
  ));
}

class _Gate extends StatefulWidget {
  const _Gate();
  @override
  State<_Gate> createState() => _GateState();
}

class _GateState extends State<_Gate> {
  bool? _signedIn;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) => setState(() => _signedIn = (p.getString('student_token') ?? '').isNotEmpty));
  }

  @override
  Widget build(BuildContext context) {
    if (_signedIn == null) return const Scaffold(body: Center(child: CircularProgressIndicator(color: indGold)));
    if (_signedIn == false) return _SignIn(onDone: () => setState(() => _signedIn = true));
    return Scaffold(
      backgroundColor: indInk,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: IndustrialHome(lesson: (p) => TabletLessonScreen(programme: p)),
        ),
      ),
    );
  }
}

class _SignIn extends StatefulWidget {
  final VoidCallback onDone;
  const _SignIn({required this.onDone});
  @override
  State<_SignIn> createState() => _SignInState();
}

class _SignInState extends State<_SignIn> {
  final _phone = TextEditingController(), _otp = TextEditingController();
  bool _sent = false, _busy = false;
  String _error = '';

  String get _digits => _phone.text.replaceAll(RegExp(r'\D'), '');

  Future<void> _go() async {
    setState(() { _busy = true; _error = ''; });
    try {
      if (!_sent) {
        if (_digits.length < 10) throw 'Enter a 10-digit WhatsApp number.';
        await ApiService.standaloneRequestOtp(phone: _digits);
        setState(() => _sent = true);
      } else {
        final res = await ApiService.standaloneVerifyOtp(phone: _digits, otp: _otp.text.trim());
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('student_token', res['token'] as String? ?? '');
        await prefs.setString('token', res['jwt_token'] as String? ?? '');
        widget.onDone();
      }
    } catch (e) {
      setState(() => _error = e is String ? e : (e is ApiException ? e.message : 'Could not sign in. Check the internet and try again.'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: indInk,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('ALTROBYTE INDUSTRIAL', style: GoogleFonts.inter(color: indGold, letterSpacing: 3, fontWeight: FontWeight.w700, fontSize: 12)),
              const SizedBox(height: 10),
              Text('Sign in with the team\'s WhatsApp number', style: GoogleFonts.poppins(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
              const SizedBox(height: 20),
              TextField(controller: _phone, enabled: !_sent, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'WhatsApp number')),
              if (_sent) ...[
                const SizedBox(height: 12),
                TextField(controller: _otp, autofocus: true, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Code sent on WhatsApp')),
              ],
              if (_error.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(_error, style: const TextStyle(color: indBad)),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _busy ? null : _go,
                style: FilledButton.styleFrom(backgroundColor: indGold, foregroundColor: indInk, minimumSize: const Size.fromHeight(48)),
                child: Text(_sent ? 'Sign in' : 'Send code'),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
