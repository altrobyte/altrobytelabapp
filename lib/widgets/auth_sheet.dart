// Sign in — WhatsApp number first, Google second.
//
// The order is deliberate. A Google account arrives with no phone number, and
// the number is what every later thing depends on: the login OTP, workshop
// reminders, enrolment receipts, the CRM. A student who signs in with Google
// has to be asked for it again at checkout anyway, so asking once, here, is
// both fewer steps overall and the only path that produces a usable contact.
//
// Google stays because some people bounce at "enter your number", and half a
// record beats none.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_colors.dart';
import '../services/api_service.dart';
import '../services/google_auth_service.dart';

/// Opens the sheet. Returns true if the user ended up signed in.
Future<bool> showAuthSheet(BuildContext context, {String reason = ''}) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AuthSheet(reason: reason),
  );
  return ok == true;
}

class _AuthSheet extends StatefulWidget {
  final String reason;
  const _AuthSheet({required this.reason});

  @override
  State<_AuthSheet> createState() => _AuthSheetState();
}

enum _Step { choose, phone, otp }

class _AuthSheetState extends State<_AuthSheet> {
  _Step _step = _Step.choose;
  final _phone = TextEditingController();
  final _otp = TextEditingController();
  final _name = TextEditingController();
  final _org = TextEditingController();
  /// 'student' or 'working'. Asked only on first registration, because it
  /// changes which batch we would put them in — a working professional cannot
  /// do a weekday intensive — and because a CRM full of unknowns is a CRM
  /// nobody segments.
  String _occupation = 'student';

  bool _busy = false;
  String _error = '';
  /// The server tells us on verify whether this number is new. Asking for a
  /// name up front would be a field most people do not need to fill.
  bool _needsName = false;

  @override
  void dispose() {
    _phone.dispose();
    _otp.dispose();
    _name.dispose();
    _org.dispose();
    super.dispose();
  }

  String get _digits => _phone.text.replaceAll(RegExp(r'\D'), '');

  Future<void> _sendOtp() async {
    if (_digits.length < 10) {
      setState(() => _error = 'Enter a 10-digit mobile number');
      return;
    }
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      await ApiService.standaloneRequestOtp(phone: _digits, name: _name.text.trim());
      if (mounted) {
        setState(() {
          _step = _Step.otp;
          _busy = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e is ApiException ? e.message : 'Could not send the OTP';
      });
    }
  }

  Future<void> _verify() async {
    if (_otp.text.trim().length < 4) {
      setState(() => _error = 'Enter the 6-digit code');
      return;
    }
    if (_needsName && _name.text.trim().isEmpty) {
      setState(() => _error = 'Please add your name');
      return;
    }
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      final res = await ApiService.standaloneVerifyOtp(
        phone: _digits,
        otp: _otp.text.trim(),
        name: _name.text.trim(),
      );
      // Sent after the account exists rather than as part of it: a profile
      // field must never be the reason a sign-in fails.
      if (_needsName) {
        try {
          await ApiService.updateMyProfile({
            'occupation': _occupation,
            if (_occupation == 'student') 'college': _org.text.trim(),
            if (_occupation == 'working') 'company': _org.text.trim(),
          }, token: res['jwt_token'] as String? ?? '');
        } catch (_) {}
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('student_token', res['token'] as String? ?? '');
      await prefs.setString('token', res['jwt_token'] as String? ?? '');
      await prefs.setString('student_name', res['name'] as String? ?? '');
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      final msg = e is ApiException ? e.message : 'Could not verify';
      setState(() {
        _busy = false;
        // The server asks for a name only when the number is new to it.
        if (msg.toLowerCase().contains('naam') || msg.toLowerCase().contains('name')) {
          _needsName = true;
          _error = 'Almost there — add your name to finish signing up.';
        } else {
          _error = msg;
        }
      });
    }
  }

