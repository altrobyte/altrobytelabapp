import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_colors.dart';
import 'caller_controller.dart';
import 'lead_screen.dart';
import 'models.dart';
import 'queue_order.dart';
import 'widgets.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<CallerController>();
    final now = c.now;
    final rows = <Widget>[];
    String? last;
    for (final l in c.leads) {
      final b = bucketOf(l, now);
      if (b != last) {
        rows.add(_Header(bucketTitles[b] ?? b, c.leads.where((x) => bucketOf(x, now) == b).length, key: ValueKey('h_$b')));
        last = b;
      }
      rows.add(LeadCard(l, now: now, key: ValueKey('lead_${l.phone}')));
    }
    return RefreshIndicator(
      onRefresh: c.refresh,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          if (c.offline || c.outbox.length > 0) _SyncBar(waiting: c.outbox.length, offline: c.offline),
          if (c.leads.isEmpty)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Text(c.syncing ? 'Getting your leads…' : 'No leads given to you yet. Pull down to check again.',
                  textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary, fontSize: 15)),
            ),
          ...rows,
        ],
      ),
    );
  }
}

class _SyncBar extends StatelessWidget {
  final int waiting;
  final bool offline;
  const _SyncBar({required this.waiting, required this.offline});

  @override
  Widget build(BuildContext context) => Container(
        color: AppColors.warning.withValues(alpha: 0.15),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(children: [
          const Icon(Icons.cloud_off, size: 18, color: AppColors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              waiting > 0
                  ? '$waiting call log${waiting == 1 ? '' : 's'} saved on the phone, will sync when there is internet.'
                  : 'No internet. Showing your leads from the last sync.',
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ]),
      );
}

class _Header extends StatelessWidget {
  final String title;
  final int count;
  const _Header(this.title, this.count, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text('$title  ·  $count',
            style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.textSecondary, fontSize: 13)),
      );
}

class LeadCard extends StatelessWidget {
  final Lead lead;
  final DateTime now;
  const LeadCard(this.lead, {super.key, required this.now});

  @override
  Widget build(BuildContext context) {
    final c = context.read<CallerController>();
    final f = lead.nextFollowupAt;
    final due = f != null && !f.isAfter(now);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      color: AppColors.cardBg,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => LeadScreen(phone: lead.phone))),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(lead.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(height: 5),
                Wrap(spacing: 6, runSpacing: 4, children: [
                  HeatBadge(lead.heat, converted: lead.converted),
                  Tag(stages[lead.stage] ?? lead.stage),
                  for (final l in lead.labels) Tag(l, color: AppColors.textSecondary),
                ]),
                if (lead.lastNote.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(lead.lastNote,
                      maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary)),
                ],
                if (f != null) ...[
                  const SizedBox(height: 6),
                  Row(children: [
                    Icon(Icons.alarm, size: 15, color: due ? AppColors.error : AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text('${due ? 'Due' : 'Next'} ${CallerController.when(f)}',
                        style: TextStyle(
                            fontSize: 13, color: due ? AppColors.error : AppColors.textSecondary, fontWeight: FontWeight.w600)),
                  ]),
                ],
              ]),
            ),
            IconButton.filled(
              key: ValueKey('call_${lead.phone}'),
              tooltip: 'Call',
              style: IconButton.styleFrom(backgroundColor: AppColors.success, minimumSize: const Size(52, 52)),
              icon: const Icon(Icons.call, color: Colors.white),
              onPressed: () => c.call(lead),
            ),
          ]),
        ),
      ),
    );
  }
}
