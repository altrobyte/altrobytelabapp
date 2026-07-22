import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import '../services/api_service.dart';

class AuditLogsScreen extends StatefulWidget {
  final int instituteId;
  final bool isSuperAdmin;

  const AuditLogsScreen({
    super.key,
    required this.instituteId,
    this.isSuperAdmin = false,
  });

  @override
  State<AuditLogsScreen> createState() => _AuditLogsScreenState();
}

class _AuditLogsScreenState extends State<AuditLogsScreen> {
  List<Map<String, dynamic>> _audits = [];
  bool _loading = true;
  String? _error;
  String? _note;

  @override
  void initState() {
    super.initState();
    _loadAudits();
  }

  Future<void> _loadAudits() async {
    setState(() {
      _loading = true;
      _error = null;
      _note = null;
    });

    try {
      final audits = await ApiService.getAudits(widget.instituteId);
      if (!mounted) return;
      setState(() {
        _audits = List<Map<String, dynamic>>.from(audits);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      final err = e.toString();
      setState(() {
        _error = err;
        if (err.contains('note')) {
          _note = 'Audit logs table not yet available. Ask admin to run migration.';
        }
        _loading = false;
      });
    }
  }

  String _formatAction(String action) {
    return action.replaceAll('.', ' ').toUpperCase();
  }

  String _formatTime(String? timestamp) {
    if (timestamp == null) return '';
    try {
      final dt = DateTime.parse(timestamp);
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return timestamp;
    }
  }

  IconData _getActionIcon(String action) {
    if (action.contains('login')) return Icons.login_rounded;
    if (action.contains('student.add')) return Icons.person_add_rounded;
    if (action.contains('fee')) return Icons.payments_rounded;
    if (action.contains('register')) return Icons.app_registration_rounded;
    if (action.contains('test')) return Icons.quiz_rounded;
    return Icons.history_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isSuperAdmin
        ? 'Audit Logs (Institute #${widget.instituteId})'
        : 'Activity Logs';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.sidebar,
        elevation: 0,
        title: Text(
          title,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, color: AppColors.error, size: 48),
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          style: GoogleFonts.inter(color: Colors.white70),
                          textAlign: TextAlign.center,
                        ),
                        if (_note != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _note!,
                            style: GoogleFonts.inter(color: AppColors.accent, fontSize: 13),
                          ),
                        ],
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _loadAudits,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : _audits.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.history_toggle_off_rounded, size: 64, color: Colors.white24),
                          const SizedBox(height: 16),
                          Text(
                            'No activity logs yet',
                            style: GoogleFonts.poppins(color: Colors.white54, fontSize: 16),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadAudits,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _audits.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final log = _audits[index];
                          final action = (log['action'] ?? '').toString();
                          final actor = '${log['actor_type'] ?? ''} #${log['actor_id'] ?? ''}';
                          final time = _formatTime(log['created_at']?.toString());
                          final details = log['details'] as Map<String, dynamic>?;

                          return Container(
                            decoration: BoxDecoration(
                              color: AppColors.sidebar,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppColors.accent.withValues(alpha: 0.15),
                                child: Icon(
                                  _getActionIcon(action),
                                  color: AppColors.accent,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                _formatAction(action),
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'By $actor',
                                    style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
                                  ),
                                  if (details != null && details.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        details.toString(),
                                        style: GoogleFonts.inter(
                                          color: Colors.white38,
                                          fontSize: 11,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                              ),
                              trailing: Text(
                                time,
                                style: GoogleFonts.inter(color: Colors.white38, fontSize: 11),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}