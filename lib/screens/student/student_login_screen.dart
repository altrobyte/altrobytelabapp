import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants/app_colors.dart';
import '../../constants/api_constants.dart';
import '../../providers/brand_provider.dart';

const _teal = Color(0xFF00BFA5);

class StudentLoginScreen extends StatefulWidget {
  const StudentLoginScreen({super.key});

  @override
  State<StudentLoginScreen> createState() => _StudentLoginScreenState();
}

class _StudentLoginScreenState extends State<StudentLoginScreen> {
  int _step = 0; // 0 = code+phone, 1 = OTP
  bool _loading = false;
  String _studentName = '';

  final _formKey = GlobalKey<FormState>();
  final _codeCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final code = context.read<BrandProvider>().instituteCode;
      if (code != null && code.isNotEmpty && _codeCtrl.text.isEmpty) {
        _codeCtrl.text = code;
      }
    });
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  Future<void> _requestOtp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final res = await http.post(
        Uri.parse(
            '${ApiConstants.baseUrl}/student/request-otp'
            '?institute_code=${Uri.encodeComponent(_codeCtrl.text.trim().toUpperCase())}'
            '&phone=${Uri.encodeComponent(_phoneCtrl.text.trim())}'),
        headers: {'Content-Type': 'application/json'},
      );
      final body = jsonDecode(res.body);
      if (res.statusCode >= 400) throw body['detail'] ?? 'Failed';
      _studentName = body['name'] ?? '';
      setState(() => _step = 1);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('OTP sent to your WhatsApp!'),
          backgroundColor: _teal,
        ));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error));
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _verifyOtp() async {
    if (_otpCtrl.text.trim().length != 6) return;
    setState(() => _loading = true);
    final router = GoRouter.of(context);
    try {
      final res = await http.post(
        Uri.parse(
            '${ApiConstants.baseUrl}/student/verify-otp'
            '?institute_code=${Uri.encodeComponent(_codeCtrl.text.trim().toUpperCase())}'
            '&phone=${Uri.encodeComponent(_phoneCtrl.text.trim())}'
            '&otp=${_otpCtrl.text.trim()}'),
        headers: {'Content-Type': 'application/json'},
      );
      final body = jsonDecode(res.body);
      if (res.statusCode >= 400) throw body['detail'] ?? 'Verification failed';
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('student_token', body['token'] ?? '');
      await prefs.setInt('student_user_id', body['student_user_id'] ?? 0);
      await prefs.setInt('student_id', body['student_id'] ?? 0);
      await prefs.setInt('student_institute_id', body['institute_id'] ?? 0);
      await prefs.setString('student_phone', _phoneCtrl.text.trim());
      await prefs.setString('student_name', body['name'] ?? '');
      await prefs.setString('student_institute_name', body['institute_name'] ?? '');
      await prefs.setBool('student_is_standalone', false);
      if (!mounted) return;
      router.go('/student/home');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error));
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.sidebar,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 48),
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                      color: _teal.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20)),
                  child: const Icon(Icons.school_rounded, color: _teal, size: 36),
                ),
                const SizedBox(height: 16),
                Text('Coaching Login',
                    style: GoogleFonts.poppins(
                        color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Login with your coaching institute',
                    style: GoogleFonts.inter(color: Colors.white38, fontSize: 13)),
                const SizedBox(height: 28),

                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _step == 0
                      ? _Step0(
                          key: const ValueKey('step0'),
                          formKey: _formKey,
                          codeCtrl: _codeCtrl,
                          phoneCtrl: _phoneCtrl,
                          loading: _loading,
                          onNext: _requestOtp,
                        )
                      : _Step1(
                          key: const ValueKey('step1'),
                          otpCtrl: _otpCtrl,
                          studentName: _studentName,
                          phone: _phoneCtrl.text.trim(),
                          loading: _loading,
                          onVerify: _verifyOtp,
                          onBack: () => setState(() {
                            _step = 0;
                            _otpCtrl.clear();
                          }),
                        ),
                ),

                const SizedBox(height: 20),
                TextButton(
                  onPressed: () => context.go('/'),
                  child: Text('← Back',
                      style: GoogleFonts.inter(color: Colors.white24, fontSize: 12)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Step0 extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController codeCtrl, phoneCtrl;
  final bool loading;
  final VoidCallback onNext;

  const _Step0({
    super.key, required this.formKey, required this.codeCtrl,
    required this.phoneCtrl, required this.loading, required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Enter your details',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
              const SizedBox(height: 4),
              Text('Your teacher will share the institute code with you',
                  style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 20),
              TextFormField(
                controller: codeCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Institute Code', hintText: 'e.g. EHL001',
                  prefixIcon: Icon(Icons.vpn_key_rounded),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter institute code' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Your Phone Number', hintText: '9876543210',
                  prefixIcon: Icon(Icons.phone_rounded), prefixText: '+91 ',
                ),
                validator: (v) => (v == null || v.trim().length < 10) ? 'Enter valid 10-digit number' : null,
                onFieldSubmitted: (_) => onNext(),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _teal, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: loading ? null : onNext,
                  icon: loading
                      ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_rounded, size: 18),
                  label: Text('Send OTP via WhatsApp',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Step1 extends StatelessWidget {
  final TextEditingController otpCtrl;
  final String studentName, phone;
  final bool loading;
  final VoidCallback onVerify, onBack;

  const _Step1({
    super.key, required this.otpCtrl, required this.studentName,
    required this.phone, required this.loading,
    required this.onVerify, required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back_rounded),
                  padding: EdgeInsets.zero, constraints: const BoxConstraints()),
              const SizedBox(width: 8),
              Text('Enter OTP',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
            ]),
            const SizedBox(height: 12),
            if (studentName.isNotEmpty)
              Text('Welcome, $studentName!',
                  style: GoogleFonts.poppins(color: _teal, fontWeight: FontWeight.w500, fontSize: 14)),
            const SizedBox(height: 4),
            Text('OTP sent to +91 $phone',
                style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 20),
            TextFormField(
              controller: otpCtrl,
              keyboardType: TextInputType.number,
              maxLength: 6, autofocus: true, textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 12),
              decoration: InputDecoration(
                counterText: '',
                hintText: '------',
                hintStyle: GoogleFonts.poppins(fontSize: 28, letterSpacing: 12,
                    color: AppColors.textSecondary.withValues(alpha: 0.3)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
              ),
              onFieldSubmitted: (_) => onVerify(),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _teal, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: loading ? null : onVerify,
                child: loading
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text('Verify & Login',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: onBack,
                child: Text("Didn't receive OTP? Go back & resend",
                    style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
