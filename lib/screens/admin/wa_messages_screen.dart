// What WhatsApp messages this platform sends, and what it actually sent.
//
// Two tabs because they answer two questions. "Rules" is what a student will
// receive and when — a property of the code. "Sent" is whether it happened —
// a property of the log. An admin who only has the second cannot tell a quiet
// day from a broken trigger.
//
// Read-only. Composing and replying live on the WhatsApp dashboard.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../services/api_service.dart';

class WaMessagesScreen extends StatefulWidget {
  const WaMessagesScreen({super.key});

  @override
  State<WaMessagesScreen> createState() => _WaMessagesScreenState();
}

class _WaMessagesScreenState extends State<WaMessagesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  Map<String, dynamic> _data = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      _data = await ApiService.waOverview();
    } catch (_) {
      _data = {};
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final counts = Map<String, dynamic>.from(_data['counts'] ?? {});
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        // The theme paints AppBar foreground white for the dark bars used
        // elsewhere; on a white bar that hides the title and every action.
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: Text('WhatsApp messages',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 17)),
        actions: [
          IconButton(
              onPressed: () {
                setState(() => _loading = true);
                _load();
              },
              icon: const Icon(Icons.refresh_rounded, size: 21)),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: const [Tab(text: 'What gets sent'), Tab(text: 'Actually sent')],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                child: Row(children: [
                  _Stat(label: 'Last 24h', value: '${counts['d1'] ?? 0}'),
                  _Stat(label: 'Last 7 days', value: '${counts['d7'] ?? 0}'),
                  _Stat(label: 'All time', value: '${counts['total'] ?? 0}'),
                  _Stat(
                      label: 'Failed',
                      value: '${counts['failed'] ?? 0}',
                      warn: (counts['failed'] ?? 0) is int &&
                          (counts['failed'] ?? 0) > 0),
                ]),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  children: [_rules(), _sent()],
                ),
              ),
            ]),
    );
  }

  Widget _rules() {
    final triggers = (_data['triggers'] as List?) ?? [];
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: triggers.length,
        separatorBuilder: (_, __) => const SizedBox(height: 9),
        itemBuilder: (context, i) =>
            _TriggerCard(trigger: triggers[i] as Map<String, dynamic>),
      ),
    );
  }

  Widget _sent() {
    final sent = (_data['sent'] as List?) ?? [];
    final scheduled = (_data['scheduled'] as List?) ?? [];
    if (sent.isEmpty && scheduled.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'Nothing has gone out yet. Messages appear here the moment a '
            'trigger fires — a signup, a payment, or the hourly sweep.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: AppColors.textSecondary, height: 1.5),
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.all(12), children: [
        if (scheduled.isNotEmpty) ...[
          _heading('Scheduled sends', 'Reminders and deadline nudges'),
          for (final s in scheduled)
            _ScheduledRow(row: s as Map<String, dynamic>),
          const SizedBox(height: 18),
        ],
        if (sent.isNotEmpty) ...[
          _heading('All outgoing', 'Everything this platform sent'),
          for (final m in sent) _SentRow(row: m as Map<String, dynamic>),
        ],
      ]),
    );
  }

  Widget _heading(String title, String sub) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 2),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.w600)),
          Text(sub,
              style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
        ]),
      );
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final bool warn;
  const _Stat({required this.label, required this.value, this.warn = false});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Text(value,
              style: GoogleFonts.poppins(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: warn ? AppColors.error : AppColors.textPrimary)),
          Text(label,
              style: GoogleFonts.inter(fontSize: 10.5, color: AppColors.textSecondary)),
        ]),
      );
}

class _TriggerCard extends StatelessWidget {
  final Map<String, dynamic> trigger;
  const _TriggerCard({required this.trigger});

