import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_service.dart';

/// A page whose whole job is to turn a link into a time in the diary.
///
/// Shared directly, like the roadmap. Pick a day, pick a time, leave a number
/// — that is the entire form. Anything else asked here is a reason to close
/// the tab, and we can ask it on the call.
class BookCallScreen extends StatefulWidget {
  const BookCallScreen({super.key});

  @override
  State<BookCallScreen> createState() => _BookCallScreenState();
}

class _BookCallScreenState extends State<BookCallScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _topic = TextEditingController();

  List<dynamic> _days = [];
  int _day = 0;
  String _slot = '';
  bool _loading = true;
  bool _sending = false;
  String _error = '';
  Map<String, dynamic>? _booked;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _topic.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final r = await ApiService.getBookingSlots();
      if (!mounted) return;
      setState(() {
        _days = (r['days'] as List?) ?? [];
        _day = 0;
        _slot = '';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : 'Could not load the times. $e';
        _loading = false;
      });
    }
  }

  Future<void> _book() async {
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
    if (_slot.isEmpty) {
      setState(() => _error = 'Pick a time');
      return;
    }
    setState(() {
      _sending = true;
      _error = '';
    });
    try {
      final r = await ApiService.bookCall(
        name: name,
        phone: digits,
        slotUtc: _slot,
        topic: _topic.text.trim(),
      );
      if (mounted) setState(() => _booked = r);
    } catch (e) {
      if (!mounted) return;
      final msg = e is ApiException ? e.message : 'Could not book that. $e';
      setState(() => _error = msg);
      // Somebody else took it while this form was open — the list on screen
      // is now wrong, so refresh it rather than let them retry into the same
      // rejection.
      if (msg.toLowerCase().contains('slot')) _load();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width > 700;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: wide ? 24 : 16, vertical: 24),
              child: _booked != null ? _done() : _form(),
            ),
          ),
        ),
      ),
    );
  }

  // ── Booked ───────────────────────────────────────────────────────────────
  Widget _done() {
    final b = _booked!;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _card,
      child: Column(children: [
        const Icon(Icons.event_available_rounded, size: 50, color: Color(0xFF2E7D32)),
        const SizedBox(height: 14),
        Text('Your call is booked',
            style: GoogleFonts.poppins(
                fontSize: 19, fontWeight: FontWeight.w600, color: const Color(0xFF0B2450))),
        const SizedBox(height: 8),
        Text('${b['when']}',
            style: GoogleFonts.poppins(
                fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xFF12326B))),
        const SizedBox(height: 10),
        Text(
          'We will ring the number you gave us. A confirmation is on its way '
          'over WhatsApp — reply there if you need to move it.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
              fontSize: 12.5, height: 1.55, color: const Color(0xFF5A6B82)),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => launchUrl(
                Uri.parse('${b['google_calendar_url']}'),
                mode: LaunchMode.externalApplication),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF12326B),
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.calendar_month_rounded, size: 18, color: Colors.white),
            label: Text('Add to Google Calendar',
                style: GoogleFonts.poppins(
                    fontSize: 14.5, fontWeight: FontWeight.w600, color: Colors.white)),
          ),
        ),
        const SizedBox(height: 9),
        TextButton.icon(
          onPressed: () => launchUrl(
              Uri.parse('${ApiService.base}${b['ics_url']}'),
              mode: LaunchMode.externalApplication),
          icon: const Icon(Icons.download_rounded, size: 16),
          label: Text('Any other calendar (.ics)',
              style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF5A6B82))),
        ),
      ]),
    );
  }

  // ── Form ─────────────────────────────────────────────────────────────────
  Widget _form() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Book a call',
            style: GoogleFonts.poppins(
                fontSize: 24, fontWeight: FontWeight.w700, color: const Color(0xFF0B2450))),
        const SizedBox(height: 6),
        Text(
          'Pick a time that suits you and we will call. No payment, no '
          'commitment — bring your questions about the programme, the '
          'roadmap, or whether it fits what you are trying to build.',
          style: GoogleFonts.inter(
              fontSize: 13, height: 1.6, color: const Color(0xFF5A6B82)),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: _card,
          child: _loading
              ? const Padding(
                  padding: EdgeInsets.all(30),
                  child: Center(child: CircularProgressIndicator()))
              : _days.isEmpty
                  ? _noSlots()
                  : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _label('PICK A DAY'),
                      const SizedBox(height: 9),
                      SizedBox(
                        height: 62,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _days.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (_, i) => _dayChip(i),
                        ),
                      ),
                      const SizedBox(height: 18),
                      _label('PICK A TIME  ·  IST'),
                      const SizedBox(height: 9),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        for (final s in (_days[_day]['slots'] as List? ?? []))
                          _slotChip(s as Map<String, dynamic>),
                      ]),
                      const SizedBox(height: 20),
                      _label('YOUR DETAILS'),
                      const SizedBox(height: 9),
                      _field(_name, 'Your name', TextInputType.name),
                      const SizedBox(height: 10),
                      _field(_phone, 'Mobile number', TextInputType.phone,
                          formatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10),
                          ],
                          prefix: '+91 '),
                      const SizedBox(height: 10),
                      _field(_topic, 'What would you like to talk about? (optional)',
                          TextInputType.text),
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
                          onPressed: _sending ? null : _book,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF12326B),
                            disabledBackgroundColor:
                                const Color(0xFF12326B).withValues(alpha: 0.45),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: _sending
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.event_rounded,
                                  size: 18, color: Colors.white),
                          label: Text(_sending ? 'Booking...' : 'Book this call',
                              style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white)),
                        ),
                      ),
                    ]),
        ),
        const SizedBox(height: 14),
        Center(
          child: Text('Altrobyte Lab  ·  Indore',
              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF9AA5B5))),
        ),
      ]);

  Widget _noSlots() => Column(children: [
        const Icon(Icons.event_busy_rounded, size: 40, color: Color(0xFF9AA5B5)),
        const SizedBox(height: 12),
        Text(_error.isEmpty ? 'No times open right now' : _error,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
                fontSize: 15, fontWeight: FontWeight.w600, color: const Color(0xFF0B2450))),
        const SizedBox(height: 6),
        Text('Try again shortly, or message us on WhatsApp and we will find a time.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
                fontSize: 12.5, height: 1.5, color: const Color(0xFF5A6B82))),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh_rounded, size: 17),
          label: Text('Try again', style: GoogleFonts.inter(fontSize: 13)),
        ),
      ]);

  Widget _dayChip(int i) {
    final d = _days[i] as Map<String, dynamic>;
    final on = i == _day;
    final count = (d['slots'] as List?)?.length ?? 0;
    return GestureDetector(
      // Changing day clears the time: a slot from Tuesday selected while
      // Thursday is showing is a booking nobody meant to make.
      onTap: () => setState(() {
        _day = i;
        _slot = '';
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: 86,
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: on ? const Color(0xFF12326B) : const Color(0xFFF1F4F9),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
              color: on ? const Color(0xFF12326B) : const Color(0xFFE1E7F0)),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('${d['label']}',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: on ? Colors.white : const Color(0xFF0B2450))),
          const SizedBox(height: 2),
          Text('$count free',
              style: GoogleFonts.inter(
                  fontSize: 10,
                  color: on
                      ? Colors.white.withValues(alpha: 0.75)
                      : const Color(0xFF9AA5B5))),
        ]),
      ),
    );
  }

  Widget _slotChip(Map<String, dynamic> s) {
    final v = '${s['start_utc']}';
    final on = v == _slot;
    return GestureDetector(
      onTap: () => setState(() => _slot = v),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: on ? const Color(0xFF12326B) : const Color(0xFFF1F4F9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: on ? const Color(0xFF12326B) : const Color(0xFFE1E7F0)),
        ),
        child: Text('${s['label']}',
            style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: on ? Colors.white : const Color(0xFF5A6B82))),
      ),
    );
  }

  Widget _label(String t) => Text(t,
      style: GoogleFonts.inter(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: const Color(0xFF9AA5B5)));

  Widget _field(TextEditingController c, String hint, TextInputType type,
          {List<TextInputFormatter>? formatters, String? prefix}) =>
      TextField(
        controller: c,
        keyboardType: type,
        inputFormatters: formatters,
        style: GoogleFonts.inter(fontSize: 13.5),
        decoration: InputDecoration(
          hintText: hint,
          prefixText: prefix,
          prefixStyle:
              GoogleFonts.inter(fontSize: 13.5, color: const Color(0xFF5A6B82)),
          hintStyle:
              GoogleFonts.inter(fontSize: 13.5, color: const Color(0xFF9AA5B5)),
          filled: true,
          fillColor: const Color(0xFFF7F9FC),
          contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 14),
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

  static final _card = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 18,
          offset: const Offset(0, 4)),
    ],
  );
}
