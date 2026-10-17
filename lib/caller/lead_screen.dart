// One lead: who they are, and everything that happened with them in order (calls, notes, WhatsApp).

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_colors.dart';
import 'caller_api.dart';
import 'caller_controller.dart';
import 'models.dart';
import 'widgets.dart';

class LeadScreen extends StatefulWidget {
  final String phone;
  const LeadScreen({super.key, required this.phone});

  @override
  State<LeadScreen> createState() => _LeadScreenState();
}

class _LeadScreenState extends State<LeadScreen> {
  Map<String, dynamic>? _data;
  String? _problem;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _problem = null);
    try {
      final d = await context.read<CallerController>().api.timeline(widget.phone);
      if (mounted) setState(() => _data = d);
    } on CallerError catch (e) {
      if (mounted) setState(() => _problem = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<CallerController>();
    final lead = _data == null
        ? (c.leadFor(widget.phone) ?? Lead(phone: widget.phone))
        : Lead.fromJson((_data!['lead'] as Map).cast<String, dynamic>());
    final events = ((_data?['events'] as List?) ?? const []).map((e) => (e as Map).cast<String, dynamic>()).toList();
    final next = '${_data?['next_step'] ?? ''}';
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(lead.displayName), backgroundColor: AppColors.primary, foregroundColor: Colors.white),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.success,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.call),
        label: const Text('Call'),
        onPressed: () => c.call(lead),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 90), children: [
          Wrap(spacing: 6, runSpacing: 6, children: [
            HeatBadge(lead.heat, converted: lead.converted),
            Tag(stages[lead.stage] ?? lead.stage),
            for (final l in lead.labels) Tag(l, color: AppColors.textSecondary),
          ]),
          const SizedBox(height: 8),
          Text(lead.phone, style: const TextStyle(color: AppColors.textSecondary)),
          if (lead.converted && lead.creditedTo.isNotEmpty)
            Text('Converted, credited to ${lead.creditedTo}', style: const TextStyle(color: AppColors.success)),
          for (final r in lead.heat.reasons)
            Text('• $r', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          if (next.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('Next: $next', style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => c.logByHand(lead),
            icon: const Icon(Icons.edit_note),
            label: const Text('Log a call by hand'),
          ),
          const Divider(height: 28),
          if (_problem != null)
            Column(children: [
              Text(_problem!, textAlign: TextAlign.center),
              TextButton(onPressed: _load, child: const Text('Try again')),
            ])
          else if (_data == null)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
          else if (events.isEmpty)
            const Text('Nothing yet.', style: TextStyle(color: AppColors.textSecondary))
          else
            for (final e in events) _Event(e),
        ]),
      ),
    );
  }
}

class _Event extends StatelessWidget {
  final Map<String, dynamic> e;
  const _Event(this.e);

  @override
  Widget build(BuildContext context) {
    final at = DateTime.tryParse('${e['at'] ?? ''}');
    final when = at == null ? '' : CallerController.when(at);
    late final IconData icon;
    late final String title;
    var body = '${e['text'] ?? ''}';
    switch (e['kind']) {
      case 'call':
        icon = e['direction'] == 'in' ? Icons.call_received : Icons.call_made;
        final bits = [
          outcomes[e['outcome']] ?? '${e['outcome']}',
          if ((e['duration_s'] ?? 0) > 0) duration((e['duration_s'] as num).toInt()),
          if ('${e['interest']}'.isNotEmpty) interests[e['interest']] ?? '${e['interest']}',
          if ('${e['stage_after']}'.isNotEmpty) '→ ${stages[e['stage_after']] ?? e['stage_after']}',
        ];
        title = '${bits.join(' · ')}  —  ${e['by'] ?? ''}';
        if ('${e['lost_reason']}'.isNotEmpty) body = 'Lost: ${e['lost_reason']}${body.isEmpty ? '' : '. $body'}';
      case 'note':
        icon = Icons.sticky_note_2_outlined;
        title = 'Note — ${e['by'] ?? ''}';
      default:
        icon = Icons.chat_outlined;
        title = e['direction'] == 'in' ? 'WhatsApp from them' : 'WhatsApp from us';
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 20, color: e['kind'] == 'whatsapp' ? AppColors.whatsapp : AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            if (body.isNotEmpty) Text(body),
            Text(when, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ]),
        ),
      ]),
    );
  }
}
