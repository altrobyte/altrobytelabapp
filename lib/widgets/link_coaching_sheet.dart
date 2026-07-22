import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_colors.dart';
import '../constants/api_constants.dart';

/// Bottom sheet: enter institute code -> WhatsApp OTP -> link a standalone
/// student account to a coaching institute. Shared by the profile screen
/// and the post-registration onboarding screen.
void showLinkCoachingSheet(
  BuildContext context, {
  required String phone,
  required VoidCallback onLinked,
}) {
  final codeCtrl = TextEditingController();
  final otpCtrl = TextEditingController();
  bool otpSent = false;
  bool linking = false;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => StatefulBuilder(
      builder: (ctx, setSheet) => Padding(
        padding: EdgeInsets.only(
            left: 24, right: 24, top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.link_rounded, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Link to Coaching', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
              Text('Enter your institute code to connect', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
            ]),
            const Spacer(),
            IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
          ]),
          const SizedBox(height: 20),
          TextField(
            controller: codeCtrl,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: 'Institute Code',
              hintText: 'e.g. ABCD1234',
              prefixIcon: const Icon(Icons.vpn_key_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          if (otpSent) ...[
            const SizedBox(height: 14),
            TextField(
              controller: otpCtrl,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: InputDecoration(
                labelText: 'OTP (sent to WhatsApp)',
                prefixIcon: const Icon(Icons.sms_rounded),
                counterText: '',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: linking ? null : () async {
                if (codeCtrl.text.trim().isEmpty) return;
                setSheet(() => linking = true);
                if (!otpSent) {
                  try {
                    final res = await http.post(
                      Uri.parse('${ApiConstants.studentRequestOtp()}?institute_code=${Uri.encodeComponent(codeCtrl.text.trim().toUpperCase())}&phone=${Uri.encodeComponent(phone)}'),
                    );
                    if (res.statusCode >= 400) {
                      final body = jsonDecode(res.body);
                      throw body['detail'] ?? 'Failed';
                    }
                    setSheet(() { otpSent = true; linking = false; });
                  } catch (e) {
                    setSheet(() => linking = false);
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error));
                    }
                  }
                } else {
                  try {
                    final prefs = await SharedPreferences.getInstance();
                    final token = prefs.getString('student_token') ?? '';
                    final res = await http.post(
                      Uri.parse(ApiConstants.studentLinkCoaching()),
                      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
                      body: jsonEncode({'institute_code': codeCtrl.text.trim().toUpperCase(), 'otp': otpCtrl.text.trim()}),
                    );
                    final body = jsonDecode(res.body) as Map<String, dynamic>;
                    if (res.statusCode >= 400) throw body['detail'] ?? 'Failed';

                    await prefs.setInt('student_institute_id', body['institute_id'] ?? 0);
                    await prefs.setString('student_institute_name', body['institute_name'] ?? '');
                    await prefs.setBool('student_is_standalone', false);
                    if (ctx.mounted) Navigator.pop(ctx);
                    onLinked();
                  } catch (e) {
                    setSheet(() => linking = false);
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error));
                    }
                  }
                }
              },
              child: linking
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(otpSent ? 'Verify & Link' : 'Send OTP',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      ),
    ),
  );
}
