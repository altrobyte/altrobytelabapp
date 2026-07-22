// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../constants/api_constants.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class SuperAdminDashboardScreen extends StatefulWidget {
  const SuperAdminDashboardScreen({super.key});

  @override
  State<SuperAdminDashboardScreen> createState() =>
      _SuperAdminDashboardScreenState();
}

class _SuperAdminDashboardScreenState
    extends State<SuperAdminDashboardScreen> {
  Map<String, dynamic>? _stats;
  Map<String, dynamic>? _revenue;
  List<Map<String, dynamic>> _institutes = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final auth = context.read<AuthProvider>();
    final token = auth.token ?? '';
    try {
      final results = await Future.wait([
        ApiService.getSuperStats(token),
        ApiService.getSuperInstitutes(token),
        ApiService.getSuperRevenue(token),
      ]);
      setState(() {
        _stats = results[0];
        _institutes = List<Map<String, dynamic>>.from(results[1]['institutes'] ?? []);
        _revenue = results[2];
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111122),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.white.withValues(alpha: 0.06)),
        ),
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)]),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.shield_rounded,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Text('Super Admin',
                style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B35).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: const Color(0xFFFF6B35).withValues(alpha: 0.3)),
              ),
              child: Text('PLATFORM',
                  style: GoogleFonts.inter(
                      color: const Color(0xFFFF6B35),
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded,
                color: Color(0xFFFFB300), size: 20),
            onPressed: () => context.push('/super/settings'),
            tooltip: 'Platform Settings',
          ),
          IconButton(
            icon: const Icon(Icons.monetization_on_rounded,
                color: Color(0xFF00BFA5), size: 20),
            onPressed: () => context.push('/super/commissions'),
            tooltip: 'Commission Tracker',
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded,
                color: Colors.white38, size: 20),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              icon: const Icon(Icons.logout_rounded,
                  color: Colors.white38, size: 16),
              label: Text('Logout',
                  style: GoogleFonts.inter(
                      color: Colors.white38, fontSize: 12)),
              onPressed: () async {
                await auth.logout();
                if (!mounted) return;
                // ignore: use_build_context_synchronously
                context.go('/');
              },
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF6B35)))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.white24, size: 40),
                      const SizedBox(height: 12),
                      Text(_error!,
                          style: const TextStyle(color: Colors.white38)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF6B35)),
                        onPressed: _load,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: const Color(0xFFFF6B35),
                  backgroundColor: const Color(0xFF1A1A2E),
                  onRefresh: _load,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_revenue != null) ...[
                          const _SectionHeader(
                            icon: Icons.currency_rupee_rounded,
                            title: 'Revenue',
                            subtitle: 'Billing overview',
                          ),
                          const SizedBox(height: 12),
                          _RevenueRow(revenue: _revenue!),
                          const SizedBox(height: 24),
                        ],
                        const _SectionHeader(
                          icon: Icons.bar_chart_rounded,
                          title: 'Platform Overview',
                          subtitle: 'Live stats across all institutes',
                        ),
                        const SizedBox(height: 14),
                        if (_stats != null) _StatsGrid(stats: _stats!),
                        const SizedBox(height: 28),
                        _SectionHeader(
                          icon: Icons.business_rounded,
                          title: 'All Institutes',
                          subtitle: '${_institutes.length} registered',
                          badge: '${_institutes.length}',
                        ),
                        const SizedBox(height: 14),
                        if (_institutes.isEmpty)
                          _EmptyInstitutes()
                        else
                          ..._institutes.map((inst) => _InstituteCard(
                              inst: inst, onRefresh: _load)),
                      ],
                    ),
                  ),
                ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? badge;
  const _SectionHeader(
      {required this.icon,
      required this.title,
      required this.subtitle,
      this.badge});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFFF6B35), size: 18),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(title,
                    style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
                if (badge != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6B35).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(badge!,
                        style: GoogleFonts.inter(
                            color: const Color(0xFFFF6B35),
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ],
            ),
            Text(subtitle,
                style: GoogleFonts.inter(
                    color: Colors.white30, fontSize: 11)),
          ],
        ),
      ],
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final Map<String, dynamic> stats;
  const _StatsGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    final items = [
      _StatItem('Active Institutes', '${stats['active_institutes'] ?? 0}',
          Icons.business_rounded, const Color(0xFF00BFA5)),
      _StatItem('Total Students', '${stats['total_students'] ?? 0}',
          Icons.people_rounded, const Color(0xFF7C4DFF)),
      _StatItem('Total Tests', '${stats['total_tests'] ?? 0}',
          Icons.quiz_rounded, const Color(0xFFFF6B35)),
      _StatItem('Test Attempts', '${stats['total_attempts'] ?? 0}',
          Icons.check_circle_rounded, const Color(0xFF26C6DA)),
      _StatItem('Student Logins', '${stats['active_student_accounts'] ?? 0}',
          Icons.person_rounded, const Color(0xFF5E35B1)),
      _StatItem('Active Managers', '${stats['active_managers'] ?? 0}',
          Icons.manage_accounts_rounded, const Color(0xFFFF8C42)),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 280,
        childAspectRatio: 3.2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) => _StatCard(item: items[i]),
    );
  }
}

