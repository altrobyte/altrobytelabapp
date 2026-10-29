// The CRM's WhatsApp automation in one place (25 Oct 2026): the automatic follow-ups (on/off and their words), the bulk
// messages waiting to go, and Altron the WhatsApp counsellor (its switch, the test numbers, where hot-lead alerts go,
// and a try-box that runs a made-up conversation without sending anything).

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../services/api_service.dart';

/// The website funnel, the number to watch every day (29 Oct 2026): visitors on /learn, free weeks started, the plans
/// page, taps on a plan, and how many free-week people pay now. Free-week people are CRM leads with a follow-up.
class _FunnelTab extends StatefulWidget {
  const _FunnelTab();

  @override
  State<_FunnelTab> createState() => _FunnelTabState();
}

class _FunnelTabState extends State<_FunnelTab> {
  int _days = 7;
  Map<String, dynamic>? _f;
  String? _err;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _err = null);
    try {
      final f = await ApiService.salesFunnel(_days);
      if (mounted) setState(() => _f = f);
    } catch (_) {
      if (mounted) setState(() => _err = 'Could not load the funnel. Pull to try again.');
    }
  }

  Widget _step(String label, Object? n, IconData icon) => Expanded(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(icon, color: const Color(0xFF1A3C5E)),
              const SizedBox(height: 8),
              Text('${n ?? 0}', style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w700)),
              Text(label, style: GoogleFonts.inter(fontSize: 12.5, color: Colors.black54)),
            ]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final f = _f;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.all(18), children: [
        Row(children: [
          Text('Last', style: GoogleFonts.inter()),
          const SizedBox(width: 8),
          for (final d in const [1, 7, 30])
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                  label: Text(d == 1 ? 'today' : '$d days'),
                  selected: _days == d,
                  onSelected: (_) {
                    _days = d;
                    _load();
                  }),
            ),
        ]),
        const SizedBox(height: 12),
        if (_err != null) Text(_err!, style: const TextStyle(color: Colors.red)),
        if (f == null && _err == null) const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator())),
        if (f != null) ...[
          Row(children: [
            _step('saw the roadmap', f['learn_views'], Icons.map_rounded),
            _step('started the free week', f['trials_started'], Icons.rocket_launch_rounded),
            _step('saw the plans', f['unlock_views'], Icons.sell_rounded),
          ]),
          Row(children: [
            _step('tapped a plan', f['plan_clicks'], Icons.touch_app_rounded),
            _step('pay now (after the free week)', f['paid_after_trial'], Icons.currency_rupee_rounded),
            const Expanded(child: SizedBox()),
          ]),
          const SizedBox(height: 14),
          Text('Plans asked about', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          if ((f['plans'] as List? ?? []).isEmpty) const Text('None yet.'),
          for (final p in (f['plans'] as List? ?? []))
            ListTile(dense: true, title: Text('${p['plan']}'), trailing: Text('${p['visitors']}')),
          const SizedBox(height: 10),
          Text('Everyone who starts the free week is in the CRM as "interested" (source web_trial), with a follow-up the '
              'day before their week ends. Nothing is sent to them automatically.',
              style: GoogleFonts.inter(fontSize: 12.5, color: Colors.black54)),
        ],
      ]),
    );
  }
}

class CrmAutomationScreen extends StatelessWidget {
  const CrmAutomationScreen({super.key});

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 4,
        child: Scaffold(
          appBar: AppBar(
            title: Text('WhatsApp automation', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 17)),
            bottom: const TabBar(isScrollable: true, tabs: [
              Tab(text: 'Website funnel'),
              Tab(text: 'Auto messages'),
              Tab(text: 'Scheduled'),
              Tab(text: 'Altron counsellor'),
            ]),
          ),
          body: const TabBarView(children: [_FunnelTab(), _AutoTab(), _JobsTab(), _CounselTab()]),
        ),
      );
}

Widget _wide(Widget child) => Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 860), child: child));

