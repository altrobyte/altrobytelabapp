import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_colors.dart';
import '../constants/api_constants.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});
  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  int _step = 0; // 0 = details, 1 = OTP
  bool _loading = false;
  int _logoTaps = 0;
  bool _showSuperAdminLink = false;

  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _collegeCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  bool _showMoreDetails = false;

  bool get _isRegisterTab => _tabCtrl.index == 1;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) {
        setState(() {
          _step = 0;
          _otpCtrl.clear();
        });
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoNavigate());
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    _collegeCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _autoNavigate() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    if (prefs.getString('student_token') != null) {
      context.go('/student/home');
    }
  }

  // A slow-but-connected phone (full signal bars, poor real throughput) can
  // blow past the request timeout, surfacing as a raw "TimeoutException
  // after 0:00:20...: Future not completed" — meaningless to a student.
  String _friendlyError(Object e) {
    if (e is TimeoutException) {
      return 'Your network seems slow right now. Please check your connection and try again.';
    }
    return e.toString();
  }

  void _onLogoTap() {
    _logoTaps++;
    if (_logoTaps >= 7) {
      setState(() => _showSuperAdminLink = true);
    }
  }

  Future<void> _requestOtp() async {
    if (_isRegisterTab && !_formKey.currentState!.validate()) return;
    if (!_isRegisterTab && _phoneCtrl.text.trim().length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Enter a valid 10-digit number'), backgroundColor: AppColors.error));
      return;
    }
    setState(() => _loading = true);
    try {
      final res = await http.post(
        Uri.parse(ApiConstants.standaloneRequestOtp()),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': _phoneCtrl.text.trim(),
          'name': _nameCtrl.text.trim(),
        }),
      ).timeout(const Duration(seconds: 20));
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode >= 400) throw data['detail'] ?? 'Failed';
      setState(() => _step = 1);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('OTP sent to your WhatsApp!'),
          backgroundColor: AppColors.success,
        ));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_friendlyError(e)), backgroundColor: AppColors.error));
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _verifyOtp() async {
    if (_otpCtrl.text.trim().length != 6) return;
    setState(() => _loading = true);
    final router = GoRouter.of(context);
    try {
      final res = await http.post(
        Uri.parse(ApiConstants.standaloneVerifyOtp()),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': _phoneCtrl.text.trim(),
          'otp': _otpCtrl.text.trim(),
          'name': _nameCtrl.text.trim(),
          'college': _collegeCtrl.text.trim(),
          'email': _emailCtrl.text.trim(),
          'address': _addressCtrl.text.trim(),
        }),
      ).timeout(const Duration(seconds: 20));
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 422 && !_isRegisterTab) {
        // Number not registered yet — nudge to Register tab, keep phone filled.
        if (!mounted) return;
        setState(() {
          _step = 0;
          _otpCtrl.clear();
          _tabCtrl.index = 1;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Ye number registered nahi hai. Register kar lo — naam bhi daal do.'),
          backgroundColor: AppColors.warning,
        ));
        return;
      }
      if (res.statusCode >= 400) throw data['detail'] ?? 'Failed';

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('student_token', data['token'] ?? '');
      await prefs.setInt('student_user_id', data['student_user_id'] ?? 0);
      await prefs.setInt('student_id', data['student_id'] ?? 0);
      await prefs.setInt('student_institute_id', data['institute_id'] ?? 0);
      await prefs.setString('student_phone', _phoneCtrl.text.trim());
      await prefs.setString('student_name', data['name'] ?? '');
      await prefs.setString('student_institute_name', data['institute_name'] ?? '');
      await prefs.setBool('student_is_standalone', data['is_standalone'] == true);
      if (!mounted) return;

      final isNew = data['is_new_registration'] == true;
      router.go(isNew ? '/student/onboarding' : '/student/home');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_friendlyError(e)), backgroundColor: AppColors.error));
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.sidebar,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
            child: Column(
              children: [
                const SizedBox(height: 24),
                // Logo — hidden tap counter
                GestureDetector(
                  onTap: _onLogoTap,
                  child: Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(color: AppColors.accent.withValues(alpha: 0.35),
                            blurRadius: 20, offset: const Offset(0, 6))
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: Image.asset('assets/images/logo.png', fit: BoxFit.cover),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('AltrobyteLab',
                    style: GoogleFonts.poppins(
                        color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                Text('Exam prep with AI',
                    style: GoogleFonts.inter(color: Colors.white38, fontSize: 13)),
                const SizedBox(height: 32),

                // Card
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 0,
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      TabBar(
                        controller: _tabCtrl,
                        labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
                        unselectedLabelStyle: GoogleFonts.poppins(fontSize: 14),
                        indicatorColor: AppColors.accent,
                        labelColor: AppColors.accent,
                        unselectedLabelColor: AppColors.textSecondary,
                        tabs: const [
                          Tab(text: 'Login'),
                          Tab(text: 'Register'),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: _step == 0 ? _buildDetailsStep() : _buildOtpStep(),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
                Text('5 free AI tests/month • No coaching required',
                    style: GoogleFonts.inter(color: Colors.white30, fontSize: 11)),

                const SizedBox(height: 32),
                if (_showSuperAdminLink) ...[
                  TextButton(
                    onPressed: () => context.go('/super/login'),
                    child: Text('Super Admin',
                        style: GoogleFonts.inter(
                            color: Colors.white24, fontSize: 11,
                            decoration: TextDecoration.underline)),
                  ),
                ],
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailsStep() {
    return Form(
      key: _formKey,
      child: Column(
        key: ValueKey('details_$_isRegisterTab'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.whatsapp.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.chat_rounded, color: AppColors.whatsapp, size: 20),
            ),
            const SizedBox(width: 10),
            Text(_isRegisterTab ? 'Create your account' : 'Login with WhatsApp',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
          ]),
          const SizedBox(height: 20),
          if (_isRegisterTab) ...[
            _field(_nameCtrl, 'Your Name', Icons.badge_rounded,
                validator: (v) => (v == null || v.trim().length < 2) ? 'Enter name' : null,
                textCapitalization: TextCapitalization.words),
            const SizedBox(height: 14),
          ],
          _field(_phoneCtrl, 'WhatsApp Number', Icons.phone_rounded,
              keyboardType: TextInputType.phone, prefixText: '+91 ',
              hintText: '9876543210',
              validator: (v) => (v == null || v.trim().length < 10) ? 'Enter 10-digit number' : null),
          if (_isRegisterTab) ...[
            const SizedBox(height: 4),
            InkWell(
              onTap: () => setState(() => _showMoreDetails = !_showMoreDetails),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(children: [
                  Icon(_showMoreDetails ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                      size: 18, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text('More details (optional)',
                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                ]),
              ),
            ),
            if (_showMoreDetails) ...[
              _field(_collegeCtrl, 'College / Company', Icons.school_rounded),
              const SizedBox(height: 12),
              _field(_emailCtrl, 'Email', Icons.email_rounded,
                  keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 12),
              _field(_addressCtrl, 'Address', Icons.location_on_rounded),
              const SizedBox(height: 8),
            ],
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _loading ? null : _requestOtp,
              icon: _loading
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text('Send OTP via WhatsApp',
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtpStep() {
    return Column(
      key: const ValueKey('otp_step'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          IconButton(
            onPressed: () => setState(() {
              _step = 0;
              _otpCtrl.clear();
            }),
            icon: const Icon(Icons.arrow_back_rounded),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          Text('Enter OTP', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
        ]),
        const SizedBox(height: 8),
        Text('Sent to +91 ${_phoneCtrl.text.trim()} on WhatsApp',
            style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 20),
        TextFormField(
          controller: _otpCtrl,
          keyboardType: TextInputType.number,
          maxLength: 6, autofocus: true, textAlign: TextAlign.center,
          style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: 10),
          decoration: InputDecoration(
            counterText: '',
            hintText: '------',
            hintStyle: GoogleFonts.poppins(fontSize: 26, letterSpacing: 10,
                color: AppColors.textSecondary.withValues(alpha: 0.3)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          ),
          onFieldSubmitted: (_) => _verifyOtp(),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _loading ? null : _verifyOtp,
            child: _loading
                ? const SizedBox(width: 22, height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(_isRegisterTab ? 'Verify & Create Account' : 'Verify & Login',
                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: _loading ? null : _requestOtp,
            child: Text("Didn't get OTP? Resend",
                style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12)),
          ),
        ),
      ],
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
    String? prefixText,
    String? hintText,
    String? Function(String?)? validator,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        prefixIcon: Icon(icon, size: 20),
        prefixText: prefixText,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      validator: validator,
    );
  }
}
