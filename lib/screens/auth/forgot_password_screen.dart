import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../services/api_service.dart';
import '../../utils/validators.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  int _step = 0; // 0 = email, 1 = otp + new password
  bool _loading = false;
  String _email = '';

  final _emailKey = GlobalKey<FormState>();
  final _resetKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _showPass = false;
  bool _showConfirm = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _otpCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (!_emailKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ApiService.forgotPassword(_emailCtrl.text.trim());
      _email = _emailCtrl.text.trim();
      setState(() => _step = 1);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('OTP sent to your email (check spam folder too)'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (_) {
      // Always show success message to avoid email enumeration
      _email = _emailCtrl.text.trim();
      setState(() => _step = 1);
    }
    setState(() => _loading = false);
  }

  Future<void> _resetPassword() async {
    if (!_resetKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ApiService.resetPassword(_email, _otpCtrl.text.trim(), _passCtrl.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Password reset successfully! Please login.'),
        backgroundColor: Colors.green,
      ));
      context.go('/login');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString()),
        backgroundColor: AppColors.error,
      ));
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => _step == 1 ? setState(() => _step = 0) : context.go('/login'),
        ),
        title: Text(
          _step == 0 ? 'Forgot Password' : 'Enter OTP',
          style: GoogleFonts.poppins(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _step == 0 ? _emailStep(key: const ValueKey(0)) : _otpStep(key: const ValueKey(1)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _emailStep({Key? key}) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.lock_reset_rounded,
              color: AppColors.accent, size: 28),
        ),
        const SizedBox(height: 20),
        Text('Reset your password',
            style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary)),
        const SizedBox(height: 6),
        Text('Enter your registered email and we\'ll send you a 6-digit OTP.',
            style: GoogleFonts.inter(
                color: AppColors.textSecondary, fontSize: 13)),
        const SizedBox(height: 28),
        Form(
          key: _emailKey,
          child: Column(children: [
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Registered Email',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              validator: Validators.email,
              onFieldSubmitted: (_) => _sendOtp(),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _loading ? null : _sendOtp,
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text('Send OTP',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600, fontSize: 15)),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 20),
        Center(
          child: TextButton(
            onPressed: () => context.go('/login'),
            child: Text('← Back to Login',
                style: GoogleFonts.inter(
                    color: AppColors.textSecondary, fontSize: 13)),
          ),
        ),
      ],
    );
  }

  Widget _otpStep({Key? key}) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.mark_email_read_rounded,
              color: Colors.green, size: 28),
        ),
        const SizedBox(height: 20),
        Text('Check your email',
            style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary)),
        const SizedBox(height: 6),
        RichText(
          text: TextSpan(
            style: GoogleFonts.inter(
                color: AppColors.textSecondary, fontSize: 13),
            children: [
              const TextSpan(text: 'OTP sent to '),
              TextSpan(
                  text: _email,
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        const SizedBox(height: 28),
        Form(
          key: _resetKey,
          child: Column(children: [
            TextFormField(
              controller: _otpCtrl,
              keyboardType: TextInputType.number,
              maxLength: 6,
              autofocus: true,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 10),
              decoration: InputDecoration(
                labelText: '6-digit OTP',
                counterText: '',
                prefixIcon: const Icon(Icons.pin_rounded),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              validator: (v) => (v == null || v.length != 6)
                  ? 'Enter the 6-digit OTP'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passCtrl,
              obscureText: !_showPass,
              decoration: InputDecoration(
                labelText: 'New Password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_showPass
                      ? Icons.visibility_off
                      : Icons.visibility),
                  onPressed: () => setState(() => _showPass = !_showPass),
                ),
              ),
              validator: (v) => (v == null || v.length < 6)
                  ? 'Minimum 6 characters'
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _confirmCtrl,
              obscureText: !_showConfirm,
              decoration: InputDecoration(
                labelText: 'Confirm New Password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_showConfirm
                      ? Icons.visibility_off
                      : Icons.visibility),
                  onPressed: () =>
                      setState(() => _showConfirm = !_showConfirm),
                ),
              ),
              validator: (v) => v != _passCtrl.text
                  ? 'Passwords do not match'
                  : null,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _loading ? null : _resetPassword,
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text('Reset Password',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600, fontSize: 15)),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => setState(() => _step = 0),
              child: Text('Didn\'t get OTP? Resend',
                  style: GoogleFonts.inter(
                      color: AppColors.textSecondary, fontSize: 13)),
            ),
          ]),
        ),
      ],
    );
  }
}