  Future<void> _google() async {
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      await GoogleAuthService.signIn();
      if (!mounted) return;
      Navigator.pop(context, true);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        // Naming the cause. "Did not complete" covered a closed popup, a
        // blocked popup and a domain Firebase has never been told about —
        // three different problems with three different fixes, and only the
        // reader could tell which one they were looking at.
        _error = switch (e.code) {
          'unauthorized-domain' =>
            'This site is not authorised for Google sign-in yet. '
                'Use WhatsApp above, or add this domain in Firebase.',
          'popup-blocked' =>
            'Your browser blocked the popup. Allow popups and try again.',
          'popup-closed-by-user' || 'cancelled-popup-request' =>
            'Sign-in was cancelled.',
          'network-request-failed' =>
            'Network problem. Check your connection and try again.',
          _ => 'Google sign-in did not complete (${e.code}).',
        };
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Google sign-in did not complete. $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(22, 10, 22, 28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 38,
            height: 4,
            margin: const EdgeInsets.only(bottom: 18),
            decoration: BoxDecoration(
                color: Colors.black12, borderRadius: BorderRadius.circular(2)),
          ),
          if (_step != _Step.choose)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                          _step = _step == _Step.otp ? _Step.phone : _Step.choose;
                          _error = '';
                        }),
                icon: const Icon(Icons.arrow_back_rounded, size: 17),
                label: const Text('Back'),
              ),
            ),
          Text(
            switch (_step) {
              _Step.choose => 'Sign in to continue',
              _Step.phone => 'Your WhatsApp number',
              _Step.otp => 'Enter the code',
            },
            style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            switch (_step) {
              _Step.choose => widget.reason.isNotEmpty
                  ? widget.reason
                  : 'So we can save your progress and send your updates.',
              _Step.phone => "We'll send a code to this number on WhatsApp.",
              _Step.otp => 'Sent on WhatsApp to ${_digits.isEmpty ? '' : '+91 $_digits'}.',
            },
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
                fontSize: 12.5, height: 1.45, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          if (_error.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(_error,
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.error)),
            ),
            const SizedBox(height: 14),
          ],
          ...switch (_step) {
            _Step.choose => _chooseStep(),
            _Step.phone => _phoneStep(),
            _Step.otp => _otpStep(),
          },
        ]),
      ),
    );
  }

  List<Widget> _chooseStep() => [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _busy ? null : () => setState(() => _step = _Step.phone),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.chat_rounded, size: 19, color: Colors.white),
            label: Text('Continue with WhatsApp',
                style: GoogleFonts.poppins(
                    fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
          ),
        ),
        const SizedBox(height: 12),
        Row(children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text('or',
                style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.textSecondary)),
          ),
          const Expanded(child: Divider()),
        ]),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _busy ? null : _google,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Text('G',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF4285F4))),
            label: Text('Continue with Google',
                style: GoogleFonts.poppins(fontSize: 14.5, fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Signing in with Google? We will ask for your number later so we can '
          'send your class reminders.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
              fontSize: 10.5, height: 1.4, color: AppColors.textSecondary),
        ),
      ];

  List<Widget> _phoneStep() => [
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          autofocus: true,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
          decoration: InputDecoration(
            prefixText: '+91  ',
            hintText: '10-digit mobile',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(11)),
          ),
          onSubmitted: (_) => _sendOtp(),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _busy ? null : _sendOtp,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _busy
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text('Send code on WhatsApp',
                    style: GoogleFonts.poppins(
                        fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
          ),
        ),
      ];

  List<Widget> _otpStep() => [
        TextField(
          controller: _otp,
          keyboardType: TextInputType.number,
          autofocus: true,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(fontSize: 22, letterSpacing: 8),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          decoration: InputDecoration(
            hintText: '······',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(11)),
          ),
        ),
        if (_needsName) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Your name',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(11)),
            ),
          ),
          const SizedBox(height: 10),
          Row(children: [
            for (final o in const [('student', 'Student'), ('working', 'Working')])
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _occupation = o.$1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(
                        color: _occupation == o.$1
                            ? AppColors.primary.withValues(alpha: 0.1)
                            : Colors.transparent,
                        border: Border.all(
                            color: _occupation == o.$1
                                ? AppColors.primary
                                : Colors.black26),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(o.$2,
                            style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _occupation == o.$1
                                    ? AppColors.primary
                                    : AppColors.textSecondary)),
                      ),
                    ),
                  ),
                ),
              ),
          ]),
          const SizedBox(height: 10),
          TextField(
            controller: _org,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: _occupation == 'working' ? 'Company' : 'College',
              hintText: 'Optional',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(11)),
            ),
          ),
        ],
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _busy ? null : _verify,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _busy
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(_needsName ? 'Create my account' : 'Verify',
                    style: GoogleFonts.poppins(
                        fontSize: 15, fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: _busy ? null : _sendOtp,
          child: Text('Resend code',
              style: GoogleFonts.inter(fontSize: 12.5)),
        ),
      ];
}
