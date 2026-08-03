import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../constants/app_colors.dart';
import '../../services/api_service.dart';

/// Public, no-login events listing.
class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  List<dynamic> _events = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final events = await ApiService.getEvents();
      if (!mounted) return;
      setState(() { _events = events; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text('Events',
            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: GoogleFonts.inter(color: AppColors.textSecondary)))
              : _events.isEmpty
                  ? Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.event_outlined, size: 48, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text('No upcoming events', style: GoogleFonts.inter(color: AppColors.textSecondary)),
                      ]),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _events.length,
                        itemBuilder: (context, i) => _EventCard(event: _events[i]),
                      ),
                    ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final Map<String, dynamic> event;
  const _EventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    DateTime? date;
    try {
      date = event['event_date'] != null ? DateTime.parse(event['event_date']) : null;
    } catch (_) {}

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/events/${event['id']}'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if ((event['banner_url'] ?? '').isNotEmpty)
            Image.network(event['banner_url'], height: 140, width: double.infinity, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink()),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(event['title'] ?? '', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
              const SizedBox(height: 8),
              Row(children: [
                if (date != null) ...[
                  const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.accent),
                  const SizedBox(width: 6),
                  Text(DateFormat('EEE, d MMM yyyy · h:mm a').format(date),
                      style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textSecondary)),
                ],
              ]),
              if ((event['location'] ?? '').isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Text(event['location'], style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textSecondary)),
                ]),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}
