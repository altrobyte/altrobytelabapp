import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../constants/app_colors.dart';
import '../../services/api_service.dart';

/// Public, no-login Live Sessions / Workshops listing — upcoming first,
/// past sessions (with a recording link, if any) below. Grid layout on
/// wide screens, matching the Training Modules and home-feed Featured
/// carousel poster style rather than full-bleed banner cards.
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
    }).toList()
      ..sort((a, b) {
        final da = _dateOf(a);
        final db = _dateOf(b);
        if (da == null || db == null) return 0;
        return da.compareTo(db);
      });
    final past = _sessions.where((s) {
      final d = _dateOf(s);
      return d != null && d.isBefore(now);
    }).toList()
      ..sort((a, b) {
        final da = _dateOf(a);
        final db = _dateOf(b);
        if (da == null || db == null) return 0;
        return db.compareTo(da);
      });

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
                      // Max-extent (not fixed-count) grid: card width never
                      // grows past ~260, so the image (and therefore total
                      // card height) stays consistent at any window width —
                      // a fixed column count let a single-column card go
                      // nearly full-width on a narrow browser, making the
                      // image tall enough to push the button past the
                      // card's fixed height and get clipped.
                      child: CustomScrollView(
                        slivers: [
                          if (upcoming.isNotEmpty) ...[
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                              sliver: SliverToBoxAdapter(
                                child: Text('Upcoming',
                                    style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16)),
                              ),
                            ),
                            SliverPadding(
                              padding: const EdgeInsets.all(16),
                              sliver: SliverGrid(
                                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: 260,
                                  mainAxisSpacing: 16,
                                  crossAxisSpacing: 16,
                                  mainAxisExtent: 320,
                                ),
                                delegate: SliverChildBuilderDelegate(
                                  (context, i) => _SessionCard(session: upcoming[i]),
                                  childCount: upcoming.length,
                                ),
                              ),
                            ),
                          ],
                          if (past.isNotEmpty) ...[
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                              sliver: SliverToBoxAdapter(
                                child: Text('Past Sessions',
                                    style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16)),
                              ),
                            ),
                            SliverPadding(
                              padding: const EdgeInsets.all(16),
                              sliver: SliverGrid(
                                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: 260,
                                  mainAxisSpacing: 16,
                                  crossAxisSpacing: 16,
                                  mainAxisExtent: 320,
                                ),
                                delegate: SliverChildBuilderDelegate(
                                  (context, i) => _SessionCard(session: past[i]),
                                  childCount: past.length,
                                ),
                              ),
                            ),
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
    final originalPrice = (session['original_price'] as num?);
    final banner = (session['banner_url'] ?? '').toString();

    final tagLabel = isPast ? (hasRecording ? 'Watch Recording' : 'Session Ended') : 'Register Now';
    final tagIcon = isPast
        ? (hasRecording ? Icons.play_circle_fill_rounded : Icons.event_busy_rounded)
        : Icons.arrow_forward_rounded;
    final ended = isPast && !hasRecording;
    final tagColor = ended
        ? Colors.grey.shade200
        : hasRecording && isPast
            ? AppColors.primary
            : AppColors.accent;
    final tagTextColor = ended ? AppColors.textSecondary : Colors.white;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/live-sessions/${session['id']}'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            // contain, not cover — these banners are text-heavy promo
            // posters (title, dates, curriculum bullets baked into the
            // image itself), so cropping to fill the box was cutting off
            // real content instead of just trimming empty margin.
            child: banner.isNotEmpty
                ? Container(
                    color: Colors.grey.shade100,
                    child: Image.network(banner, fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const _BannerFallback()),
                  )
                : const _BannerFallback(),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  if (session['is_featured'] == true) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                      child: Text('FEATURED',
                          style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.accent)),
                    ),
                    const SizedBox(width: 6),
                  ],
                  if (originalPrice != null && originalPrice > price) ...[
                    Text('₹${originalPrice.toStringAsFixed(0)}',
                        style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary, decoration: TextDecoration.lineThrough)),
                    const SizedBox(width: 4),
                  ],
                  Text(price > 0 ? '₹${price.toStringAsFixed(0)}' : 'FREE',
                      style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w800,
                          color: price > 0 ? AppColors.accent : AppColors.success)),
                ]),
                const SizedBox(height: 6),
                Text(session['title'] ?? '',
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13.5)),
                const Spacer(),
                if (date != null)
                  Row(children: [
                    const Icon(Icons.calendar_today_rounded, size: 12, color: AppColors.textSecondary),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(DateFormat('d MMM, h:mm a').format(date),
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.textSecondary)),
                    ),
                  ]),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  decoration: BoxDecoration(
                    color: tagColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: ended
                        ? null
                        : [BoxShadow(color: tagColor.withValues(alpha: 0.3), blurRadius: 6, offset: const Offset(0, 2))],
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(tagIcon, size: 12, color: tagTextColor),
                    const SizedBox(width: 5),
                    Text(tagLabel, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: tagTextColor)),
                  ]),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class _BannerFallback extends StatelessWidget {
  const _BannerFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(child: Icon(Icons.video_camera_front_rounded, color: Colors.white, size: 36)),
    );
  }
}