void _toast(BuildContext context, String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

String _problem(Object e) => e.toString().replaceFirst('Exception: ', '');

// ── automatic follow-ups ──

class _AutoTab extends StatefulWidget {
  const _AutoTab();

  @override
  State<_AutoTab> createState() => _AutoTabState();
}

class _AutoTabState extends State<_AutoTab> {
  List<Map<String, dynamic>>? _seqs;
  final Map<String, TextEditingController> _boxes = {};
  final Set<String> _saving = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _boxes.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await ApiService.crmAuto();
      _seqs = [for (final s in (r['sequences'] as List)) Map<String, dynamic>.from(s as Map)];
      for (final s in _seqs!) {
        for (final st in (s['steps'] as List)) {
          final k = '${s['id']}/${st['key']}';
          (_boxes[k] ??= TextEditingController()).text = '${st['text']}';
        }
      }
    } catch (e) {
      if (mounted) _toast(context, 'Could not load: ${_problem(e)}');
      _seqs ??= [];
    }
    if (mounted) setState(() {});
  }

  Future<void> _save(Map<String, dynamic> s, bool on) async {
    final id = '${s['id']}';
    setState(() => _saving.add(id));
    try {
      await ApiService.crmAutoSet(id, on, {for (final st in (s['steps'] as List)) '${st['key']}': _boxes['$id/${st['key']}']!.text.trim()});
      if (mounted) _toast(context, on ? '"${s['title']}" is ON' : '"${s['title']}" saved (off)');
      await _load();
    } catch (e) {
      if (mounted) _toast(context, 'Not saved: ${_problem(e)}');
    }
    if (mounted) setState(() => _saving.remove(id));
  }

  @override
  Widget build(BuildContext context) {
    final seqs = _seqs;
    if (seqs == null) return const Center(child: CircularProgressIndicator());
    return _wide(ListView(padding: const EdgeInsets.all(18), children: [
      Text('Each message starts "Hi <their first name>," and goes as the approved update template, so it arrives even '
          'outside the 24-hour window. A STOP is respected. {booking} = the Rs 999 seat link, {demo} = their own roadmap + demo link.',
          style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textSecondary, height: 1.4)),
      const SizedBox(height: 14),
      for (final s in seqs)
        Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: Colors.black.withValues(alpha: 0.08))),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${s['title']}', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
                    Text('${s['who']}', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                  ]),
                ),
                Switch(
                  value: s['on'] == true,
                  onChanged: _saving.contains(s['id']) ? null : (v) => _save(s, v),
                ),
              ]),
              for (final st in (s['steps'] as List)) ...[
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: Text('${st['when']}', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12.5))),
                  Text('sent ${st['sent']}', style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.textSecondary)),
                ]),
                const SizedBox(height: 6),
                TextField(
                  controller: _boxes['${s['id']}/${st['key']}'],
                  maxLines: 3,
                  maxLength: 800,
                  decoration: InputDecoration(border: const OutlineInputBorder(), isDense: true, prefixText: 'Hi Asha, ',
                      prefixStyle: GoogleFonts.inter(color: AppColors.textSecondary)),
                ),
              ],
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: _saving.contains(s['id']) ? null : () => _save(s, s['on'] == true), child: const Text('Save words')),
              ),
            ]),
          ),
        ),
    ]));
  }
}

// ── scheduled bulk ──

class _JobsTab extends StatefulWidget {
  const _JobsTab();

  @override
  State<_JobsTab> createState() => _JobsTabState();
}

class _JobsTabState extends State<_JobsTab> {
  List<dynamic>? _jobs;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _jobs = (await ApiService.crmBulkJobs())['jobs'] as List? ?? [];
    } catch (e) {
      _jobs ??= [];
      if (mounted) _toast(context, 'Could not load: ${_problem(e)}');
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final jobs = _jobs;
    if (jobs == null) return const Center(child: CircularProgressIndicator());
    if (jobs.isEmpty) {
      return Center(
          child: Text('Nothing scheduled. In the CRM list, "WhatsApp these" → "Send later".',
              style: GoogleFonts.inter(color: AppColors.textSecondary)));
    }
    return _wide(RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.all(18), children: [
        for (final j in jobs)
          ListTile(
            leading: Icon(j['status'] == 'waiting' ? Icons.schedule_rounded : Icons.check_circle_rounded,
                color: j['status'] == 'waiting' ? AppColors.accent : AppColors.success),
            title: Text('${j['text']}', maxLines: 2, overflow: TextOverflow.ellipsis),
            subtitle: Text('${j['people']} people · ${_when('${j['send_at']}')} · ${j['status']}'),
            trailing: j['status'] == 'waiting'
                ? TextButton(
                    onPressed: () async {
                      try {
                        await ApiService.crmBulkCancel(j['id'] as int);
                        await _load();
                      } catch (e) {
                        if (context.mounted) _toast(context, _problem(e));
                      }
                    },
                    child: const Text('Cancel'))
                : null,
          ),
      ]),
    ));
  }
}

String _when(String iso) {
  final d = DateTime.tryParse(iso)?.toLocal();
  if (d == null) return iso;
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '${d.day}/${d.month} $h:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'AM' : 'PM'}';
}

