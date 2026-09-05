import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../constants/app_colors.dart';
import '../../services/api_service.dart';

/// Everybody who sat the scholarship test, and what it earned them.
///
/// Deliberately not a filter on the leads list. A lead is somebody to chase;
/// a scholar is somebody already holding an offer with a date on it, and the
/// question about them is different — did they redeem it, and if not, why
/// not. That warrants its own list with its own numbers at the top.
class ScholarsScreen extends StatefulWidget {
  const ScholarsScreen({super.key});

  @override
  State<ScholarsScreen> createState() => _ScholarsScreenState();
}

class _ScholarsScreenState extends State<ScholarsScreen> {
  List<Map<String, dynamic>> _rows = [];
  int _total = 0;
  int _awarded = 0;
  int _redeemed = 0;
  bool _loading = true;
  bool _awardedOnly = false;
  String _error = '';
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final d = await ApiService.getScholars(
          q: _search.text.trim(), awardedOnly: _awardedOnly);
      _rows = ((d['scholars'] as List?) ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      _total = (d['total'] as num?)?.toInt() ?? 0;
      _awarded = (d['awarded'] as num?)?.toInt() ?? 0;
      _redeemed = (d['redeemed'] as num?)?.toInt() ?? 0;
      _error = '';
    } catch (e) {
      _error = e is ApiException ? e.message : '$e';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _whatsapp(Map<String, dynamic> r) async {
    final phone = '${r['phone'] ?? ''}'.replaceAll(RegExp(r'\D'), '');
    if (phone.isEmpty) return;
    final off = (r['discount_percent'] as num?)?.toInt() ?? 0;
    final pct = r['percent'];
    final name = '${r['name'] ?? ''}'.split(' ').first;
    final text = Uri.encodeComponent(off > 0
        ? "Hi $name! Congratulations — you scored $pct% on the Altrobyte "
            "Scholarship Test, which earns you $off% off. Your code is "
            "${r['coupon_code']}. Shall I hold a seat for you?"
        : "Hi $name! Thanks for taking the Altrobyte Scholarship Test — you "
            "scored $pct%. Happy to walk you through the programme and what "
            "it covers, if you would like.");
    final n = phone.length == 10 ? '91$phone' : phone;
    final uri = Uri.parse('https://wa.me/$n?text=$text');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open WhatsApp')));
    }
  }

  void _copy(Map<String, dynamic> r) {
    final lines = [
      '${r['name'] ?? ''}',
      '${r['phone'] ?? ''}',
      if ('${r['email'] ?? ''}'.isNotEmpty) '${r['email']}',
      if ('${r['college'] ?? ''}'.isNotEmpty) '${r['college']}',
      if ('${r['branch'] ?? ''}'.isNotEmpty) '${r['branch']}',
      if ('${r['year_of_study'] ?? ''}'.isNotEmpty) 'Year ${r['year_of_study']}',
      if ('${r['city'] ?? ''}'.isNotEmpty) '${r['city']}',
      'Scored ${r['score']}/${r['total']} (${r['percent']}%)',
      if (((r['discount_percent'] as num?)?.toInt() ?? 0) > 0)
        '${r['discount_percent']}% off — code ${r['coupon_code']}',
    ];
    Clipboard.setData(ClipboardData(text: lines.join('\n')));
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Details copied')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: Text('Scholars',
            style:
                GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 17)),
        actions: [
          IconButton(
              onPressed: _load, icon: const Icon(Icons.refresh_rounded, size: 21)),
        ],
      ),
      body: Column(children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          child: Column(children: [
            Row(children: [
              _stat('Sat it', '$_total'),
              _stat('Won a band', '$_awarded'),
              _stat('Redeemed', '$_redeemed'),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  onSubmitted: (_) => _load(),
                  decoration: InputDecoration(
                    hintText: 'Name, number or college',
                    prefixIcon: const Icon(Icons.search_rounded, size: 19),
                    isDense: true,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Won only'),
                selected: _awardedOnly,
                onSelected: (v) {
                  setState(() => _awardedOnly = v);
                  _load();
                },
              ),
            ]),
          ]),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error.isNotEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(_error,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.error)),
                      ),
                    )
                  : _rows.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(28),
                            child: Text(
                                'Nobody has sat the scholarship test yet. '
                                'Once somebody does, they appear here with '
                                'their details and their score.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                    fontSize: 13,
                                    height: 1.55,
                                    color: AppColors.textSecondary)),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 30),
                            itemCount: _rows.length,
                            itemBuilder: (_, i) => _row(_rows[i]),
                          ),
                        ),
        ),
      ]),
    );
  }

  Widget _stat(String label, String value) => Expanded(
        child: Column(children: [
          Text(value,
              style: GoogleFonts.poppins(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary)),
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 11, color: AppColors.textSecondary)),
        ]),
      );

  Widget _row(Map<String, dynamic> r) {
    final off = (r['discount_percent'] as num?)?.toInt() ?? 0;
    final pct = (r['percent'] as num?)?.toDouble() ?? 0;
    final code = '${r['coupon_code'] ?? ''}';
    final used = (r['coupon_used_count'] as num?)?.toInt() ?? 0;
    final where = [
      '${r['college'] ?? ''}',
      '${r['branch'] ?? ''}',
      '${r['year_of_study'] ?? ''}',
    ].where((e) => e.isNotEmpty).join(' · ');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFE6EBF3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(
                '${r['name'] ?? ''}'.isEmpty ? 'No name given' : '${r['name']}',
                style: GoogleFonts.poppins(
                    fontSize: 14.5, fontWeight: FontWeight.w600)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
                color: (off > 0 ? AppColors.success : AppColors.textSecondary)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20)),
            child: Text(off > 0 ? '$off% off' : 'no award',
                style: GoogleFonts.inter(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: off > 0 ? AppColors.success : AppColors.textSecondary)),
          ),
        ]),
        const SizedBox(height: 3),
        Text(
            '${r['score']}/${r['total']} correct · ${pct.toStringAsFixed(0)}%'
            '${'${r['phone'] ?? ''}'.isEmpty ? '' : ' · ${r['phone']}'}',
            style: GoogleFonts.inter(
                fontSize: 12, color: AppColors.textSecondary)),
        if (where.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(where,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                  fontSize: 12, color: AppColors.textSecondary)),
        ],
        if (code.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(children: [
            Icon(
                used > 0
                    ? Icons.check_circle_rounded
                    : Icons.confirmation_number_outlined,
                size: 15,
                color: used > 0 ? AppColors.success : AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(code,
                style: GoogleFonts.poppins(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: AppColors.primary)),
            const SizedBox(width: 8),
            Text(used > 0 ? 'redeemed' : 'not used yet',
                style: GoogleFonts.inter(
                    fontSize: 11, color: AppColors.textSecondary)),
          ]),
        ],
        const SizedBox(height: 8),
        Row(children: [
          TextButton.icon(
            onPressed: () => _whatsapp(r),
            icon: const Icon(Icons.chat_rounded, size: 16),
            label: const Text('WhatsApp'),
            style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF128C7E),
                visualDensity: VisualDensity.compact),
          ),
          const SizedBox(width: 4),
          TextButton.icon(
            onPressed: () => _copy(r),
            icon: const Icon(Icons.copy_rounded, size: 15),
            label: const Text('Copy details'),
            style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                visualDensity: VisualDensity.compact),
          ),
        ]),
      ]),
    );
  }
}
