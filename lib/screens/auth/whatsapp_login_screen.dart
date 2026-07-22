import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class WhatsappLoginScreen extends StatefulWidget {
  const WhatsappLoginScreen({super.key});

  @override
  State<WhatsappLoginScreen> createState() => _WhatsappLoginScreenState();
}

class _WhatsappLoginScreenState extends State<WhatsappLoginScreen> {
  int _step = 0;
  bool _loading = false;
  String _phone = '';

  final _phoneKey = GlobalKey<FormState>();
  final _otpKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (!_phoneKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ApiService.requestWhatsappOtp(_phoneCtrl.text.trim());
      _phone = _phoneCtrl.text.trim();
      setState(() => _step = 1);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('OTP sent to your WhatsApp!'),
          backgroundColor: Color(0xFF25D366),
        ));
      }
    } catch (e) {
      _phone = _phoneCtrl.text.trim();
      setState(() => _step = 1);
    }
    setState(() => _loading = false);
  }

  Future<void> _verifyOtp() async {
    if (!_otpKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final data = await ApiService.verifyWhatsappOtp(_phone, _otpCtrl.text.trim());
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      await auth.setFromResponse(data);
      if (!mounted) return;
      context.go('/dashboard');
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
          onPressed: () => _step == 1
              ? setState(() => _step = 0)
              : context.go('/login'),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _step == 0
                  ? _phoneStep(key: const ValueKey(0))
                  : _otpStep(key: const ValueKey(1)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _phoneStep({Key? key}) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFF25D366).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.chat_rounded,
                color: Color(0xFF25D366), size: 26),
          ),
          const SizedBox(width: 14),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('WhatsApp Login',
                style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
            Text('Get OTP on your WhatsApp',
                style: GoogleFonts.inter(
                    color: AppColors.textSecondary, fontSize: 12)),
          ]),
        ]),
        const SizedBox(height: 32),
        Form(
          key: _phoneKey,
          child: Column(children: [
            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Registered Mobile Number',
                prefixIcon: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  child: Text('+91',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                ),
                hintText: '9876543210',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Enter mobile number';
                if (v.trim().length < 10) return 'Enter valid 10-digit number';
                return null;
              },
              onFieldSubmitted: (_) => _sendOtp(),
            ),
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.info_outline, size: 13, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text('Use the phone number you registered with',
                  style: GoogleFonts.inter(
                      color: AppColors.textSecondary, fontSize: 11)),
            ]),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _loading ? null : _sendOtp,
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded, size: 18),
                label: Text('Send OTP via WhatsApp',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600, fontSize: 15)),
              ),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => context.go('/login'),
              child: Text('Login with email & password instead',
                  style: GoogleFonts.inter(
                      color: AppColors.textSecondary, fontSize: 13)),
            ),
          ]),
        ),
      ],
    );
  }

  Widget _otpStep({Key? key}) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: const Color(0xFF25D366).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.mark_chat_read_rounded,
              color: Color(0xFF25D366), size: 26),
        ),
        const SizedBox(height: 16),
        Text('Enter OTP',
            style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary)),
        const SizedBox(height: 6),
        RichText(
          text: TextSpan(
            style: GoogleFonts.inter(
                color: AppColors.textSecondary, fontSize: 13),
            children: [
              const TextSpan(text: 'OTP sent on WhatsApp to '),
              TextSpan(
                  text: '+91 $_phone',
                  style: const TextStyle(
                      color: Color(0xFF25D366),
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        const SizedBox(height: 28),
        Form(
          key: _otpKey,
          child: Column(children: [
            TextFormField(
              controller: _otpCtrl,
              keyboardType: TextInputType.number,
              maxLength: 6,
              autofocus: true,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 12),
              decoration: InputDecoration(
                counterText: '',
                hintText: '------',
                hintStyle: GoogleFonts.poppins(
                    fontSize: 28,
                    letterSpacing: 12,
                    color: AppColors.textSecondary.withValues(alpha: 0.3)),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(
                    vertical: 18, horizontal: 20),
              ),
              validator: (v) =>
                  (v == null || v.length != 6) ? 'Enter 6-digit OTP' : null,
              onFieldSubmitted: (_) => _verifyOtp(),
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
                onPressed: _loading ? null : _verifyOtp,
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text('Verify & Login',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600, fontSize: 15)),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => setState(() {
                _step = 0;
                _otpCtrl.clear();
              }),
              child: Text("Didn't receive OTP? Resend",
                  style: GoogleFonts.inter(
                      color: AppColors.textSecondary, fontSize: 13)),
            ),
          ]),
        ),
      ],
    );
  }
}
