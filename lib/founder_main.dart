// The founder's Altron as its own small Android app (24 Oct 2026): sign in once with the admin email and password, then
// Altron opens straight away. Built from this entry point only, so none of the website's browser-only code comes in:
//   flutter build apk --release -t lib/founder_main.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/admin/founder_altron_screen.dart';
import 'services/api_service.dart';

void main() => runApp(const FounderApp());

class FounderApp extends StatelessWidget {
  const FounderApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Altron',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorSchemeSeed: const Color(0xFF14343F), useMaterial3: true),
        home: const _Gate(),
      );
}

class _Gate extends StatefulWidget {
  const _Gate();

  @override
  State<_Gate> createState() => _GateState();
}

class _GateState extends State<_Gate> {
  String? _token;
  bool _ready = false;
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) => setState(() {
          _token = p.getString('token');
          _ready = true;
        }));
  }

  Future<void> _signIn() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await ApiService.login(_email.text.trim(), _password.text);
      final role = '${r['role'] ?? ''}';
      if (role != 'admin' && role != 'super_admin') throw 'This account is not an admin.';
      final t = '${r['token'] ?? ''}';
      await (await SharedPreferences.getInstance()).setString('token', t);
      setState(() => _token = t);
    } catch (e) {
      setState(() => _error = e is String ? e : 'Could not sign in. Check the email and password.');
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _signOut() async {
    await (await SharedPreferences.getInstance()).remove('token');
    setState(() => _token = null);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const Scaffold(backgroundColor: Color(0xFF0F2530));
    final t = _token;
    if (t != null && t.isNotEmpty) return FounderAltronScreen(token: t, onSignOut: _signOut);
    return Scaffold(
      backgroundColor: const Color(0xFF0F2530),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Altron', textAlign: TextAlign.center, style: GoogleFonts.poppins(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text('Your leads and your course, by voice.', textAlign: TextAlign.center, style: GoogleFonts.inter(color: Colors.white70)),
              const SizedBox(height: 28),
              TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: _dec('Admin email')),
              const SizedBox(height: 12),
              TextField(controller: _password, obscureText: true, decoration: _dec('Password'), onSubmitted: (_) => _signIn()),
              if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: const TextStyle(color: Color(0xFFFF8A80)))),
              const SizedBox(height: 18),
              FilledButton(onPressed: _busy ? null : _signIn, child: Padding(padding: const EdgeInsets.all(12), child: Text(_busy ? 'Signing in…' : 'Sign in'))),
            ]),
          ),
        ),
      ),
    );
  }

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      );
}
