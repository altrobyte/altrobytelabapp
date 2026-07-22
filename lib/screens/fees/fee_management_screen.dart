import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../models/fee_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/loading_widget.dart';

/// Read-only collection dashboard. All fee actions (add / remind / pay-link /
/// mark-paid) now live on the student's detail page; this screen just shows the
/// money picture and who owes what (tap a defaulter to open their page).
class FeeManagementScreen extends StatefulWidget {
  const FeeManagementScreen({super.key});

  @override
  State<FeeManagementScreen> createState() => _FeeManagementScreenState();
}

class _FeeManagementScreenState extends State<FeeManagementScreen> {
  List<Fee> _pending = [];
  List<Fee> _paid = [];
  bool _loading = true;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load({bool force = false}) async {
    if (!force && _loaded) return;
    final auth = context.read<AuthProvider>();
    if (auth.instituteId == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final pendingRaw = await ApiService.getPendingFees(auth.instituteId!);
      final paidRaw = await ApiService.getFees(auth.instituteId!, status: 'paid');
      if (!mounted) return;
      setState(() {
        _pending =
            pendingRaw.map((f) => Fee.fromJson(Map<String, dynamic>.from(f))).toList();
        _paid =
            paidRaw.map((f) => Fee.fromJson(Map<String, dynamic>.from(f))).toList();
        _loading = false;
        _loaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  double get _totalPending => _pending.fold(0, (s, f) => s + f.amount);
  double get _totalCollected => _paid.fold(0, (s, f) => s + f.amount);

  double get _thisMonth {
    final now = DateTime.now();
    return _paid.where((f) {
      final d = DateTime.tryParse(f.paidDate ?? '');
      return d != null && d.year == now.year && d.month == now.month;
    }).fold(0.0, (s, f) => s + f.amount);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingWidget(message: 'Loading collection...');

    // Defaulters: highest dues first, overdue prioritised.
    final defaulters = [..._pending]
      ..sort((a, b) {
        if (a.isOverdue != b.isOverdue) return a.isOverdue ? -1 : 1;
        return b.amount.compareTo(a.amount);
      });

    return RefreshIndicator(
      onRefresh: () => _load(force: true),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Fee Collection',
              style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          Row(children: [
            _statCard('Collected', Fmt.currency(_totalCollected),
                AppColors.success, Icons.account_balance_wallet_rounded),
            const SizedBox(width: 12),
            _statCard('Pending', Fmt.currency(_totalPending), AppColors.error,
                Icons.pending_actions_rounded),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            _statCard('This Month', Fmt.currency(_thisMonth), AppColors.primary,
                Icons.calendar_month_rounded),
            const SizedBox(width: 12),
            _statCard('Defaulters', '${_pending.length}', AppColors.warning,
                Icons.people_rounded),
          ]),
          const SizedBox(height: 24),
          Row(children: [
            Text('Pending Dues',
                style: GoogleFonts.poppins(
                    fontSize: 16, fontWeight: FontWeight.w600)),
            const Spacer(),
            Text('Tap to open student',
                style: GoogleFonts.inter(
                    fontSize: 11, color: AppColors.textSecondary)),
          ]),
          const SizedBox(height: 8),
          if (defaulters.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: EmptyState(
                  icon: Icons.check_circle_outline,
                  title: 'No pending dues',
                  subtitle: 'All fees are collected'),
            )
          else
            ...defaulters.map((f) => _DefaulterTile(fee: f)),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                    fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _DefaulterTile extends StatelessWidget {
  final Fee fee;
  const _DefaulterTile({required this.fee});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.go('/students/${fee.studentId}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                child: Text(
                    (fee.studentName ?? '?').substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(fee.studentName ?? 'Student',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                    Text('Due: ${Fmt.date(fee.dueDate)}',
                        style: GoogleFonts.inter(
                            fontSize: 12, color: AppColors.textSecondary)),
                    if (fee.isOverdue)
                      Text('OVERDUE',
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              color: AppColors.error,
                              fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(Fmt.currency(fee.amount),
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.error)),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
