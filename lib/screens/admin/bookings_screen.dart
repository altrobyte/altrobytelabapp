import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/api_service.dart';

/// The call schedule, soonest first — which is the order you work through it.
class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  List<dynamic> _rows = [];
  bool _loading = true;
  bool _upcoming = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final r = await ApiService.getBookings(upcoming: _upcoming);
      if (mounted) {
        setState(() {
          _rows = r;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e is ApiException ? e.message : '$e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _setStatus(int id, String status) async {
    try {
      await ApiService.setBookingStatus(id, status);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not update: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: Text('Booked calls',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 17)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0B2450),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded, size: 21),
            onPressed: _load,
          ),
        ],
      ),
      body: Column(children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
          child: Row(children: [
            for (final t in const [(true, 'Upcoming'), (false, 'All')])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(t.$2, style: GoogleFonts.inter(fontSize: 12.5)),
                  selected: _upcoming == t.$1,
                  onSelected: (_) {
                    setState(() => _upcoming = t.$1);
                    _load();
                  },
                ),
              ),
            const Spacer(),
            Text('${_rows.length}',
                style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF12326B))),
          ]),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error.isNotEmpty
                  ? Center(child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(_error, textAlign: TextAlign.center)))
                  : _rows.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(28),
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.event_note_rounded,
                                      size: 42, color: Color(0xFF9AA5B5)),
                                  const SizedBox(height: 12),
                                  Text('Nothing booked yet',
                                      style: GoogleFonts.poppins(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF0B2450))),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Share altrobytelab.com/book and slots '
                                    'will appear here as people take them.',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.inter(
                                        fontSize: 12.5,
                                        height: 1.5,
                                        color: const Color(0xFF5A6B82)),
                                  ),
                                ]),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.separated(
                            padding: const EdgeInsets.all(14),
                            itemCount: _rows.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (_, i) =>
                                _row(_rows[i] as Map<String, dynamic>),
                          ),
                        ),
        ),
      ]),
    );
  }

  Widget _row(Map<String, dynamic> b) {
    final status = '${b['status']}';
    final phone = '${b['phone']}';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6EBF3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text('${b['when']}',
                style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF12326B))),
          ),
          _pill(status),
        ]),
        const SizedBox(height: 7),
        Text('${b['name']}',
            style: GoogleFonts.poppins(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF0B2450))),
        if ('${b['topic']}'.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text('${b['topic']}',
              style: GoogleFonts.inter(
                  fontSize: 12, height: 1.45, color: const Color(0xFF5A6B82))),
        ],
        const SizedBox(height: 11),
        Wrap(spacing: 7, runSpacing: 7, children: [
          _act(Icons.call_rounded, '+$phone',
              () => launchUrl(Uri.parse('tel:+$phone'))),
          _act(Icons.chat_rounded, 'WhatsApp',
              () => launchUrl(Uri.parse('https://wa.me/$phone'),
                  mode: LaunchMode.externalApplication)),
          _act(Icons.calendar_month_rounded, 'Calendar',
              () => launchUrl(Uri.parse('${b['google_calendar_url']}'),
                  mode: LaunchMode.externalApplication)),
        ]),
        if (status == 'booked') ...[
          const Divider(height: 22),
          Row(children: [
            for (final s in const [
              ('done', 'Done'),
              ('no_show', 'No show'),
              ('cancelled', 'Cancel'),
            ])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: OutlinedButton(
                  onPressed: () => _setStatus(b['id'] as int, s.$1),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(s.$2, style: GoogleFonts.inter(fontSize: 11.5)),
                ),
              ),
          ]),
        ],
      ]),
    );
  }

  Widget _pill(String status) {
    final colour = switch (status) {
      'done' => const Color(0xFF2E7D32),
      'no_show' => const Color(0xFFE65100),
      'cancelled' => const Color(0xFF9AA5B5),
      _ => const Color(0xFF12326B),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(status.replaceAll('_', ' '),
          style: GoogleFonts.inter(
              fontSize: 10, fontWeight: FontWeight.w700, color: colour)),
    );
  }

  Widget _act(IconData icon, String label, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F4F9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 14, color: const Color(0xFF12326B)),
            const SizedBox(width: 5),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF12326B))),
          ]),
        ),
      );
}
