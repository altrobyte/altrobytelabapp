import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants/app_colors.dart';
import '../../constants/api_constants.dart';

const _earnedColor = AppColors.success;
const _brandColor = AppColors.primary;

class CommissionTrackerScreen extends StatefulWidget {
  const CommissionTrackerScreen({super.key});

  @override
  State<CommissionTrackerScreen> createState() => _CommissionTrackerScreenState();
}

class _CommissionTrackerScreenState extends State<CommissionTrackerScreen> {
  bool _loading = true;
  Map<String, dynamic> _summary = {};
  List<dynamic> _commissions = [];
  bool _calculating = false;
  String _filterStatus = 'all';
  String? _filterMonth;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<Map<String, String>> _authHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('super_admin_token') ?? '';
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final headers = await _authHeaders();
    try {
      final summaryRes = await http.get(
          Uri.parse(ApiConstants.commissionSummary()), headers: headers);
      if (summaryRes.statusCode == 200) {
        _summary = jsonDecode(summaryRes.body);
      }

      var url = ApiConstants.commissions();
      final params = <String>[];
      if (_filterStatus != 'all') params.add('status=$_filterStatus');
      if (_filterMonth != null) params.add('month=$_filterMonth');
      if (params.isNotEmpty) url += '?${params.join('&')}';

      final listRes = await http.get(Uri.parse(url), headers: headers);
      if (listRes.statusCode == 200) {
        final data = jsonDecode(listRes.body);
        _commissions = data['commissions'] ?? [];
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _calculate() async {
    setState(() => _calculating = true);
    final headers = await _authHeaders();
    try {
      final res = await http.post(
          Uri.parse(ApiConstants.calculateCommissions()), headers: headers);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        _toast('Calculated for ${data['institutes_processed']} institutes');
        await _load();
      }
    } catch (e) {
      _toast(e.toString());
    }
    if (mounted) setState(() => _calculating = false);
  }

  Future<void> _markPaid(int id) async {
    final headers = await _authHeaders();
    try {
      final res = await http.put(
          Uri.parse(ApiConstants.markCommissionPaid(id)), headers: headers);
      if (res.statusCode == 200) {
        _toast('Marked as paid!');
        await _load();
      }
    } catch (e) {
      _toast(e.toString());
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    final totalEarned = _summary['total_earned'] ?? 0;
    final totalPaid = _summary['total_paid'] ?? 0;
    final totalPending = _summary['total_pending'] ?? 0;
    final instCount = _summary['institutes_count'] ?? 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.sidebar,
        foregroundColor: Colors.white,
        title: Text('Commission Tracker',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _earnedColor))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── Summary Cards ──
                  Row(children: [
                    _summaryCard('Total Earned', '₹$totalEarned', _earnedColor),
                    const SizedBox(width: 10),
                    _summaryCard('Collected', '₹$totalPaid', AppColors.success),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    _summaryCard('Pending', '₹$totalPending', AppColors.error),
                    const SizedBox(width: 10),
                    _summaryCard('Institutes', '$instCount', _brandColor),
                  ]),
                  const SizedBox(height: 20),

                  // ── Actions ──
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: _brandColor,
                      minimumSize: const Size(double.infinity, 46),
                    ),
                    onPressed: _calculating ? null : _calculate,
                    icon: _calculating
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.calculate_rounded, size: 18),
                    label: Text(_calculating
                        ? 'Calculating...'
                        : 'Calculate This Month\'s Commissions'),
                  ),
                  const SizedBox(height: 16),

                  // ── Filters ──
                  Row(children: [
                    Text('Filter: ',
                        style: GoogleFonts.inter(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    _filterChip('All', 'all'),
                    const SizedBox(width: 6),
                    _filterChip('Pending', 'pending'),
                    const SizedBox(width: 6),
                    _filterChip('Paid', 'paid'),
                  ]),
                  const SizedBox(height: 12),

                  // ── Commission List ──
                  if (_commissions.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.monetization_on_outlined,
                                size: 48, color: Colors.grey.shade300),
                            const SizedBox(height: 8),
                            Text('No commission records found',
                                style: GoogleFonts.inter(
                                    color: AppColors.textSecondary)),
                            const SizedBox(height: 4),
                            Text('Tap "Calculate" to generate records',
                                style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._commissions.map((c) => _commissionTile(c)),
                ],
              ),
            ),
    );
  }

  Widget _summaryCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: GoogleFonts.poppins(
                    fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 2),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    final active = _filterStatus == value;
    return InkWell(
      onTap: () {
        setState(() => _filterStatus = value);
        _load();
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? _brandColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: active ? _brandColor : Colors.grey.shade300),
        ),
        child: Text(label,
            style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : AppColors.textSecondary)),
      ),
    );
  }

  Widget _commissionTile(dynamic c) {
    final data = c as Map<String, dynamic>;
    final isPaid = data['status'] == 'paid';
    final students = data['premium_students'] ?? 0;
    final total = data['total_commission'] ?? 0;
    final month = data['month'] ?? '';
    final institute = data['institute_name'] ?? 'Unknown';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: isPaid
                    ? AppColors.success.withValues(alpha: 0.1)
                    : AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isPaid ? Icons.check_circle_rounded : Icons.schedule_rounded,
                color: isPaid ? AppColors.success : AppColors.error,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(institute,
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  Text('$month • $students students × ₹12',
                      style: GoogleFonts.inter(
                          fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('₹$total',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isPaid ? AppColors.success : AppColors.textPrimary)),
                if (!isPaid)
                  InkWell(
                    onTap: () => _markPaid(data['id']),
                    child: Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: _earnedColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('Mark Paid',
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _earnedColor)),
                    ),
                  )
                else
                  Text('PAID',
                      style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.success)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
