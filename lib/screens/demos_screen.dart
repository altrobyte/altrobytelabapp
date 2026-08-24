import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_service.dart';

/// Upcoming free demo classes, and a seat in one.
///
/// Shareable like /book and /roadmap. No account, no payment — a name and a
/// number is the whole price of admission, because the point of a free demo
/// is meeting people who have never heard of us, and a signup wall meets
/// nobody.
class DemosScreen extends StatefulWidget {
  const DemosScreen({super.key});

  @override
  State<DemosScreen> createState() => _DemosScreenState();
}

class _DemosScreenState extends State<DemosScreen> {
  List<dynamic> _demos = [];

  /// Demo ids this browser has already taken a seat in.
  ///
  /// There is no account here on purpose, so the only place this can live is
  /// the device. Offering "Book a free seat" to somebody who booked an hour
  /// ago reads as though their booking did not register, and the second
  /// attempt only ever comes back as "you already have a seat" anyway.
  Set<int> _booked = {};
  bool _loading = true;
  String _error = '';

  static const _bookedKey = 'booked_demo_ids';

  Future<void> _rememberBooked(int id) async {
    setState(() => _booked = {..._booked, id});
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
          _bookedKey, _booked.map((e) => '$e').toList());
    } catch (_) {
      // Private windows and cleared site data both land here. The seat is
      // safe on the server either way; only this shortcut is lost.
    }
  }

  Future<void> _loadBooked() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_bookedKey) ?? [];
      final ids = raw.map(int.tryParse).whereType<int>().toSet();
      if (mounted) setState(() => _booked = ids);
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _loadBooked();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final r = await ApiService.getDemos();
      if (mounted) {
        setState(() {
          _demos = r;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e is ApiException ? e.message : 'Could not load the demos. $e';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
                children: [
                  Text('Free demo classes',
                      style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0B2450))),
                  const SizedBox(height: 6),
                  Text(
                    'Sit in on a real session before you decide anything. No '
                    'payment, no account — just turn up and see how we teach.',
                    style: GoogleFonts.inter(
                        fontSize: 13, height: 1.6, color: const Color(0xFF5A6B82)),
                  ),
                  const SizedBox(height: 20),
                  if (_loading)
                    const Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(child: CircularProgressIndicator()))
                  else if (_error.isNotEmpty)
                    _empty(Icons.error_outline_rounded, _error, retry: true)
                  else if (_demos.isEmpty)
                    _empty(Icons.event_busy_rounded,
                        'No demo classes scheduled right now. Check back in a '
                        'few days, or message us and we will tell you when the '
                        'next one opens.')
                  else
                    for (final d in _demos)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _DemoCard(
                          demo: d as Map<String, dynamic>,
                          alreadyBooked:
                              _booked.contains((d as Map)['id'] as int),
                          onBooked: (id) async {
                            await _rememberBooked(id);
                            await _load();
                          },
                        ),
                      ),
                  const SizedBox(height: 10),
                  Center(
                    child: Text('Altrobyte Lab  ·  Indore',
                        style: GoogleFonts.inter(
                            fontSize: 11, color: const Color(0xFF9AA5B5))),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _empty(IconData icon, String msg, {bool retry = false}) => Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(children: [
          Icon(icon, size: 40, color: const Color(0xFF9AA5B5)),
          const SizedBox(height: 12),
          Text(msg,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 13, height: 1.55, color: const Color(0xFF5A6B82))),
          if (retry) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded, size: 17),
              label: Text('Try again', style: GoogleFonts.inter(fontSize: 13)),
            ),
          ],
        ]),
      );
}

class _DemoCard extends StatelessWidget {
  final Map<String, dynamic> demo;
  final bool alreadyBooked;
  final Future<void> Function(int demoId) onBooked;
  const _DemoCard({
    required this.demo,
    required this.onBooked,
    this.alreadyBooked = false,
  });

