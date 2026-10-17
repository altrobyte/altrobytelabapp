import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_colors.dart';
import 'caller_controller.dart';

/// Two ways in: the institute owner with a WhatsApp code to the number on the account (no password to remember), and
/// telecallers with the email and password the admin gave them (web CRM > Calling team > People).
class CallerLoginScreen extends StatefulWidget {
  const CallerLoginScreen({super.key});

  @override
  State<CallerLoginScreen> createState() => _CallerLoginScreenState();
}

class _CallerLoginScreenState extends State<CallerLoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _phone = TextEditingController();
  final _code = TextEditingController();
  bool _whatsapp = true, _codeSent = false, _admin = false, _busy = false;
  String? _problem, _info;

  @override
  void dispose() {
    for (final c in [_email, _password, _phone, _code]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _run(Future<void> Function() f) async {
    setState(() {
      _busy = true;
      _problem = null;
    });
    await f();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _sendCode() => _run(() async {
        if (_phone.text.replaceAll(RegExp(r'[^0-9]'), '').length < 10) {
          _problem = 'Type the mobile number on your account.';
          return;
        }
        _info = await context.read<CallerController>().requestOtp(_phone.text);
        _codeSent = true;
      });

  Future<void> _verify() => _run(() async {
        if (_code.text.trim().length < 4) {
          _problem = 'Type the code from WhatsApp.';
          return;
        }
        _problem = await context.read<CallerController>().signInWithOtp(_phone.text, _code.text);
      });

  Future<void> _password_() => _run(() async {
        if (_email.text.trim().isEmpty || _password.text.isEmpty) {
          _problem = 'Type your email and password.';
          return;
        }
        _problem = await context.read<CallerController>().signIn(_email.text, _password.text, admin: _admin);
      });

  Widget _button(String text, VoidCallback onTap) => SizedBox(
        height: 52,
        child: FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          onPressed: _busy ? null : onTap,
          child: _busy
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(text, style: const TextStyle(fontSize: 17)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(24), children: [
          const SizedBox(height: 32),
          const Icon(Icons.support_agent, size: 64, color: AppColors.primary),
          const SizedBox(height: 12),
          const Text('Altrobyte Caller',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.primary)),
          const SizedBox(height: 20),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('WhatsApp code'), icon: Icon(Icons.chat)),
              ButtonSegment(value: false, label: Text('Email & password'), icon: Icon(Icons.lock)),
            ],
            selected: {_whatsapp},
            onSelectionChanged: (s) => setState(() {
              _whatsapp = s.first;
              _problem = null;
            }),
          ),
          const SizedBox(height: 20),
          if (_whatsapp) ...[
            const Text('For the institute owner: a code goes to the WhatsApp number on your account.',
                style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Mobile number', border: OutlineInputBorder()),
            ),
            if (_codeSent) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _code,
                keyboardType: TextInputType.number,
                onSubmitted: (_) => _verify(),
                decoration: const InputDecoration(labelText: 'Code from WhatsApp', border: OutlineInputBorder()),
              ),
            ],
            if (_info != null && _codeSent)
              Padding(padding: const EdgeInsets.only(top: 8), child: Text(_info!, style: const TextStyle(color: AppColors.textSecondary))),
          ] else ...[
            const Text('For telecallers: the email and password your admin gave you.',
                style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: true,
              onSubmitted: (_) => _password_(),
              decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _admin,
              onChanged: (v) => setState(() => _admin = v),
              title: const Text('I am the institute admin'),
            ),
          ],
          if (_problem != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(_problem!, style: const TextStyle(color: AppColors.error)),
            ),
          const SizedBox(height: 10),
          if (_whatsapp && !_codeSent) _button('Send code on WhatsApp', _sendCode),
          if (_whatsapp && _codeSent) ...[
            _button('Sign in', _verify),
            TextButton(onPressed: _busy ? null : _sendCode, child: const Text('Send the code again')),
          ],
          if (!_whatsapp) _button('Sign in', _password_),
        ]),
      ),
    );
  }
}