  @override
  Widget build(BuildContext context) {
    final status = trigger['status'] as String? ?? '';
    final category = trigger['category'] as String? ?? '';
    final fires = trigger['trigger'] as String? ?? '';
    final isMarketing = category == 'marketing';

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withValues(alpha: 0.07)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(trigger['name'] as String? ?? '',
                style: GoogleFonts.poppins(
                    fontSize: 14, fontWeight: FontWeight.w600)),
          ),
          if (status == 'fallback')
            _Pill(
              text: 'PLAIN TEXT',
              color: const Color(0xFFE65100),
            )
          else if (status == 'live')
            _Pill(text: 'LIVE', color: AppColors.success),
        ]),
        const SizedBox(height: 5),
        Text(trigger['when'] as String? ?? '',
            style: GoogleFonts.inter(
                fontSize: 12, height: 1.4, color: AppColors.textSecondary)),
        const SizedBox(height: 9),
        Wrap(spacing: 6, runSpacing: 6, children: [
          _Pill(
            text: fires.toUpperCase(),
            color: fires == 'manual'
                ? AppColors.textSecondary
                : const Color(0xFF0277BD),
          ),
          _Pill(
            text: category.toUpperCase(),
            // Marketing is the one that needs opt-in, so it is the one worth
            // spotting on a list.
            color: isMarketing ? const Color(0xFF6A1B9A) : AppColors.textSecondary,
          ),
          if ((trigger['template'] as String? ?? '').isNotEmpty)
            _Pill(text: trigger['template'] as String, color: AppColors.primary),
        ]),
        if (status == 'fallback') ...[
          const SizedBox(height: 8),
          Text(
            'Meta has not approved ${trigger['intended_template'] ?? 'the template'} '
            'yet, so this goes out as a plain update. Turn the switch on in '
            'Settings once it is approved.',
            style: GoogleFonts.inter(
                fontSize: 11, height: 1.4, color: const Color(0xFFE65100)),
          ),
        ],
        if (isMarketing) ...[
          const SizedBox(height: 6),
          Text('Only reaches people who opted in.',
              style: GoogleFonts.inter(
                  fontSize: 11, color: AppColors.textSecondary)),
        ],
      ]),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color color;
  const _Pill({required this.text, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.11),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(text,
            style: GoogleFonts.inter(
                fontSize: 8.5, fontWeight: FontWeight.w700, color: color)),
      );
}

class _SentRow extends StatelessWidget {
  final Map<String, dynamic> row;
  const _SentRow({required this.row});

  @override
  Widget build(BuildContext context) {
    final when = '${row['created_at'] ?? ''}'.replaceFirst('T', '  ').split('.').first;
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(
                (row['name'] as String?)?.isNotEmpty == true
                    ? '${row['name']}  ·  ${row['phone']}'
                    : '${row['phone']}',
                style: GoogleFonts.inter(
                    fontSize: 12.5, fontWeight: FontWeight.w600)),
          ),
          Text(when,
              style: GoogleFonts.inter(fontSize: 10, color: AppColors.textSecondary)),
        ]),
        const SizedBox(height: 3),
        Text('${row['body'] ?? ''}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
                fontSize: 11.5, height: 1.35, color: AppColors.textSecondary)),
      ]),
    );
  }
}

class _ScheduledRow extends StatelessWidget {
  final Map<String, dynamic> row;
  const _ScheduledRow({required this.row});

  static const _kindNames = {
    'workshop_reminder': 'Workshop reminder',
    'challenge_deadline': 'Deadline nudge',
  };

  @override
  Widget build(BuildContext context) {
    final status = row['status'] as String? ?? '';
    final failed = status == 'failed';
    final when = '${row['created_at'] ?? ''}'.replaceFirst('T', '  ').split('.').first;

    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: failed
                ? AppColors.error.withValues(alpha: 0.35)
                : Colors.black.withValues(alpha: 0.06)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(
                '${_kindNames[row['kind']] ?? row['kind']}  ·  ${row['phone']}',
                style: GoogleFonts.inter(
                    fontSize: 12.5, fontWeight: FontWeight.w600)),
          ),
          _Pill(
              text: status.toUpperCase(),
              color: failed ? AppColors.error : AppColors.success),
        ]),
        const SizedBox(height: 3),
        Text(when,
            style: GoogleFonts.inter(fontSize: 10, color: AppColors.textSecondary)),
        if (failed && (row['detail'] as String? ?? '').isNotEmpty) ...[
          const SizedBox(height: 4),
          Text('${row['detail']}',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                  fontSize: 10.5, height: 1.35, color: AppColors.error)),
        ],
      ]),
    );
  }
}
