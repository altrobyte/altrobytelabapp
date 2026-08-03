import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../constants/app_colors.dart';
import '../../services/api_service.dart';
import '../../widgets/html_view.dart';
import '../../widgets/registration_success_card.dart';

class EventDetailScreen extends StatefulWidget {
  final int eventId;
  const EventDetailScreen({super.key, required this.eventId});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  Map<String, dynamic>? _event;
  bool _loading = true;
  bool _registered = false;
  bool _registering = false;
  String? _error;

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final event = await ApiService.getEvent(widget.eventId);
      bool registered = false;
      try {
        registered = await ApiService.isRegisteredForEvent(widget.eventId);
      } catch (_) {}
      if (!mounted) return;
      setState(() { _event = event; _registered = registered; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _register() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter your name'), backgroundColor: AppColors.error));
      return;
    }
    setState(() => _registering = true);
    try {
      await ApiService.registerForEvent(widget.eventId,
          name: _nameCtrl.text.trim(), phone: _phoneCtrl.text.trim(), email: _emailCtrl.text.trim());
      if (!mounted) return;
      setState(() { _registered = true; _registering = false; });
      showRegistrationSuccessDialog(context,
          typeLabel: 'EVENT',
          title: _event!['title'] ?? '',
          studentName: _nameCtrl.text.trim());
    } catch (e) {
      if (!mounted) return;
      setState(() => _registering = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null || _event == null) {
      return Scaffold(
        appBar: AppBar(leading: const BackButton()),
        body: Center(child: Text(_error ?? 'Event not found')),
      );
    }
    final event = _event!;
    DateTime? date;
    try {
      date = event['event_date'] != null ? DateTime.parse(event['event_date']) : null;
    } catch (_) {}

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(event['title'] ?? '',
            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
            maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if ((event['banner_url'] ?? '').isNotEmpty)
            Image.network(event['banner_url'], height: 180, width: double.infinity, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink()),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(event['title'] ?? '', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 19)),
              const SizedBox(height: 12),
              if (date != null)
                _infoRow(Icons.calendar_today_rounded, DateFormat('EEEE, d MMMM yyyy · h:mm a').format(date)),
              if ((event['location'] ?? '').isNotEmpty) _infoRow(Icons.location_on_outlined, event['location']),
              if ((event['meeting_link'] ?? '').isNotEmpty) ...[
                const SizedBox(height: 4),
                InkWell(
                  onTap: () async {
                    final uri = Uri.parse(event['meeting_link']);
                    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
                  },
                  child: _infoRow(Icons.videocam_outlined, 'Join meeting link', color: AppColors.accent),
                ),
              ],
              const SizedBox(height: 16),
              if ((event['description_html'] ?? '').isNotEmpty)
                SizedBox(height: 320, child: HtmlView(html: event['description_html'])),
              const SizedBox(height: 20),
              _registrationCard(),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Icon(icon, size: 16, color: color ?? AppColors.textSecondary),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: GoogleFonts.inter(fontSize: 13.5, color: color ?? AppColors.textPrimary))),
      ]),
    );
  }

  Widget _registrationCard() {
    if (_registered) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          const Icon(Icons.check_circle_rounded, color: AppColors.success),
          const SizedBox(width: 10),
          Text('You\'re registered for this event',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppColors.success)),
        ]),
      );
    }
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Register', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 12),
          TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Name *', isDense: true)),
          const SizedBox(height: 10),
          TextField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: 'Phone', isDense: true)),
          const SizedBox(height: 10),
          TextField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'Email', isDense: true)),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _registering ? null : _register,
              style: FilledButton.styleFrom(backgroundColor: AppColors.accent, padding: const EdgeInsets.symmetric(vertical: 13)),
              child: _registering
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text('Register', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      ),
    );
  }
}
