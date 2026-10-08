import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../providers/auth_provider.dart';

class DesktopLoginScreen extends StatefulWidget {
  const DesktopLoginScreen({super.key});

  @override
  State<DesktopLoginScreen> createState() => _DesktopLoginScreenState();
}

class _DesktopLoginScreenState extends State<DesktopLoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _show = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final auth = context.read<AuthProvider>();
    if (_email.text.trim().isEmpty || _password.text.isEmpty) return;
    await auth.login(_email.text.trim(), _password.text);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.black.withValues(alpha: 0.08))),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.smart_toy_rounded, color: AppColors.primary, size: 30),
                  const SizedBox(width: 10),
                  Text('Altrobyte AI Trainer', style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 6),
                Text('Sign in with your Altrobyte account.', style: GoogleFonts.inter(color: AppColors.textSecondary)),
                const SizedBox(height: 22),
                TextField(
                  controller: _email,
                  autofocus: true,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(labelText: 'Email', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _password,
                  obscureText: !_show,
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    suffixIcon: IconButton(icon: Icon(_show ? Icons.visibility_off_rounded : Icons.visibility_rounded), onPressed: () => setState(() => _show = !_show)),
                  ),
                ),
                if (auth.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(auth.error!, style: GoogleFonts.inter(fontSize: 13, color: AppColors.error)),
                  ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: auth.isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                    child: Text(auth.isLoading ? 'Signing in…' : 'Sign in'),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
