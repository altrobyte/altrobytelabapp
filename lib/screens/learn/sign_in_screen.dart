import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../widgets/auth_sheet.dart';

/// The website's "Log in" (30 Oct 2026, founder: the home page's Log in opened the old coaching-institute login, a
/// worst experience). A learner signs in with their WhatsApp number and lands on their modules; someone already signed
/// in goes straight there.
class SignInScreen extends StatefulWidget {
  /// Where to go after signing in: a path on this site (the fast /learn page sends its own address).
  final String? next;
  const SignInScreen({super.key, this.next});
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
    if (token.isNotEmpty) return _leave();
    final ok = await showAuthSheet(context, reason: 'to open your learning', phoneOnly: true);
    if (!mounted) return;
    if (ok) return _leave();
    setState(() => _asked = true);
  }

  /// /learn and the lessons are plain pages now, outside the app: a full page load, which reads the saved sign-in.
  void _leave() {
    final next = widget.next ?? '';
    final path = next.startsWith('/') && !next.startsWith('//') ? next : '/learn';
    launchUrl(Uri.base.resolve(path), webOnlyWindowName: '_self');
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
                TextButton(onPressed: () => launchUrl(Uri.base.resolve('/learn'), webOnlyWindowName: '_self'), child: const Text('Look around first', style: TextStyle(color: Colors.white70))),
              ])
            : const SizedBox.shrink(),
      ),
    );
  }
}

/// A page that lives outside the app (a plain HTML page on the site): opening it from inside the app loads it in full.
class FullPage extends StatefulWidget {
  final String path;
  const FullPage(this.path, {super.key});
  @override
  State<FullPage> createState() => _FullPageState();
}

class _FullPageState extends State<FullPage> {
  @override
  void initState() {
    super.initState();
    launchUrl(Uri.base.resolve(widget.path), webOnlyWindowName: '_self');
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(backgroundColor: Color(0xFF0A1220), body: Center(child: CircularProgressIndicator()));
}
