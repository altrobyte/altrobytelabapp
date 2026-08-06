import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../constants/app_colors.dart';
import '../../services/api_service.dart';

/// Admin view of the same activity feed shown (masked) on student home —
/// full name/phone here, for oversight of who's actually enrolling/
/// registering.
class ActivityFeedAdminScreen extends StatefulWidget {
  const ActivityFeedAdminScreen({super.key});

  @override
  State<ActivityFeedAdminScreen> createState() => _ActivityFeedAdminScreenState();
}

class _ActivityFeedAdminScreenState extends State<ActivityFeedAdminScreen> {
  List<dynamic> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await ApiService.getActivityFeedAdmin(limit: 50);
      if (!mounted) return;
      setState(() { _items = items; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text('Activity Feed', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
        actions: [IconButton(icon: const Icon(Icons.refresh_rounded, color: Colors.white), onPressed: _load)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? Center(child: Text('No activity yet', style: GoogleFonts.inter(color: AppColors.textSecondary)))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _items.length,
                    itemBuilder: (context, i) {
                      final item = _items[i] as Map<String, dynamic>;
                      String? ts;
                      try {
                        ts = DateFormat('d MMM, h:mm a').format(DateTime.parse(item['timestamp']));
                      } catch (_) {}
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0x1A1BA672),
                            child: Icon(Icons.bolt_rounded, color: AppColors.success, size: 20),
                          ),
                          title: RichText(
                            text: TextSpan(
                              style: GoogleFonts.inter(fontSize: 13, color: AppColors.textPrimary),
                              children: [
                                TextSpan(text: '${item['student_name']} ', style: const TextStyle(fontWeight: FontWeight.w700)),
                                TextSpan(text: '${item['action']} '),
                                TextSpan(text: item['target'], style: const TextStyle(fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                          subtitle: Text(
                            [if ((item['student_phone'] ?? '').toString().isNotEmpty) item['student_phone'], if (ts != null) ts]
                                .join('  ·  '),
                            style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.textSecondary),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