  @override
  Widget build(BuildContext context) {
    final seats = demo['seats_left'] as int?;
    final full = demo['is_full'] == true;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6EBF3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text('${demo['when'] ?? ''}',
                style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF12326B))),
          ),
          // Only shown when there is a real number behind it. "Filling fast"
          // with no cap set is the kind of thing people check.
          if (full)
            _tag('Full', const Color(0xFFC62828))
          else if (seats != null && seats <= 5)
            _tag('$seats seats left', const Color(0xFFC62828))
          else if (seats != null)
            _tag('$seats seats left', const Color(0xFF2E7D32)),
        ]),
        const SizedBox(height: 7),
        Text('${demo['title'] ?? ''}',
            style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                height: 1.3,
                color: const Color(0xFF0B2450))),
        if ('${demo['host_name'] ?? ''}'.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text('with ${demo['host_name']}',
              style: GoogleFonts.inter(
                  fontSize: 12, color: const Color(0xFF5A6B82))),
        ],
        const SizedBox(height: 11),
        Wrap(spacing: 7, runSpacing: 7, children: [
          _chip(Icons.timer_outlined, '${demo['duration_minutes'] ?? 60} min'),
          if ('${demo['platform'] ?? ''}'.isNotEmpty)
            _chip(Icons.videocam_outlined, '${demo['platform']}'),
          _chip(Icons.currency_rupee_rounded, 'Free'),
        ]),
        const SizedBox(height: 14),
        if (alreadyBooked)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 13),
            decoration: BoxDecoration(
              color: const Color(0xFF2E7D32).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                  color: const Color(0xFF2E7D32).withValues(alpha: 0.25)),
            ),
            child: Row(children: [
              const Icon(Icons.check_circle_rounded,
                  size: 18, color: Color(0xFF2E7D32)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Your seat is booked',
                          style: GoogleFonts.poppins(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF2E7D32))),
                      const SizedBox(height: 1),
                      Text('The joining link comes on WhatsApp before it starts',
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              height: 1.35,
                              color: const Color(0xFF5A6B82))),
                    ]),
              ),
            ]),
          )
        else
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: full
                  ? null
                  : () => _DemoSheet.show(context, demo, onBooked),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF12326B),
                disabledBackgroundColor: const Color(0xFFD7DEE8),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11)),
              ),
              icon: Icon(full ? Icons.block_rounded : Icons.event_seat_rounded,
                  size: 17,
                  color: full ? const Color(0xFF9AA5B5) : Colors.white),
              label: Text(full ? 'This one is full' : 'Book a free seat',
                  style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: full ? const Color(0xFF9AA5B5) : Colors.white)),
            ),
          ),
      ]),
    );
  }

  Widget _tag(String t, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(t,
            style: GoogleFonts.inter(
                fontSize: 10, fontWeight: FontWeight.w700, color: c)),
      );

  Widget _chip(IconData i, String t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F4F9),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(i, size: 12, color: const Color(0xFF5A6B82)),
          const SizedBox(width: 4),
          Text(t,
              style: GoogleFonts.inter(
                  fontSize: 11, fontWeight: FontWeight.w500,
                  color: const Color(0xFF5A6B82))),
        ]),
      );
}

/// Name and number, then the joining link.
class _DemoSheet extends StatefulWidget {
  final Map<String, dynamic> demo;
  final Future<void> Function(int demoId) onBooked;
  const _DemoSheet({required this.demo, required this.onBooked});

  static Future<void> show(BuildContext context, Map<String, dynamic> demo,
          Future<void> Function(int demoId) onBooked) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _DemoSheet(demo: demo, onBooked: onBooked),
      );

  @override
  State<_DemoSheet> createState() => _DemoSheetState();
}