// ── Altron the counsellor ──

class _CounselTab extends StatefulWidget {
  const _CounselTab();

  @override
  State<_CounselTab> createState() => _CounselTabState();
}

class _CounselTabState extends State<_CounselTab> {
  final _test = TextEditingController();
  final _alerts = TextEditingController();
  final _try = TextEditingController(text: 'Hi, roadmap chahiye\nmain 3rd year ECE student hu, job chahiye\nfees kitni hai?');
  bool _on = true;
  bool _loaded = false;
  bool _trying = false;
  List<dynamic> _turns = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _test.dispose();
    _alerts.dispose();
    _try.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      for (final s in await ApiService.getAdminSettings()) {
        final m = Map<String, dynamic>.from(s as Map);
        final v = '${m['value'] ?? ''}';
        if (m['key'] == 'counsel_test_phones') _test.text = v;
        if (m['key'] == 'sales_alert_phones') _alerts.text = v;
        if (m['key'] == 'counsel_enabled') _on = v != 'off';
      }
    } catch (_) {}
    if (mounted) setState(() => _loaded = true);
  }

  Future<void> _set(String key, String value, String done) async {
    try {
      await ApiService.setAdminSetting(key, value);
      if (mounted) _toast(context, done);
    } catch (e) {
      if (mounted) _toast(context, 'Not saved: ${_problem(e)}');
    }
  }

  Future<void> _run() async {
    final lines = _try.text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    if (lines.isEmpty) return;
    setState(() {
      _trying = true;
      _turns = [];
    });
    try {
      _turns = (await ApiService.crmCounselTry(lines))['turns'] as List? ?? [];
    } catch (e) {
      if (mounted) _toast(context, 'Could not try: ${_problem(e)}');
    }
    if (mounted) setState(() => _trying = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const Center(child: CircularProgressIndicator());
    return _wide(ListView(padding: const EdgeInsets.all(18), children: [
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text('Altron answers leads on the Altron number', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14.5)),
        subtitle: const Text('It also needs "AI agent" on for the number in the WhatsApp dashboard. Off here = never answers.'),
        value: _on,
        onChanged: (v) {
          setState(() => _on = v);
          _set('counsel_enabled', v ? 'on' : 'off', v ? 'Counsellor on' : 'Counsellor off');
        },
      ),
      const SizedBox(height: 8),
      Text('Test numbers (answered while the agent is off in the dashboard)', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
      const SizedBox(height: 6),
      Row(children: [
        Expanded(child: TextField(controller: _test, decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true, hintText: '9876543210, 9123456789'))),
        const SizedBox(width: 8),
        FilledButton(onPressed: () => _set('counsel_test_phones', _test.text.trim(), 'Test numbers saved'), child: const Text('Save')),
      ]),
      const SizedBox(height: 14),
      Text('Hot-lead alerts go to', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
      const SizedBox(height: 6),
      Row(children: [
        Expanded(child: TextField(controller: _alerts, decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true, hintText: 'Empty = 7222977927'))),
        const SizedBox(width: 8),
        FilledButton(onPressed: () => _set('sales_alert_phones', _alerts.text.trim(), 'Alert numbers saved'), child: const Text('Save')),
      ]),
      const Divider(height: 34),
      Text('Try a conversation (nothing is sent, nothing saved)', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14.5)),
      const SizedBox(height: 4),
      Text('One line = one message from the lead.', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
      const SizedBox(height: 8),
      TextField(controller: _try, maxLines: 5, decoration: const InputDecoration(border: OutlineInputBorder())),
      const SizedBox(height: 8),
      Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.icon(
            onPressed: _trying ? null : _run,
            icon: _trying ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.play_arrow_rounded),
            label: Text(_trying ? 'Altron is thinking…' : 'Try')),
      ),
      const SizedBox(height: 12),
      for (final t in _turns) ...[
        Align(alignment: Alignment.centerLeft, child: _bubble('${t['them']}', Colors.white)),
        Align(alignment: Alignment.centerRight, child: _bubble('${t['altron']}', const Color(0xFFDCF8C6))),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
              [t['temperature'], if (t['handoff'] == true) '→ team', if ('${t['plan']}'.isNotEmpty) 'plan: ${t['plan']}', t['note']].join(' · '),
              style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
        ),
        const SizedBox(height: 10),
      ],
    ]));
  }

  Widget _bubble(String text, Color color) => Container(
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.all(10),
        constraints: const BoxConstraints(maxWidth: 560),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.black12)),
        child: Text(text, style: GoogleFonts.inter(fontSize: 13)),
      );
}
