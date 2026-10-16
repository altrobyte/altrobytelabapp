// How learners are getting on with the AI Trainer: the funnel (opened → ready → started → first checked step → finished)
// and one row per learner with how far they got, where they are stuck, and how often they asked for help. The numbers V1
// is judged by; until the mentor page of V1.1 it is also where a mentor sees who needs a call.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../constants/app_colors.dart';
import '../../services/api_service.dart';

class TrainerUsageScreen extends StatefulWidget {
  const TrainerUsageScreen({super.key});

  @override
  State<TrainerUsageScreen> createState() => _TrainerUsageScreenState();
}

class _TrainerUsageScreenState extends State<TrainerUsageScreen> {
  int _days = 7;
  Map<String, dynamic>? _data;
  Map<String, dynamic>? _classes; // module notes turned into live classes
  String? _problem;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _problem = null;
    });
    try {
      _data = await ApiService.trainerUsage(_days);
      try {
        _classes = await ApiService.classNotesStatus();
      } catch (_) {
        _classes = null; // the usage numbers still show
      }
    } catch (e) {
      _problem = e is ApiException ? e.message : 'Could not load the numbers. Try again.';
    }
    if (mounted) setState(() => _loading = false);
  }

  static String _when(String? iso) {
    final d = DateTime.tryParse(iso ?? '')?.toLocal();
    if (d == null) return '—';
    final ago = DateTime.now().difference(d);
    if (ago.inMinutes < 60) return '${ago.inMinutes} min ago';
    if (ago.inHours < 24) return '${ago.inHours} h ago';
    return '${ago.inDays} d ago';
  }

  @override
  Widget build(BuildContext context) {
    final funnel = [for (final f in (_data?['funnel'] as List? ?? const [])) Map<String, dynamic>.from(f as Map)];
    final rows = [for (final r in (_data?['learners'] as List? ?? const [])) Map<String, dynamic>.from(r as Map)];
    final top = funnel.isEmpty ? 0 : ((funnel.first['learners'] as num?) ?? 0).toInt();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: Text('Trainer usage', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 17)),
        actions: [
          SegmentedButton<int>(
            showSelectedIcon: false,
            segments: const [ButtonSegment(value: 1, label: Text('Today')), ButtonSegment(value: 7, label: Text('7 days')), ButtonSegment(value: 30, label: Text('30 days'))],
            selected: {_days},
            onSelectionChanged: (v) {
              _days = v.first;
              _load();
            },
          ),
          IconButton(tooltip: 'Refresh', onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _problem != null
              ? Center(child: Text(_problem!, style: GoogleFonts.inter(color: AppColors.error)))
              : ListView(padding: const EdgeInsets.all(16), children: [
                  Text('Where learners get to', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 10, runSpacing: 10, children: [
                    for (var i = 0; i < funnel.length; i++)
                      Container(
                        width: 190,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.black12)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${funnel[i]['learners']}', style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.primary)),
                          Text('${funnel[i]['step']}', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                          if (i > 0 && top > 0)
                            Text('${(100 * ((funnel[i]['learners'] as num?) ?? 0) / top).round()}% of those who opened',
                                style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.textSecondary)),
                        ]),
                      ),
                  ]),
                  const SizedBox(height: 22),
                  // Module notes turned into live classes on the board, by Claude on the server.
                  if (_classes != null)
                    Builder(builder: (_) {
                      final n = Map<String, dynamic>.from((_classes!['counts'] as Map?) ?? const {});
                      final failed = [for (final f in (_classes!['failed'] as List? ?? const [])) Map<String, dynamic>.from(f as Map)];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: const Color(0xFFEEF4FF), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFC9D8F5))),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Wrap(spacing: 24, runSpacing: 6, children: [
                            Text('Live class versions of notes', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
                            Text('${n['ready'] ?? 0} ready', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.success)),
                            Text('${(n['waiting'] ?? 0) + (n['working'] ?? 0)} waiting', style: GoogleFonts.inter(fontSize: 13)),
                            Text('${n['failed'] ?? 0} failed', style: GoogleFonts.inter(fontSize: 13, color: (n['failed'] ?? 0) > 0 ? AppColors.error : AppColors.textSecondary)),
                            Text(_classes!['worker'] == true ? 'Converting now…' : 'Idle', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                          ]),
                          for (final f in failed.take(5))
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text('• ${f['title']}: ${'${f['class_problems'] ?? ''}'.split('\n').first}',
                                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                            ),
                        ]),
                      );
                    }),
                  // Talk with Altron Live: what it costs, from Google's own counts (or the minutes, when a report never came).
                  Builder(builder: (_) {
                    final live = Map<String, dynamic>.from((_data?['live'] as Map?) ?? const {});
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: const Color(0xFFFFF4EC), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFFFD2B3))),
                      child: Wrap(spacing: 28, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                        Text('Altron Live', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
                        Text('${live['learners'] ?? 0} learners talked', style: GoogleFonts.inter(fontSize: 13)),
                        Text('${live['minutes'] ?? 0} minutes', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                        Text('≈ ₹${live['inr'] ?? 0} in all', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFFB4470A))),
                        Text('≈ ₹${live['inr_per_learner'] ?? 0} per learner', style: GoogleFonts.inter(fontSize: 13)),
                        Text('Estimate at Google list prices; the Google Cloud bill is the final word.',
                            style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.textSecondary)),
                      ]),
                    );
                  }),
                  const SizedBox(height: 22),
                  Text('Learners (${rows.length})', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text('Most recent first. Someone who asked for help or is stuck on the same step for long needs a call.',
                      style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textSecondary)),
                  const SizedBox(height: 10),
                  if (rows.isEmpty)
                    Text('Nobody has used the trainer in this period yet.', style: GoogleFonts.inter(color: AppColors.textSecondary))
                  else
                    Container(
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.black12)),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingTextStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                          dataTextStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.textPrimary),
                          columns: const [
                            DataColumn(label: Text('Learner')),
                            DataColumn(label: Text('Got to')),
                            DataColumn(label: Text('Best lesson')),
                            DataColumn(label: Text('Stuck at')),
                            DataColumn(label: Text('Help'), numeric: true),
                            DataColumn(label: Text('Altron Live'), numeric: true),
                            DataColumn(label: Text('Last seen')),
                            DataColumn(label: Text('Last thing they did')),
                          ],
                          rows: [
                            for (final r in rows)
                              DataRow(cells: [
                                DataCell(Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text('${(r['name'] as String?)?.isNotEmpty == true ? r['name'] : r['key']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                                  if ('${r['phone'] ?? ''}'.isNotEmpty) Text('${r['phone']}', style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.textSecondary)),
                                ])),
                                DataCell(Text('${r['furthest'] ?? ''}')),
                                DataCell(Text(r['best'] == null ? '—' : '${r['best']['lesson']} · ${r['best']['done']}/${r['best']['total']}')),
                                DataCell(Text(r['best'] == null ? '—' : '${r['best']['stuck_at'] ?? ''}')),
                                DataCell(Text('${r['help'] ?? 0}',
                                    style: TextStyle(fontWeight: FontWeight.w700, color: (r['help'] ?? 0) > 0 ? AppColors.error : AppColors.textSecondary))),
                                DataCell(Text((r['live_minutes'] ?? 0) == 0 ? '—' : '${r['live_minutes']} min · ₹${r['live_inr'] ?? 0}')),
                                DataCell(Text(_when(r['last_seen'] as String?))),
                                DataCell(ConstrainedBox(constraints: const BoxConstraints(maxWidth: 320), child: Text('${r['last_event'] ?? ''}', overflow: TextOverflow.ellipsis))),
                              ]),
                          ],
                        ),
                      ),
                    ),
                ]),
    );
  }
}
