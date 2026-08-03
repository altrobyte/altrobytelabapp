import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../constants/app_colors.dart';
import '../../services/api_service.dart';

/// Public, no-login Live Sessions / Workshops listing — upcoming first,
/// past sessions (with a recording link, if any) below.
class LiveSessionsScreen extends StatefulWidget {
  const LiveSessionsScreen({super.key});

  @override
  State<LiveSessionsScreen> createState() => _LiveSessionsScreenState();
}

class _LiveSessionsScreenState extends State<LiveSessionsScreen> {
  List<dynamic> _sessions = [];
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
      final sessions = await ApiService.getLiveSessions();
      if (!mounted) return;
      setState(() { _sessions = sessions; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  DateTime? _dateOf(Map s) {
    try {
      return s['session_date'] != null ? DateTime.parse(s['session_date']) : null;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final upcoming = _sessions.where((s) {
      final d = _dateOf(s);
      return d == null || d.isAfter(now);
    }).toList();
    final past = _sessions.where((s) {
      final d = _dateOf(s);
      return d != null && d.isBefore(now);
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text('Live Sessions & Workshops',
            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: GoogleFonts.inter(color: AppColors.textSecondary)))
              : _sessions.isEmpty
                  ? Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.video_camera_front_outlined, size: 48, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text('No live sessions scheduled yet',
                            style: GoogleFonts.inter(color: AppColors.textSecondary)),
                      ]),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          if (upcoming.isNotEmpty) ...[
                            Text('Upcoming', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15)),
                            const SizedBox(height: 10),
                            ...upcoming.map((s) => _SessionCard(session: s)),
                            const SizedBox(height: 20),
                          ],
                          if (past.isNotEmpty) ...[
                            Text('Past Sessions', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15)),
                            const SizedBox(height: 10),
                            ...past.map((s) => _SessionCard(session: s)),
                          ],
                        ],
                      ),
                    ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final Map<String, dynamic> session;
  const _SessionCard({required this.session});

  @override
  Widget build(BuildContext context) {
    DateTime? date;
    try {
      date = session['session_date'] != null ? DateTime.parse(session['session_date']) : null;
    } catch (_) {}
    final isPast = date != null && date.isBefore(DateTime.now());
    final hasRecording = (session['recording_url'] ?? '').toString().isNotEmpty;
    final price = (session['price'] as num?) ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/live-sessions/${session['id']}'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if ((session['banner_url'] ?? '').isNotEmpty)
            Image.network(session['banner_url'], height: 140, width: double.infinity, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink()),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: (price > 0 ? AppColors.accent : AppColors.success).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6)),
                  child: Text(price > 0 ? '₹$price' : 'FREE',
                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700,
                          color: price > 0 ? AppColors.accent : AppColors.success)),
                ),
                const SizedBox(width: 8),
                if (session['is_featured'] == true) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6)),
                    child: Text('FEATURED',
                        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.accent)),
                  ),
                  const SizedBox(width: 8),
                ],
                if (isPast && hasRecording)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6)),
                    child: Text('RECORDING AVAILABLE',
                        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.success)),
                  ),
              ]),
              const SizedBox(height: 8),
              Text(session['title'] ?? '', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
              if ((session['host_name'] ?? '').isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('Hosted by ${session['host_name']}',
                    style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textSecondary)),
              ],
              const SizedBox(height: 8),
              Row(children: [
                if (date != null) ...[
                  const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.accent),
                  const SizedBox(width: 6),
                  Text(DateFormat('EEE, d MMM yyyy · h:mm a').format(date),
                      style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textSecondary)),
                ],
              ]),
              if ((session['platform'] ?? '').isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.videocam_outlined, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Text(session['platform'], style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textSecondary)),
                ]),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}