class _StatItem {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatItem(this.label, this.value, this.icon, this.color);
}

class _StatCard extends StatelessWidget {
  final _StatItem item;
  const _StatCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: item.color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: item.color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(item.icon, color: item.color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(item.value,
                    style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        height: 1)),
                const SizedBox(height: 2),
                Text(item.label,
                    style: GoogleFonts.inter(
                        color: Colors.white38,
                        fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RevenueRow extends StatelessWidget {
  final Map<String, dynamic> revenue;
  const _RevenueRow({required this.revenue});

  @override
  Widget build(BuildContext context) {
    final items = [
      _RevItem('MRR', '₹${revenue['mrr'] ?? 0}', const Color(0xFF00BFA5), Icons.trending_up_rounded),
      _RevItem('This Month', '₹${revenue['monthly_revenue'] ?? 0}', const Color(0xFF7C4DFF), Icons.calendar_month_rounded),
      _RevItem('Total', '₹${revenue['total_revenue'] ?? 0}', const Color(0xFFFF8C42), Icons.account_balance_wallet_rounded),
      _RevItem('Overdue', '${revenue['overdue_institutes'] ?? 0}', Colors.red, Icons.warning_rounded),
    ];
    return Row(
      children: items.map((e) => Expanded(child: _RevCard(item: e))).toList(),
    );
  }
}

class _RevItem {
  final String label, value;
  final Color color;
  final IconData icon;
  const _RevItem(this.label, this.value, this.color, this.icon);
}

class _RevCard extends StatelessWidget {
  final _RevItem item;
  const _RevCard({required this.item});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: item.color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: item.color.withValues(alpha: 0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(item.icon, color: item.color, size: 16),
        const SizedBox(height: 6),
        Text(item.value,
            style: GoogleFonts.poppins(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, height: 1)),
        Text(item.label,
            style: GoogleFonts.inter(color: Colors.white38, fontSize: 10)),
      ]),
    );
  }
}

class _InstituteCard extends StatelessWidget {
  final Map<String, dynamic> inst;
  final VoidCallback onRefresh;
  const _InstituteCard({required this.inst, required this.onRefresh});

  Color get _statusColor {
    if (inst['is_active'] != true) return Colors.red;
    final exp = inst['plan_expires_at'];
    if (exp == null) return Colors.orange;
    final expDate = DateTime.tryParse(exp.toString());
    if (expDate == null) return Colors.orange;
    final diff = expDate.difference(DateTime.now()).inDays;
    if (diff < 0) return Colors.red;
    if (diff <= 7) return Colors.orange;
    return const Color(0xFF00BFA5);
  }

  String get _expiryLabel {
    final exp = inst['plan_expires_at'];
    if (exp == null) return 'No expiry set';
    final expDate = DateTime.tryParse(exp.toString());
    if (expDate == null) return 'No expiry set';
    final diff = expDate.difference(DateTime.now()).inDays;
    if (diff < 0) return 'EXPIRED';
    if (diff == 0) return 'Expires today';
    if (diff == 1) return 'Expires tomorrow';
    return 'Expires in ${diff}d';
  }

