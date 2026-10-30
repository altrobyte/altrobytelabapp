import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../widgets/auth_sheet.dart';

/// The website's "Log in" (30 Oct 2026, founder: the home page's Log in opened the old coaching-institute login, a
/// worst experience). A learner signs in with their WhatsApp number and lands on their modules; someone already signed
/// in goes straight there.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});
  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  bool _asked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _go());
  }

  Future<void> _go() async {
    final token = (await SharedPreferences.getInstance()).getString('student_token') ?? '';
    if (!mounted) return;
    if (token.isNotEmpty) return context.go('/learn');
    final ok = await showAuthSheet(context, reason: 'to open your learning', phoneOnly: true);
    if (!mounted) return;
    if (ok) return context.go('/learn');
    setState(() => _asked = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F2540),
      body: Center(
        child: _asked
            ? Column(mainAxisSize: MainAxisSize.min, children: [
                FilledButton(onPressed: _go, child: const Text('Log in with WhatsApp')),
                const SizedBox(height: 12),
                TextButton(onPressed: () => context.go('/learn'), child: const Text('Look around first', style: TextStyle(color: Colors.white70))),
              ])
            : const SizedBox.shrink(),
      ),
    );
  }
}
