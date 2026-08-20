import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_service.dart';

/// The callback ask, as a form rather than a jump into WhatsApp.
///
/// Opening WhatsApp with a message pre-written is the lower-friction path, and
/// it stays available at the bottom of this sheet. But it only produces a lead
/// if the reader presses send, and none at all on a desktop browser without
/// WhatsApp — everyone who tapped and then hesitated was invisible. Three
/// fields, written down the moment they are submitted, are worth more than a
/// deep link nobody completed.
class CallbackSheet extends StatefulWidget {
  /// Which track they were looking at, so the team opens the call knowing it.
  final String plan;

  /// Which page the request came from.
  final String source;

  /// Fallback for someone who would rather just message us.
  final VoidCallback? onWhatsApp;

  const CallbackSheet({
    super.key,
    this.plan = '',
    this.source = 'roadmap',
    this.onWhatsApp,
  });

  static Future<void> show(
    BuildContext context, {
    String plan = '',
    String source = 'roadmap',
    VoidCallback? onWhatsApp,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CallbackSheet(
        plan: plan,
        source: source,
        onWhatsApp: onWhatsApp,
      ),
    );
  }

  @override
  State<CallbackSheet> createState() => _CallbackSheetState();
}

class _CallbackSheetState extends State<CallbackSheet> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  String _segment = '';
  bool _sending = false;
  bool _done = false;
  String _error = '';

  /// Kept in step with SEGMENTS on the server. An unknown value is stored as
  /// "other" there, so a drift here degrades rather than breaks.
  static const _segments = [
    ('student_prefinal', 'College student — 1st to pre-final year'),
    ('student_final', 'College student — final year'),
    ('working_tech', 'Working professional — technical'),
    ('working_nontech', 'Working professional — non-technical'),
    ('other', 'Something else'),
  ];

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    final digits = _phone.text.replaceAll(RegExp(r'\D'), '');
    if (name.isEmpty) {
      setState(() => _error = 'Tell us your name so we know who to ask for');
      return;
    }
    if (digits.length < 10) {
      setState(() => _error = 'Enter a 10-digit mobile number');
      return;
    }
    setState(() {
      _sending = true;
      _error = '';
    });
    try {
      await ApiService.requestCallback(
        name: name,
        phone: digits,
        email: _email.text.trim(),
        segment: _segment,
        plan: widget.plan,
        source: widget.source,
      );
      if (mounted) setState(() => _done = true);
    } catch (e) {
      if (mounted) {
        setState(() => _error =
            e is ApiException ? e.message : 'Could not send that. $e');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Above the keyboard, or the phone field is the one thing hidden while
      // it is being filled in.
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 22),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: _done ? _thanks() : _form(),
          ),
        ),
      ),
    );
  }

  Widget _grabber() => Center(
        child: Container(
          width: 38,
          height: 4,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFD7DEE8),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );

  Widget _thanks() => Column(mainAxisSize: MainAxisSize.min, children: [
        _grabber(),
        const Icon(Icons.check_circle_rounded,
            size: 46, color: Color(0xFF2E7D32)),
        const SizedBox(height: 12),
        Text('We have your number',
            style: GoogleFonts.poppins(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF0B2450))),
        const SizedBox(height: 7),
        Text(
          'Someone from the team will call you shortly. We have also sent a '
          'note on WhatsApp so you can reply there if it is easier.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
              fontSize: 12.5, height: 1.55, color: const Color(0xFF5A6B82)),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => Navigator.pop(context),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF12326B),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Back to the roadmap',
                style: GoogleFonts.poppins(
                    fontSize: 14, fontWeight: FontWeight.w600)),
          ),
        ),
      ]);

  Widget _form() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _grabber(),
          Text('Request a callback',
              style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0B2450))),
          const SizedBox(height: 5),
          Text(
            widget.plan.isEmpty
                ? 'Two details and we will call you. No payment, no commitment.'
                : 'About the ${widget.plan} track. Two details and we will '
                    'call you — no payment, no commitment.',
            style: GoogleFonts.inter(
                fontSize: 12.5, height: 1.5, color: const Color(0xFF5A6B82)),
          ),
          const SizedBox(height: 18),
          _field(_name, 'Your name', TextInputType.name),
          const SizedBox(height: 11),
          _field(_phone, 'Mobile number', TextInputType.phone,
              formatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              prefix: '+91 '),
          const SizedBox(height: 11),
          _field(_email, 'Email (optional)', TextInputType.emailAddress),
          const SizedBox(height: 16),
          Text('Where are you right now?',
              style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0B2450))),
          const SizedBox(height: 9),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final (key, label) in _segments)
                GestureDetector(
                  onTap: () => setState(() => _segment = key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 11, vertical: 8),
                    decoration: BoxDecoration(
                      color: _segment == key
                          ? const Color(0xFF12326B)
                          : const Color(0xFFF1F4F9),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                          color: _segment == key
                              ? const Color(0xFF12326B)
                              : const Color(0xFFE1E7F0)),
                    ),
                    child: Text(label,
                        style: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: _segment == key
                                ? Colors.white
                                : const Color(0xFF5A6B82))),
                  ),
                ),
            ],
          ),
          if (_error.isNotEmpty) ...[
            const SizedBox(height: 13),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.error_outline_rounded,
                  size: 15, color: Color(0xFFC62828)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(_error,
                    style: GoogleFonts.inter(
                        fontSize: 11.5, color: const Color(0xFFC62828))),
              ),
            ]),
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _sending ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF12326B),
                disabledBackgroundColor: const Color(0xFF12326B)
                    .withValues(alpha: 0.45),
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: _sending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.phone_in_talk_rounded,
                      size: 18, color: Colors.white),
              label: Text(_sending ? 'Sending...' : 'Request a callback',
                  style: GoogleFonts.poppins(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.white)),
            ),
          ),
          if (widget.onWhatsApp != null) ...[
            const SizedBox(height: 9),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  widget.onWhatsApp!();
                },
                icon: const Icon(Icons.chat_rounded,
                    size: 17, color: Color(0xFF25D366)),
                label: Text('Message us on WhatsApp instead',
                    style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF5A6B82))),
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            'We will use your number to call you about this programme. '
            'Reply STOP on WhatsApp any time.',
            style: GoogleFonts.inter(
                fontSize: 10.5, height: 1.45, color: const Color(0xFF9AA5B5)),
          ),
        ],
      );

  Widget _field(
    TextEditingController c,
    String hint,
    TextInputType type, {
    List<TextInputFormatter>? formatters,
    String? prefix,
  }) =>
      TextField(
        controller: c,
        keyboardType: type,
        inputFormatters: formatters,
        style: GoogleFonts.inter(fontSize: 13.5),
        decoration: InputDecoration(
          hintText: hint,
          prefixText: prefix,
          prefixStyle: GoogleFonts.inter(
              fontSize: 13.5, color: const Color(0xFF5A6B82)),
          hintStyle: GoogleFonts.inter(
              fontSize: 13.5, color: const Color(0xFF9AA5B5)),
          filled: true,
          fillColor: const Color(0xFFF7F9FC),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 13, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
            borderSide: const BorderSide(color: Color(0xFFE1E7F0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
            borderSide: const BorderSide(color: Color(0xFFE1E7F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
            borderSide: const BorderSide(color: Color(0xFF12326B), width: 1.4),
          ),
        ),
      );
}
