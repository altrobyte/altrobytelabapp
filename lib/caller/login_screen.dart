import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_colors.dart';
import 'caller_controller.dart';

class CallerLoginScreen extends StatefulWidget {
  const CallerLoginScreen({super.key});

  @override
  State<CallerLoginScreen> createState() => _CallerLoginScreenState();
}

class _CallerLoginScreenState extends State<CallerLoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _admin = false, _busy = false;
  String? _problem;

  Future<void> _go() async {
    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _problem = 'Type your email and password.');
      return;
    }
    setState(() {
      _busy = true;
      _problem = null;
    });
    final said = await context.read<CallerController>().signIn(_email.text, _password.text, admin: _admin);
    if (mounted) {
      setState(() {
        _busy = false;
        _problem = said;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(24), children: [
          const SizedBox(height: 40),
          const Icon(Icons.support_agent, size: 64, color: AppColors.primary),
          const SizedBox(height: 12),
          const Text('Altrobyte Caller',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.primary)),
          const Text('Sign in with your team login', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 28),
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
            onSubmitted: (_) => _go(),
            decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _admin,
            onChanged: (v) => setState(() => _admin = v),
            title: const Text('I am the institute admin'),
          ),
          if (_problem != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_problem!, style: const TextStyle(color: AppColors.error)),
            ),
          SizedBox(
            height: 52,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: _busy ? null : _go,
              child: _busy
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Sign in', style: TextStyle(fontSize: 17)),
            ),
          ),
        ]),
      ),
    );
  }
}
