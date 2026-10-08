// The same sign-ins as the web app (same accounts, same endpoints, same AuthProvider):
// student (WhatsApp OTP, with or without an institute code), educator, manager, super admin,
// and staff WhatsApp OTP. Nothing new on the server.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../constants/api_constants.dart';
import '../constants/app_colors.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

enum _Who { student, educator, manager, superAdmin, staffWhatsapp }

const _labels = {
  _Who.student: 'Student',
  _Who.educator: 'Educator',
  _Who.manager: 'Manager',
  _Who.superAdmin: 'Super admin',
  _Who.staffWhatsapp: 'Educator (WhatsApp)',
};

class DesktopLoginScreen extends StatefulWidget {
  const DesktopLoginScreen({super.key});

  @override
  State<DesktopLoginScreen> createState() => _DesktopLoginScreenState();
}

class _DesktopLoginScreenState extends State<DesktopLoginScreen> {
  _Who _who = _Who.student;
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();
  final _phone = TextEditingController();
  final _otp = TextEditingController();
  final _name = TextEditingController();
  bool _show = false;
  bool _otpSent = false;
  bool _askName = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_email, _password, _code, _phone, _otp, _name]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _usesOtp => _who == _Who.student || _who == _Who.staffWhatsapp;

  void _pick(_Who w) {
    context.read<AuthProvider>().error = null;
    setState(() {
      _who = w;
      _otpSent = false;
      _askName = false;
      _error = null;
    });
  }

  Future<void> _submitPassword() async {
    final auth = context.read<AuthProvider>();
    final email = _email.text.trim();
    if (email.isEmpty || _password.text.isEmpty) return;
    setState(() => _error = null);
    switch (_who) {
      case _Who.manager:
        await auth.managerLogin(email, _password.text.trim());
      case _Who.superAdmin:
        await auth.superAdminLogin(email, _password.text);
      default:
        await auth.login(email, _password.text);
    }
  }

  Future<Map<String, dynamic>> _post(String url, Map<String, dynamic>? json) async {
    final res = await http.post(Uri.parse(url), headers: {'Content-Type': 'application/json'}, body: json == null ? null : jsonEncode(json));
    final body = res.body.isEmpty ? <String, dynamic>{} : jsonDecode(res.body);
    if (res.statusCode >= 400) {
      throw _ApiFailure(res.statusCode, body is Map && body['detail'] is String ? body['detail'] as String : 'Something went wrong. Try again.');
    }
    return Map<String, dynamic>.from(body as Map);
  }

  String get _phoneText => _phone.text.trim();
  String get _codeText => _code.text.trim().toUpperCase();

  Future<void> _sendOtp() async {
    if (_phoneText.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_who == _Who.staffWhatsapp) {
        await ApiService.requestWhatsappOtp(_phoneText);
      } else if (_codeText.isEmpty) {
        try {
          await _post('${ApiConstants.baseUrl}/student/standalone/request-otp',
              {'phone': _phoneText, if (_name.text.trim().isNotEmpty) 'name': _name.text.trim()});
        } on _ApiFailure catch (e) {
          if (e.status == 422 || e.status == 404) {
            setState(() {
              _askName = true;
              _error = 'New here! Enter your name and send the OTP again.';
            });
            return;
          }
          rethrow;
        }
      } else {
        await _post(
            '${ApiConstants.baseUrl}/student/request-otp?institute_code=${Uri.encodeComponent(_codeText)}&phone=${Uri.encodeComponent(_phoneText)}',
            null);
      }
      setState(() => _otpSent = true);
    } catch (e) {
      setState(() => _error = e is _ApiFailure ? e.message : 'Could not reach the server. Check your internet.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verifyOtp() async {
    if (_otp.text.trim().isEmpty) return;
    final auth = context.read<AuthProvider>();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_who == _Who.staffWhatsapp) {
        await auth.setFromResponse(await ApiService.verifyWhatsappOtp(_phoneText, _otp.text.trim()));
      } else {
        final Map<String, dynamic> body;
        if (_codeText.isEmpty) {
          body = await _post('${ApiConstants.baseUrl}/student/standalone/verify-otp',
              {'phone': _phoneText, 'otp': _otp.text.trim(), if (_name.text.trim().isNotEmpty) 'name': _name.text.trim()});
        } else {
          body = await _post(
              '${ApiConstants.baseUrl}/student/verify-otp?institute_code=${Uri.encodeComponent(_codeText)}&phone=${Uri.encodeComponent(_phoneText)}&otp=${_otp.text.trim()}',
              null);
        }
        // A learner's session token works as the bearer token for the trainer.
        await auth.setFromResponse({
          'token': body['token'] ?? body['jwt_token'],
          'role': 'student',
          'institute_id': body['institute_id'] ?? 0,
          'name': body['institute_name'] ?? body['name'] ?? '',
        });
      }
    } catch (e) {
      setState(() => _error = e is _ApiFailure ? e.message : e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  InputDecoration _dec(String label, {Widget? suffix, String? hint}) =>
      InputDecoration(labelText: label, hintText: hint, suffixIcon: suffix, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)));

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final loading = _busy || auth.isLoading;
    final error = _error ?? auth.error;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
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
                  Text('Sign in the same way as on the Altrobyte app.', style: GoogleFonts.inter(color: AppColors.textSecondary)),
                  const SizedBox(height: 18),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final w in _Who.values)
                      ChoiceChip(label: Text(_labels[w]!), selected: _who == w, onSelected: loading ? null : (_) => _pick(w)),
                  ]),
                  const SizedBox(height: 18),
                  if (_usesOtp) ..._otpFields(loading) else ..._passwordFields(),
                  if (error != null)
                    Padding(padding: const EdgeInsets.only(top: 12), child: Text(error, style: GoogleFonts.inter(fontSize: 13, color: AppColors.error))),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: loading ? null : (_usesOtp ? (_otpSent ? _verifyOtp : _sendOtp) : _submitPassword),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                      child: Text(loading ? 'Please wait…' : (_usesOtp ? (_otpSent ? 'Verify and sign in' : 'Send OTP on WhatsApp') : 'Sign in')),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _passwordFields() => [
        TextField(controller: _email, autofocus: true, keyboardType: TextInputType.emailAddress, decoration: _dec('Email')),
        const SizedBox(height: 14),
        TextField(
          controller: _password,
          obscureText: !_show,
          onSubmitted: (_) => _submitPassword(),
          decoration: _dec('Password',
              suffix: IconButton(icon: Icon(_show ? Icons.visibility_off_rounded : Icons.visibility_rounded), onPressed: () => setState(() => _show = !_show))),
        ),
      ];

  List<Widget> _otpFields(bool loading) => [
        if (_who == _Who.student) ...[
          TextField(
              controller: _code,
              enabled: !_otpSent,
              textCapitalization: TextCapitalization.characters,
              decoration: _dec('Institute code (leave empty if you have none)')),
          const SizedBox(height: 14),
        ],
        TextField(controller: _phone, enabled: !_otpSent, keyboardType: TextInputType.phone, decoration: _dec('WhatsApp number', hint: '919876543210')),
        if (_askName && !_otpSent) ...[
          const SizedBox(height: 14),
          TextField(controller: _name, decoration: _dec('Your name')),
        ],
        if (_otpSent) ...[
          const SizedBox(height: 14),
          TextField(
              controller: _otp,
              autofocus: true,
              keyboardType: TextInputType.number,
              onSubmitted: (_) => _verifyOtp(),
              decoration: _dec('OTP from WhatsApp')),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
                onPressed: loading
                    ? null
                    : () => setState(() {
                          _otpSent = false;
                          _otp.clear();
                        }),
                child: const Text('Change number / resend')),
          ),
        ],
      ];
}

class _ApiFailure implements Exception {
  _ApiFailure(this.status, this.message);
  final int status;
  final String message;
}
