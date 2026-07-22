import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/custom_button_widget.dart';
import '../../utils/validators.dart';

class SuperAdminLoginScreen extends StatefulWidget {
  const SuperAdminLoginScreen({super.key});

  @override
  State<SuperAdminLoginScreen> createState() => _SuperAdminLoginScreenState();
}

class _SuperAdminLoginScreenState extends State<SuperAdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  bool _obscure = true;
  bool _otpMode = false;
  int _otpStep = 0; // 0 = request, 1 = verify
  bool _loading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final ok = await auth.superAdminLogin(
        _emailCtrl.text.trim(), _passCtrl.text.trim());
    if (!mounted) return;
    if (ok) {
      context.go('/super/dashboard');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(auth.error ?? 'Login failed'),
            backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _sendOtp() async {
    setState(() => _loading = true);
    try {
      await ApiService.superRequestOtp();
      setState(() => _otpStep = 1);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('OTP sent to your WhatsApp!'),
          backgroundColor: Color(0xFF25D366),
        ));
      }
    } catch (_) {
      setState(() => _otpStep = 1);
    }
    setState(() => _loading = false);
  }

  Future<void> _verifyOtp() async {
    if (_otpCtrl.text.trim().length != 6) return;
    setState(() => _loading = true);
    try {
      final data = await ApiService.superVerifyOtp(_otpCtrl.text.trim());
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      await auth.setFromResponse(data);
      if (!mounted) return;
      context.go('/super/dashboard');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString()),
        backgroundColor: AppColors.error,
      ));
    }
    setState(() => _loading = false);
  }

  Widget _buildPasswordForm(auth) {
    return Form(
      key: _formKey,
      child: Column(children: [
        TextFormField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(color: Colors.white),
          decoration: _darkInput('Super Admin Email', Icons.email_rounded),
          validator: Validators.email,
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _passCtrl,
          obscureText: _obscure,
          style: const TextStyle(color: Colors.white),
          decoration: _darkInput('Password', Icons.lock_rounded).copyWith(
            suffixIcon: IconButton(
              icon: Icon(_obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  color: Colors.white38),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
          validator: (v) => (v == null || v.isEmpty) ? 'Enter password' : null,
          onFieldSubmitted: (_) => _login(),
        ),
        const SizedBox(height: 20),
        GradientButton(
          label: 'Access Platform',
          icon: Icons.shield_rounded,
          onPressed: _login,
          loading: auth.isLoading,
          colors: const [Color(0xFFFF6B35), Color(0xFFFF8C42)],
        ),
      ]),
    );
  }

  Widget _buildOtpForm() {
    if (_otpStep == 0) {
      return Column(children: [
        const Icon(Icons.chat_rounded, color: Color(0xFF25D366), size: 36),
        const SizedBox(height: 12),
        Text('WhatsApp OTP Login',
            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
        const SizedBox(height: 6),
        Text('OTP will be sent to your registered number',
            style: GoogleFonts.inter(color: Colors.white38, fontSize: 12)),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _loading ? null : _sendOtp,
            icon: _loading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send_rounded, size: 18),
            label: Text('Send OTP', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ),
      ]);
    }
    return Column(children: [
      const Icon(Icons.mark_chat_read_rounded, color: Color(0xFF25D366), size: 36),
      const SizedBox(height: 12),
      Text('Enter OTP', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
      const SizedBox(height: 6),
      Text('Sent to your registered number', style: GoogleFonts.inter(color: Colors.white38, fontSize: 12)),
      const SizedBox(height: 20),
      TextFormField(
        controller: _otpCtrl,
        keyboardType: TextInputType.number,
        maxLength: 6,
        autofocus: true,
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 12, color: Colors.white),
        decoration: InputDecoration(
          counterText: '',
          hintText: '------',
          hintStyle: GoogleFonts.poppins(fontSize: 28, letterSpacing: 12, color: Colors.white24),
          filled: true,
          fillColor: const Color(0xFF0D0D1A),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15))),
          contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
        ),
        onFieldSubmitted: (_) => _verifyOtp(),
      ),
      const SizedBox(height: 16),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF6B35),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: _loading ? null : _verifyOtp,
          child: _loading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text('Verify & Login', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        ),
      ),
      const SizedBox(height: 8),
      TextButton(
        onPressed: () => setState(() { _otpStep = 0; _otpCtrl.clear(); }),
        child: Text("Resend OTP", style: GoogleFonts.inter(color: Colors.white38, fontSize: 13)),
      ),
    ]);
  }

  InputDecoration _darkInput(String label, IconData icon) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: Colors.white54),
    prefixIcon: Icon(icon, color: Colors.white38),
    filled: true,
    fillColor: const Color(0xFF0D0D1A),
    enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15))),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFFF6B35))),
    errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.red)),
    focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.red)),
  );

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 40),
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(36),
                    boxShadow: [
                      BoxShadow(
                          color: const Color(0xFFFF6B35).withValues(alpha: 0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 8)),
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.shield_rounded, color: Colors.white, size: 36),
                  ),
                ),
                const SizedBox(height: 14),
                Text('Super Admin',
                    style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold)),
                Text('Platform Control Panel',
                    style: GoogleFonts.inter(
                        color: Colors.white38, fontSize: 13)),
                const SizedBox(height: 28),
                Card(
                  color: const Color(0xFF1A1A2E),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: _otpMode ? _buildOtpForm() : _buildPasswordForm(auth),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () => setState(() {
                    _otpMode = !_otpMode;
                    _otpStep = 0;
                    _otpCtrl.clear();
                  }),
                  icon: Icon(
                    _otpMode ? Icons.lock_rounded : Icons.chat_rounded,
                    size: 15,
                    color: _otpMode ? Colors.white38 : const Color(0xFF25D366),
                  ),
                  label: Text(
                    _otpMode ? 'Login with password instead' : 'Login with WhatsApp OTP',
                    style: GoogleFonts.inter(
                        color: _otpMode ? Colors.white38 : const Color(0xFF25D366),
                        fontSize: 13),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.remove('user_role');
                    if (!mounted) return;
                    // ignore: use_build_context_synchronously
                    context.go('/');
                  },
                  child: Text('← Back',
                      style: GoogleFonts.inter(
                          color: Colors.white24, fontSize: 12)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
