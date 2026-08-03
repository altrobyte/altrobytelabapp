import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../constants/app_colors.dart';
import '../../services/api_service.dart';

/// Super-admin view of "Partner With Us" institution enquiries.
class EnquiriesAdminScreen extends StatefulWidget {
  const EnquiriesAdminScreen({super.key});

  @override
  State<EnquiriesAdminScreen> createState() => _EnquiriesAdminScreenState();
}

class _EnquiriesAdminScreenState extends State<EnquiriesAdminScreen> {
  List<dynamic> _enquiries = [];
  bool _loading = true;

  static const _statuses = ['new', 'contacted', 'converted', 'dismissed'];
  static const _statusColors = {
    'new': AppColors.primary,
    'contacted': AppColors.accentLight,
    'converted': AppColors.success,
    'dismissed': Colors.grey,
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _enquiries = await ApiService.getEnquiriesAdmin();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _updateStatus(Map<String, dynamic> e, String status) async {
    await ApiService.updateEnquiryStatus(e['id'] as int, status);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text('Institution Enquiries', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _enquiries.isEmpty
              ? Center(child: Text('No enquiries yet', style: GoogleFonts.inter(color: AppColors.textSecondary)))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _enquiries.length,
                    itemBuilder: (context, i) {
                      final e = _enquiries[i] as Map<String, dynamic>;
                      final status = e['status'] as String? ?? 'new';
                      DateTime? date;
                      try {
                        date = DateTime.parse(e['created_at']);
                      } catch (_) {}
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Expanded(
                                child: Text(e['contact_name'] ?? '',
                                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14.5)),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: (_statusColors[status] ?? Colors.grey).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(status,
                                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600,
                                        color: _statusColors[status] ?? Colors.grey)),
                              ),
                            ]),
                            if ((e['organization_name'] ?? '').isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(e['organization_name'], style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textSecondary)),
                            ],
                            const SizedBox(height: 6),
                            Wrap(spacing: 12, children: [
                              if ((e['email'] ?? '').isNotEmpty) Text(e['email'], style: GoogleFonts.inter(fontSize: 12)),
                              if ((e['phone'] ?? '').isNotEmpty) Text(e['phone'], style: GoogleFonts.inter(fontSize: 12)),
                              if ((e['student_count'] ?? '').isNotEmpty)
                                Text('~${e['student_count']} students', style: GoogleFonts.inter(fontSize: 12)),
                            ]),
                            if ((e['message'] ?? '').isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(e['message'], style: GoogleFonts.inter(fontSize: 12.5, height: 1.4)),
                            ],
                            if (date != null) ...[
                              const SizedBox(height: 6),
                              Text(DateFormat('d MMM yyyy, h:mm a').format(date),
                                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
                            ],
                            const SizedBox(height: 10),
                            Wrap(spacing: 6, children: _statuses.map((s) => ChoiceChip(
                              label: Text(s, style: GoogleFonts.inter(fontSize: 11)),
                              selected: status == s,
                              onSelected: (_) => _updateStatus(e, s),
                            )).toList()),
                          ]),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