  @override
  Widget build(BuildContext context) {
    final isActive = inst['is_active'] == true;
    final plan = (inst['plan'] ?? 'starter') as String;
    final planColor = plan == 'enterprise'
        ? const Color(0xFFFFD700)
        : plan == 'pro'
            ? const Color(0xFF7C4DFF)
            : const Color(0xFF00BFA5);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF111122),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _statusColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.business_rounded, color: _statusColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Flexible(child: Text(inst['name'] ?? '',
                            style: GoogleFonts.poppins(
                                color: Colors.white, fontSize: 14,
                                fontWeight: FontWeight.w500),
                            maxLines: 1, overflow: TextOverflow.ellipsis)),
                        const SizedBox(width: 8),
                        _Chip(plan.toUpperCase(), planColor),
                      ]),
                      const SizedBox(height: 4),
                      Row(children: [
                        _MiniStat(Icons.people_rounded, '${inst['student_count'] ?? 0}', const Color(0xFF7C4DFF)),
                        const SizedBox(width: 10),
                        _MiniStat(Icons.quiz_rounded, '${inst['test_count'] ?? 0}', const Color(0xFFFF6B35)),
                        const SizedBox(width: 10),
                        _MiniStat(Icons.calendar_today_rounded, _expiryLabel, _statusColor),
                      ]),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, color: Colors.white38, size: 20),
                  color: const Color(0xFF1A1A2E),
                  itemBuilder: (_) => [
                    _menuItem('payment', Icons.payments_rounded, 'Record Payment', const Color(0xFF00BFA5)),
                    _menuItem('plan', Icons.upgrade_rounded, 'Change Plan', const Color(0xFF7C4DFF)),
                    _menuItem('audits', Icons.history_rounded, 'View Audits', const Color(0xFF00BFA5)),
                    if (isActive)
                      _menuItem('suspend', Icons.block_rounded, 'Suspend', Colors.orange)
                    else
                      _menuItem('activate', Icons.check_circle_rounded, 'Activate', const Color(0xFF00BFA5)),
                    _menuItem('delete', Icons.delete_forever_rounded, 'Delete Institute', Colors.red),
                  ],
                  onSelected: (v) => _handleAction(context, v),
                ),
              ],
            ),
          ),
          if (!isActive && inst['suspension_reason'] != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12)),
              ),
              child: Text('Suspended: ${inst['suspension_reason']}',
                  style: GoogleFonts.inter(color: Colors.red.shade300, fontSize: 11)),
            ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _menuItem(String value, IconData icon, String label, Color color) {
    return PopupMenuItem(
      value: value,
      child: Row(children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(color: color, fontSize: 13)),
      ]),
    );
  }

  Future<void> _handleAction(BuildContext context, String action) async {
    final auth = context.read<AuthProvider>();
    final token = auth.token ?? '';
    final id = inst['id'] as int;

    switch (action) {
      case 'activate':
        await ApiService.activateInstitute(id, token, active: true);
        onRefresh();
        break;
      case 'suspend':
        final reason = await _askReason(context);
        if (reason == null) return;
        await ApiService.activateInstitute(id, token, active: false, reason: reason);
        onRefresh();
        break;
      case 'plan':
        await _showChangePlan(context, id, token);
        break;
      case 'payment':
        await _showRecordPayment(context, id, token);
        break;
      case 'audits':
        context.push('/super/audits/$id');
        break;
      case 'delete':
        await _confirmDelete(context, id, token);
        break;
    }
  }

  Future<void> _confirmDelete(BuildContext context, int id, String token) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: Row(children: [
          const Icon(Icons.warning_rounded, color: Colors.red, size: 22),
          const SizedBox(width: 8),
          Text('Delete Institute', style: GoogleFonts.poppins(color: Colors.white)),
        ]),
        content: Text(
          'Permanently delete "${inst['name']}" and ALL its data?\n\nThis cannot be undone.',
          style: GoogleFonts.inter(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white38)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final res = await http.delete(
        Uri.parse('${ApiConstants.baseUrl}/super/institutes/$id'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      );
      if (res.statusCode == 200) {
        onRefresh();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Institute deleted'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  Future<String?> _askReason(BuildContext context) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: Text('Suspension Reason', style: GoogleFonts.poppins(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'e.g. Payment overdue',
            hintStyle: TextStyle(color: Colors.white38),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.white38))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () => Navigator.pop(context, ctrl.text.trim().isEmpty ? 'Suspended by admin' : ctrl.text.trim()),
            child: const Text('Suspend'),
          ),
        ],
      ),
    );
  }

  Future<void> _showChangePlan(BuildContext context, int id, String token) async {
    String selected = inst['plan'] ?? 'starter';
    final plans = ['starter', 'pro', 'enterprise'];
    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          title: Text('Change Plan', style: GoogleFonts.poppins(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: plans.map((p) => RadioListTile<String>(
              value: p,
              groupValue: selected,
              onChanged: (v) => setS(() => selected = v!),
              title: Text(p.toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 14)),
              subtitle: Text(
                p == 'starter' ? '50 students · ₹999/mo'
                    : p == 'pro' ? '200 students · ₹2499/mo'
                    : 'Unlimited · ₹4999/mo',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
              activeColor: const Color(0xFFFF6B35),
            )).toList(),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.white38))),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFF6B35)),
              onPressed: () async {
                await ApiService.changePlan(id, selected, token);
                if (ctx.mounted) Navigator.pop(ctx);
                onRefresh();
              },
              child: const Text('Update Plan'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showRecordPayment(BuildContext context, int id, String token) async {
    final amountCtrl = TextEditingController(text: '${inst['monthly_amount'] ?? 999}');
    final noteCtrl = TextEditingController();
    String plan = inst['plan'] ?? 'starter';
    int months = 1;
    final plans = ['starter', 'pro', 'enterprise'];

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          title: Text('Record Payment', style: GoogleFonts.poppins(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Amount (₹)',
                  labelStyle: TextStyle(color: Colors.white54),
                  prefixText: '₹ ',
                  prefixStyle: TextStyle(color: Colors.white),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFFF6B35))),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: plan,
                dropdownColor: const Color(0xFF1A1A2E),
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Plan',
                  labelStyle: TextStyle(color: Colors.white54),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                ),
                items: plans.map((p) => DropdownMenuItem(value: p, child: Text(p.toUpperCase()))).toList(),
                onChanged: (v) => setS(() => plan = v!),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: months,
                dropdownColor: const Color(0xFF1A1A2E),
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Duration',
                  labelStyle: TextStyle(color: Colors.white54),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                ),
                items: [1, 3, 6, 12].map((m) => DropdownMenuItem(value: m, child: Text('$m month${m > 1 ? 's' : ''}'))).toList(),
                onChanged: (v) => setS(() => months = v!),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  labelStyle: TextStyle(color: Colors.white54),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                ),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.white38))),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF00BFA5)),
              onPressed: () async {
                final amt = int.tryParse(amountCtrl.text.trim()) ?? 0;
                await ApiService.recordPayment(id, token,
                    amount: amt, plan: plan,
                    durationMonths: months, note: noteCtrl.text.trim());
                if (ctx.mounted) Navigator.pop(ctx);
                onRefresh();
              },
              child: const Text('Record Payment'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip(this.label, this.color);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label, style: GoogleFonts.inter(color: color, fontSize: 9, fontWeight: FontWeight.w700)),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color color;
  const _MiniStat(this.icon, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color.withValues(alpha: 0.7)),
        const SizedBox(width: 3),
        Text(value,
            style: GoogleFonts.inter(color: Colors.white38, fontSize: 11)),
      ],
    );
  }
}

class _EmptyInstitutes extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFF111122),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.business_outlined,
                color: Colors.white24, size: 36),
            const SizedBox(height: 10),
            Text('No institutes yet',
                style: GoogleFonts.poppins(
                    color: Colors.white38, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}
