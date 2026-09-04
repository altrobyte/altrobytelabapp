import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../constants/app_colors.dart';
import '../../services/api_service.dart';

/// Which test decides the price, and what each score is worth.
///
/// The bands are a pricing decision, so they live here rather than in the
/// code — the right numbers are the ones that fill a batch, and finding them
/// should not need a deploy.
class ScholarshipAdminScreen extends StatefulWidget {
  const ScholarshipAdminScreen({super.key});

  @override
  State<ScholarshipAdminScreen> createState() => _ScholarshipAdminScreenState();
}

class _ScholarshipAdminScreenState extends State<ScholarshipAdminScreen> {
  final _testId = TextEditingController();
  final _base = TextEditingController();
  final _days = TextEditingController();
  List<Map<String, dynamic>> _slabs = [];
  List _awards = const [];
  bool _loading = true;
  bool _saving = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _testId.dispose();
    _base.dispose();
    _days.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final d = await ApiService.getScholarshipAdmin();
      _testId.text = '${d['test_id'] ?? 0}';
      _base.text = '${(d['base_amount'] as num?)?.toInt() ?? 10000}';
      _days.text = '${d['valid_days'] ?? 14}';
      _slabs = ((d['slabs'] as List?) ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      _awards = (d['awards'] as List?) ?? const [];
      _error = '';
    } catch (e) {
      _error = e is ApiException ? e.message : '$e';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ApiService.saveScholarshipAdmin({
        'test_id': int.tryParse(_testId.text.trim()) ?? 0,
        'base_amount': double.tryParse(_base.text.trim()) ?? 10000,
        'valid_days': int.tryParse(_days.text.trim()) ?? 14,
        'slabs': _slabs,
      });
      messenger.showSnackBar(const SnackBar(content: Text('Saved')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
          backgroundColor: AppColors.error,
          content: Text(e is ApiException ? e.message : '$e')));
    }
    if (mounted) setState(() => _saving = false);
    _load();
  }

  double get _baseAmount => double.tryParse(_base.text.trim()) ?? 10000;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Text('Scholarship Test',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving…' : 'Save',
                style: GoogleFonts.poppins(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(16), children: [
              if (_error.isNotEmpty) ...[
                Text(_error, style: const TextStyle(color: AppColors.error)),
                const SizedBox(height: 12),
              ],
              _card('Which test', [
                TextField(
                  controller: _testId,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Test ID',
                    helperText:
                        'The published test students sit. 0 turns the '
                        'scholarship off entirely.',
                    helperMaxLines: 2,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _base,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Full fee', prefixText: 'Rs '),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _days,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Coupon valid for (days)',
                    helperText: 'A scholarship that never expires is a price '
                        'change, not an offer.',
                    helperMaxLines: 2,
                  ),
                ),
              ]),
              const SizedBox(height: 14),
              _card('What a score is worth', [
                for (var i = 0; i < _slabs.length; i++) _slabRow(i),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setState(() => _slabs.add({
                          'min_percent': 50,
                          'discount_percent': 10,
                          'label': 'New band'
                        })),
                    icon: const Icon(Icons.add, size: 17),
                    label: const Text('Add a band'),
                  ),
                ),
                Text(
                    'Read top down: a score takes the first band it reaches. '
                    'Below the lowest band there is no award at all.',
                    style: GoogleFonts.inter(
                        fontSize: 11.5,
                        height: 1.45,
                        color: AppColors.textSecondary)),
              ]),
              const SizedBox(height: 14),
              _card('Who has sat it (${_awards.length})', [
                if (_awards.isEmpty)
                  Text('Nobody yet.',
                      style: GoogleFonts.inter(
                          fontSize: 13, color: AppColors.textSecondary))
                else
                  for (final a in _awards)
                    _awardRow(Map<String, dynamic>.from(a as Map)),
              ]),
            ]),
    );
  }

  Widget _card(String title, List<Widget> children) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: GoogleFonts.poppins(
                  fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ...children,
        ]),
      );

  Widget _slabRow(int i) {
    final slab = _slabs[i];
    final off = (slab['discount_percent'] as num?)?.toInt() ?? 0;
    final pay = _baseAmount * (1 - off / 100);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        SizedBox(
          width: 74,
          child: TextFormField(
            initialValue: '${slab['min_percent'] ?? 0}',
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'From %'),
            onChanged: (v) => setState(
                () => slab['min_percent'] = int.tryParse(v.trim()) ?? 0),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 74,
          child: TextFormField(
            initialValue: '$off',
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Off %'),
            onChanged: (v) => setState(
                () => slab['discount_percent'] = int.tryParse(v.trim()) ?? 0),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextFormField(
            initialValue: '${slab['label'] ?? ''}',
            decoration: const InputDecoration(labelText: 'Label'),
            onChanged: (v) => slab['label'] = v,
          ),
        ),
        const SizedBox(width: 8),
        // The rupee figure, so nobody has to work out what a percentage
        // actually costs while deciding it.
        Text('Rs ${pay.toStringAsFixed(0)}',
            style: GoogleFonts.poppins(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.primary)),
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: () => setState(() => _slabs.removeAt(i)),
          icon: const Icon(Icons.close_rounded,
              size: 17, color: AppColors.textSecondary),
        ),
      ]),
    );
  }

  Widget _awardRow(Map<String, dynamic> a) {
    final code = '${a['coupon_code'] ?? ''}';
    final off = (a['discount_percent'] as num?)?.toInt() ?? 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(children: [
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${a['name'] ?? 'Unknown'}',
                    style: GoogleFonts.inter(
                        fontSize: 13.5, fontWeight: FontWeight.w600)),
                Text(
                    '${a['percent'] ?? 0}% · ${a['phone'] ?? ''}'
                    '${'${a['college'] ?? ''}'.isEmpty ? '' : ' · ${a['college']}'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                        fontSize: 11.5, color: AppColors.textSecondary)),
              ]),
        ),
        if (off > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20)),
            child: Text('$off% off',
                style: GoogleFonts.inter(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.success)),
          )
        else
          Text('no award',
              style: GoogleFonts.inter(
                  fontSize: 11, color: AppColors.textSecondary)),
        if (code.isNotEmpty)
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Copy $code',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$code copied')));
            },
            icon: const Icon(Icons.copy_rounded,
                size: 15, color: AppColors.textSecondary),
          ),
      ]),
    );
  }
}