class _DemoSheetState extends State<_DemoSheet> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  bool _sending = false;
  String _error = '';
  Map<String, dynamic>? _done;

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
      setState(() => _error = 'Tell us your name so we can let you in');
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
      final r = await ApiService.registerForDemo(
        demoId: widget.demo['id'] as int,
        name: name,
        phone: digits,
        email: _email.text.trim(),
      );
      if (mounted) setState(() => _done = r);
      await widget.onBooked(widget.demo['id'] as int);
    } catch (e) {
      if (mounted) {
        final msg = e is ApiException ? e.message : 'Could not book that. $e';
        setState(() => _error = msg);
        // Filled up while this sheet was open — the card behind it is stale.
        if (msg.toLowerCase().contains('filled')) {
          widget.onBooked(widget.demo['id'] as int);
        }
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 22),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
                child: _done != null ? _confirmed() : _form()),
          ),
        ),
      );

  Widget _grab() => Center(
        child: Container(
          width: 38,
          height: 4,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
              color: const Color(0xFFD7DEE8),
              borderRadius: BorderRadius.circular(2)),
        ),
      );

  Widget _confirmed() {
    final d = _done!;
    final link = '${d['meeting_link'] ?? ''}';
    return Column(mainAxisSize: MainAxisSize.min, children: [
      _grab(),
      const Icon(Icons.event_seat_rounded, size: 46, color: Color(0xFF2E7D32)),
      const SizedBox(height: 12),
      Text(d['already'] == true ? 'You already have a seat' : 'Seat booked',
          style: GoogleFonts.poppins(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF0B2450))),
      const SizedBox(height: 6),
      Text('${d['title']}\n${d['when']}',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
              fontSize: 12.5, height: 1.6, color: const Color(0xFF5A6B82))),
      const SizedBox(height: 18),
      if (link.isNotEmpty)
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => launchUrl(Uri.parse(link),
                mode: LaunchMode.externalApplication),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF12326B),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.videocam_rounded, size: 18, color: Colors.white),
            label: Text('Open the joining link',
                style: GoogleFonts.poppins(
                    fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
          ),
        )
      else
        Text('We will send the joining link on your WhatsApp before it starts.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
                fontSize: 12, height: 1.5, color: const Color(0xFF5A6B82))),
      const SizedBox(height: 8),
      Text('A copy is on its way to your WhatsApp.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
              fontSize: 11, color: const Color(0xFF9AA5B5))),
      const SizedBox(height: 9),
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text('Done',
            style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF5A6B82))),
      ),
    ]);
  }

  Widget _form() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _grab(),
          Text('Book a free seat',
              style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0B2450))),
          const SizedBox(height: 4),
          Text('${widget.demo['title']}  ·  ${widget.demo['when']}',
              style: GoogleFonts.inter(
                  fontSize: 12.5, height: 1.5, color: const Color(0xFF5A6B82))),
          const SizedBox(height: 18),
          _field(_name, 'Your name', TextInputType.name),
          const SizedBox(height: 11),
          _field(_phone, 'Mobile number', TextInputType.phone, formatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ], prefix: '+91 '),
          const SizedBox(height: 11),
          _field(_email, 'Email', TextInputType.emailAddress),
          const SizedBox(height: 14),
          // Said before they commit, not after. Somebody who does not use
          // WhatsApp needs to know that now.
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: const Color(0xFF25D366).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.chat_rounded, size: 16, color: Color(0xFF25D366)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'You will get the joining link on your WhatsApp before the '
                  'session starts.',
                  style: GoogleFonts.inter(
                      fontSize: 11.5,
                      height: 1.45,
                      color: const Color(0xFF0B2450)),
                ),
              ),
            ]),
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
                disabledBackgroundColor:
                    const Color(0xFF12326B).withValues(alpha: 0.45),
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape:
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: _sending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_rounded, size: 18, color: Colors.white),
              label: Text(_sending ? 'Booking...' : 'Confirm my seat',
                  style: GoogleFonts.poppins(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.white)),
            ),
          ),
          const SizedBox(height: 8),
          Text('Reply STOP on WhatsApp any time.',
              style: GoogleFonts.inter(
                  fontSize: 10.5, height: 1.45, color: const Color(0xFF9AA5B5))),
        ],
      );

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
