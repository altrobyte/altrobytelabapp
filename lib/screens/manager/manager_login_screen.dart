import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/custom_button_widget.dart';
import '../../utils/validators.dart';

class ManagerLoginScreen extends StatefulWidget {
  const ManagerLoginScreen({super.key});

  @override
  State<ManagerLoginScreen> createState() => _ManagerLoginScreenState();
}

class _ManagerLoginScreenState extends State<ManagerLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final ok = await auth.managerLogin(_emailCtrl.text.trim(), _passCtrl.text.trim());
    if (!mounted) return;
    if (ok) {
      context.go('/dashboard');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(auth.error ?? 'Login failed'),
            backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      backgroundColor: AppColors.sidebar,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 40),
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(32),
                  ),
                  child: const Center(
                    child: Icon(Icons.manage_accounts_rounded,
                        color: Colors.white, size: 32),
                  ),
                ),
                const SizedBox(height: 12),
                Text('Manager Portal',
                    style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold)),
                Text('AltrobyteLab',
                    style:
                        GoogleFonts.inter(color: Colors.white54, fontSize: 14)),
                const SizedBox(height: 24),
                Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Manager Email',
                              prefixIcon: Icon(Icons.email_rounded),
                            ),
                            validator: Validators.email,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _passCtrl,
                            obscureText: _obscure,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_rounded),
                              suffixIcon: IconButton(
                                icon: Icon(_obscure
                                    ? Icons.visibility_off_rounded
                                    : Icons.visibility_rounded),
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                              ),
                            ),
                            validator: (v) =>
                                (v == null || v.isEmpty) ? 'Enter password' : null,
                            onFieldSubmitted: (_) => _login(),
                          ),
                          const SizedBox(height: 20),
                          GradientButton(
                            label: 'Sign In as Manager',
                            icon: Icons.login_rounded,
                            onPressed: _login,
                            loading: auth.isLoading,
                            colors: const [AppColors.primary, AppColors.primaryLight],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.remove('user_role');
                    if (!mounted) return;
                    // ignore: use_build_context_synchronously
                    context.go('/');
                  },
                  child: Text('← Back to role selection',
                      style: GoogleFonts.inter(
                          color: Colors.white38, fontSize: 12)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
