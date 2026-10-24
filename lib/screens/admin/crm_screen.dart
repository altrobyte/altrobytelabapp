// EdTech CRM — the pipeline over WhatsApp contacts.
//
// Not an inbox. Chats, templates and broadcast live on the altronbotsaas
// dashboard; this owns the part that is EdTech's alone — which lead is at what
// stage, who owns them, what was said about them, and whether they became a
// student. Conversation history appears read-only, as context for that
// decision.

import '../../widgets/lead_import_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/api_service.dart';
import 'crm_automation_screen.dart';
import 'founder_altron_screen.dart';
import 'crm_chat_screen.dart';
import 'crm_team_screen.dart';

const _stageLabels = {
  'new': 'New',
  'contacted': 'Contacted',
  'interested': 'Interested',
  'demo_booked': 'Demo booked',
  'demo_done': 'Demo done',
  'token_paid': 'Token paid',
  'enrolled': 'Enrolled',
  'lost': 'Lost',
};

const _stageColors = {
  'new': Color(0xFF757575),
  'contacted': Color(0xFF0277BD),
  'interested': Color(0xFF6A1B9A),
  'demo_booked': Color(0xFFAD1457),
  'demo_done': Color(0xFFE65100),
  'token_paid': Color(0xFF00838F),
  'enrolled': Color(0xFF2E7D32),
  'lost': Color(0xFFB71C1C),
};

class CrmScreen extends StatefulWidget {
  const CrmScreen({super.key});

  @override
  State<CrmScreen> createState() => _CrmScreenState();
}

class _CrmScreenState extends State<CrmScreen> {
  List<dynamic> _leads = [];
  Map<String, dynamic> _counts = {};
  Map<String, dynamic> _summary = {};
  String _stage = '';
  String _heat = '';
  Map<String, dynamic> _heatCounts = {};
  Map<String, dynamic> _funnel = {};
  bool _needsCall = false;
  bool _recent = true; // the funnel for the last 30 days, or for everyone
  bool _showPipeline = false; // the list comes first; the pipeline and totals open on a tap
  Map<String, dynamic> _activity = {}; // phone -> what they did, newest first
  Map<String, dynamic> _didCounts = {};
  String _did = ''; // show only people who did this
  String _query = '';
  bool _loading = true;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    // First: it also adds everyone who registered or filled the form, so they are in the list that follows.
    try {
      final a = await ApiService.crmActivity();
      _activity = Map<String, dynamic>.from(a['activity'] ?? {});
      _didCounts = Map<String, dynamic>.from(a['counts'] ?? {});
    } catch (_) {}
    try {
      final res = await ApiService.crmLeads(stage: _stage, q: _query, heat: _heat, needsCall: _needsCall);
      _leads = (res['leads'] as List?) ?? [];
      _counts = Map<String, dynamic>.from(res['counts'] ?? {});
      _heatCounts = Map<String, dynamic>.from(res['heat_counts'] ?? {});
      _funnel = Map<String, dynamic>.from(res['funnel'] ?? {});
    } catch (_) {
      _leads = [];
    }
    try {
      _summary = await ApiService.crmSummary();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _open(Map<String, dynamic> lead) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => LeadDetailScreen(phone: lead['phone'] as String)),
    );
    if (changed == true) {
      setState(() => _loading = true);
      await _load();
    }
  }

  // The same person saved under two forms of one number. The server has already put their details on one contact and
  // hides the other; this removes the hidden copies, after saying how many there are.
  Future<void> _cleanDuplicates() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final found = await ApiService.crmDuplicates();
      final n = (found['duplicates'] as num?)?.toInt() ?? 0;
      if (!mounted) return;
      if (n == 0) {
        messenger.showSnackBar(const SnackBar(content: Text('No duplicate contacts.')));
        return;
      }
      final yes = await showDialog<bool>(
          context: context,
          builder: (d) => AlertDialog(
                title: Text('$n duplicate contact${n == 1 ? '' : 's'}'),
                content: const Text('These are second copies of people already in the list, saved under the other form of '
                    'their number. Their name, stage, owner and consent are already on the contact that stays. '
                    'Removing the copies cannot be undone.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Keep them')),
                  FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Remove copies')),
                ],
              ));
      if (yes != true) return;
      final done = await ApiService.crmDuplicates(remove: true);
      messenger.showSnackBar(SnackBar(content: Text('Removed ${done['removed'] ?? 0} duplicate contacts.')));
      if (!mounted) return;
      setState(() => _loading = true);
      _load();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not check for duplicates. ${'$e'.replaceFirst('Exception: ', '')}')));
    }
  }

  // The pipeline at a glance: how many came in, how many we spoke to, how many are interested and how many paid, and the
  // people who are warm or hot and still waiting for a first call.
  Widget _funnelCard() {
    final f = Map<String, dynamic>.from((_funnel[_recent ? 'recent' : 'all'] as Map?) ?? const {});
    if (f.isEmpty) return const SizedBox.shrink();
    final leads = (f['leads'] as num?)?.toInt() ?? 0;
    String pct(String k) => leads == 0 ? '' : ' · ${(100 * ((f[k] as num?) ?? 0) / leads).round()}%';
    final steps = [('Leads', 'leads'), ('Contacted', 'contacted'), ('Interested', 'interested'), ('Enrolled / paid', 'enrolled')];
    final waiting = (f['needs_call'] as num?)?.toInt() ?? 0;
    final sources = Map<String, dynamic>.from((_funnel['recent_sources'] as Map?) ?? const {});
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFF5F7FB), borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Pipeline', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13.5)),
          const Spacer(),
          ChoiceChip(label: const Text('Last 30 days'), selected: _recent, onSelected: (_) => setState(() => _recent = true), visualDensity: VisualDensity.compact),
          const SizedBox(width: 6),
          ChoiceChip(label: const Text('Everyone'), selected: !_recent, onSelected: (_) => setState(() => _recent = false), visualDensity: VisualDensity.compact),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          for (var i = 0; i < steps.length; i++) ...[
            if (i > 0) const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textSecondary),
            Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text('${f[steps[i].$2] ?? 0}', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700)),
              Text('${steps[i].$1}${i == 0 ? '' : pct(steps[i].$2)}', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
            ]),
          ],
        ]),
        if (waiting > 0) ...[
          const SizedBox(height: 10),
          InkWell(
            onTap: () {
              setState(() {
                _needsCall = !_needsCall;
                _heat = '';
                _stage = '';
                _loading = true;
              });
              _load();
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: _needsCall ? const Color(0xFFD84315) : const Color(0xFFFFF1EA),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                Icon(Icons.phone_in_talk_rounded, size: 18, color: _needsCall ? Colors.white : const Color(0xFFD84315)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                      _needsCall
                          ? 'Showing the $waiting warm and hot leads nobody has called. Tap to show everyone.'
                          : '$waiting warm and hot leads have not been called yet — call them first',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12.5, color: _needsCall ? Colors.white : const Color(0xFF8A3305))),
                ),
              ]),
            ),
          ),
        ],
        if (_recent && sources.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Came from: ${sources.entries.take(5).map((e) => '${'${e.key}'.replaceAll('_', ' ')} ${e.value}').join(' · ')}',
              style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.textSecondary)),
        ],
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        // The theme paints AppBar foreground white for the dark bars used
        // elsewhere; on a white bar that hides the title and every action.
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: Text('CRM',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 17)),
        actions: [
          // The founder's voice assistant: ask about leads and the course by voice.
          TextButton.icon(
              onPressed: () => openFounderAltron(context),
              icon: const Icon(Icons.graphic_eq_rounded, size: 20),
              label: const Text('Altron')),
          TextButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CrmAutomationScreen())),
              icon: const Icon(Icons.auto_mode_rounded, size: 20),
              label: const Text('Automation')),
          IconButton(
              tooltip: 'Calling team: leaderboard, unassigned leads, labels, export',
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CrmTeamScreen())),
              icon: const Icon(Icons.headset_mic_rounded, size: 21)),
          IconButton(
              tooltip: 'Scholarship test candidates',
              onPressed: () => context.push('/scholars'),
              icon: const Icon(Icons.school_rounded, size: 21)),
          IconButton(
              tooltip: 'Remove duplicate contacts',
              onPressed: _cleanDuplicates,
              icon: const Icon(Icons.cleaning_services_outlined, size: 21)),
          IconButton(
              tooltip: 'Import leads from a CSV',
              onPressed: () => LeadImportSheet.show(context, () {
                    setState(() => _loading = true);
                    _load();
                  }),
              icon: const Icon(Icons.upload_file_rounded, size: 21)),
          IconButton(
              onPressed: () {
                setState(() => _loading = true);
                _load();
              },
              icon: const Icon(Icons.refresh_rounded, size: 21)),
        ],
      ),
      // The list is the screen: one slim bar (search, who to call, the pipeline behind a button), one row of filters,
      // then the people. Everything above the list scrolls away with it.
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(slivers: [
          SliverToBoxAdapter(child: _topBar()),
          if (_showPipeline)
            SliverToBoxAdapter(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                child: Column(children: [
                  _funnelCard(),
                  const SizedBox(height: 10),
                  Row(children: [
                    _Stat(label: 'Total', value: '${_summary['total'] ?? '—'}'),
                    _Stat(label: 'Registered', value: '${_summary['linked_students'] ?? '—'}'),
                    _Stat(label: 'Active 24h', value: '${_summary['active_24h'] ?? '—'}'),
                    _Stat(
                        label: 'Opted out',
                        value: '${_summary['opted_out'] ?? '—'}',
                        warn: (_summary['opted_out'] ?? 0) is int && (_summary['opted_out'] ?? 0) > 0),
                  ]),
                ]),
              ),
            ),
          SliverToBoxAdapter(child: _filters()),
          if (_loading)
            const SliverFillRemaining(hasScrollBody: false, child: Center(child: CircularProgressIndicator()))
          else if (_shown.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    _query.isNotEmpty || _stage.isNotEmpty || _heat.isNotEmpty || _needsCall || _did.isNotEmpty
                        ? 'No leads match that.'
                        : 'No leads yet. They appear here the moment someone messages the WhatsApp number or signs up.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(color: AppColors.textSecondary, height: 1.5),
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
              sliver: SliverList.separated(
                itemCount: _shown.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (context, i) => _LeadRow(
                  lead: _shown[i],
                  activity: (_activity['${_shown[i]['phone']}'] as List?) ?? const [],
                  onTap: () => _open(_shown[i]),
                ),
              ),
            ),
        ]),
      ),
    );
  }

  /// One WhatsApp message to everyone the filters show now (e.g. Registered). It goes as the approved update template,
  /// "Hi <their name>, <your message>", so it reaches people outside the 24-hour window too.
  Future<void> _bulk() async {
    final people = [for (final l in _shown) if ('${l['phone'] ?? ''}'.length >= 10) l];
    if (people.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No one in this list to message.')));
      return;
    }
    final box = TextEditingController();
    DateTime? later;                                   // null = send now
    final first = '${people.first['name'] ?? ''}'.trim().split(' ').first;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, redraw) => AlertDialog(
          title: Text('WhatsApp ${people.length} ${people.length == 1 ? 'person' : 'people'}'),
          content: SizedBox(
            width: 460,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Everyone in the list you are looking at now. Each gets their own name.',
                  style: GoogleFonts.inter(fontSize: 12.5, color: Colors.black54)),
              const SizedBox(height: 10),
              TextField(
                controller: box,
                maxLines: 5,
                maxLength: 900,
                onChanged: (_) => redraw(() {}),
                decoration: const InputDecoration(
                    border: OutlineInputBorder(), hintText: 'e.g. our free live demo is this Saturday at 6 pm. Reply YES to get the link.'),
              ),
              Text('They will read:', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFFDCF8C6), borderRadius: BorderRadius.circular(8)),
                child: Text('Hi ${first.isEmpty ? 'there' : first}, ${box.text.trim()}', style: GoogleFonts.inter(fontSize: 13)),
              ),
              const SizedBox(height: 10),
              Row(children: [
                Icon(Icons.schedule_rounded, size: 18, color: later == null ? Colors.black38 : AppColors.accent),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(later == null ? 'Sends now' : 'Sends ${MaterialLocalizations.of(ctx).formatMediumDate(later!)} at ${TimeOfDay.fromDateTime(later!).format(ctx)}',
                      style: GoogleFonts.inter(fontSize: 12.5)),
                ),
                TextButton(
                  onPressed: () async {
                    final now = DateTime.now();
                    final day = await showDatePicker(context: ctx, firstDate: now, lastDate: now.add(const Duration(days: 30)), initialDate: now);
                    if (day == null || !ctx.mounted) return;
                    final t = await showTimePicker(context: ctx, initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))));
                    if (t == null) return;
                    final at = DateTime(day.year, day.month, day.day, t.hour, t.minute);
                    redraw(() => later = at.isAfter(now) ? at : null);
                  },
                  child: Text(later == null ? 'Send later' : 'Change'),
                ),
                if (later != null) TextButton(onPressed: () => redraw(() => later = null), child: const Text('Now')),
              ]),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
                onPressed: box.text.trim().length < 3 ? null : () => Navigator.pop(ctx, true),
                child: Text(later == null ? 'Send to ${people.length}' : 'Schedule for ${people.length}')),
          ],
        ),
      ),
    );
    if (go != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final r = await ApiService.crmBulk([for (final l in people) '${l['phone']}'], box.text.trim(), sendAt: later);
      messenger.showSnackBar(SnackBar(
          content: Text(r['scheduled'] != null
              ? 'Scheduled for ${r['scheduled']} people. See or cancel it in Automation → Scheduled.'
              : 'Sending to ${r['queued']} people. Each one shows in their chat with a note.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not send: ${e.toString().replaceFirst('Exception: ', '')}')));
    }
  }

  List<Map<String, dynamic>> get _shown => [
        for (final l in _leads.cast<Map<String, dynamic>>())
          if (_did.isEmpty || ((_activity['${l['phone']}'] as List?) ?? const []).any((x) => (x as Map)['kind'] == _did)) l
      ];

  int get _waiting => ((Map<String, dynamic>.from((_funnel['recent'] as Map?) ?? const {}))['needs_call'] as num?)?.toInt() ?? 0;

  void _reload(VoidCallback change) {
    setState(() {
      change();
      _loading = true;
    });
    _load();
  }

  Widget _topBar() {
    final waiting = _waiting;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Search name or number',
              prefixIcon: const Icon(Icons.search_rounded, size: 19),
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onSubmitted: (v) => _reload(() => _query = v.trim()),
          ),
        ),
        if (waiting > 0) ...[
          const SizedBox(width: 8),
          Tooltip(
            message: 'Warm and hot leads nobody has called yet',
            child: FilterChip(
              avatar: Icon(Icons.phone_in_talk_rounded, size: 16, color: _needsCall ? Colors.white : const Color(0xFFD84315)),
              label: Text('Call first · $waiting'),
              labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12, color: _needsCall ? Colors.white : const Color(0xFF8A3305)),
              selected: _needsCall,
              showCheckmark: false,
              selectedColor: const Color(0xFFD84315),
              backgroundColor: const Color(0xFFFFF1EA),
              side: BorderSide.none,
              onSelected: (_) => _reload(() {
                _needsCall = !_needsCall;
                _heat = '';
                _stage = '';
              }),
            ),
          ),
        ],
        const SizedBox(width: 6),
        IconButton(
          tooltip: _showPipeline ? 'Hide the pipeline' : 'Show the pipeline and totals',
          onPressed: () => setState(() => _showPipeline = !_showPipeline),
          icon: Icon(_showPipeline ? Icons.insights_rounded : Icons.insights_outlined, color: _showPipeline ? AppColors.primary : null),
        ),
      ]),
    );
  }

  // Temperature and stage in one row: who to talk to first, then where they are.
  Widget _filters() => Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            height: 32,
            child: ListView(scrollDirection: Axis.horizontal, children: [
              for (final h in _heatLabels.keys)
                _StageChip(
                  label: _heatLabels[h]!,
                  count: h.isEmpty ? _heatCounts.values.fold<int>(0, (a, b) => a + (b is int ? b : 0)) : (_heatCounts[h] as int?) ?? 0,
                  selected: _heat == h,
                  color: _heatColors[h]!,
                  onTap: () => _reload(() => _heat = h),
                ),
              Container(width: 1, margin: const EdgeInsets.fromLTRB(2, 6, 9, 6), color: Colors.black12),
              for (final st in _stageLabels.keys)
                _StageChip(
                  label: _stageLabels[st]!,
                  count: (_counts[st] as int?) ?? 0,
                  selected: _stage == st,
                  color: _stageColors[st]!,
                  onTap: () => _reload(() => _stage = _stage == st ? '' : st),
                ),
            ]),
          ),
          const SizedBox(height: 6),
          // What they did: signed up, signed in, registered for a programme or demo class, paid, a callback, the roadmap
          SizedBox(
            height: 32,
            child: ListView(scrollDirection: Axis.horizontal, children: [
              for (final k in _didLabels.keys)
                _StageChip(
                  label: _didLabels[k]!,
                  count: k.isEmpty ? _leads.length : (_didCounts[k] as int?) ?? 0,
                  selected: _did == k,
                  color: const Color(0xFF37474F),
                  onTap: () => setState(() => _did = _did == k ? '' : k),
                ),
            ]),
          ),
          if (!_loading) ...[
            const SizedBox(height: 6),
            Row(children: [
              Expanded(
                child: Text('${_shown.length} ${_shown.length == 1 ? 'person' : 'people'}${_did.isNotEmpty ? ' · ${_didLabels[_did]}' : ''}${_stage.isNotEmpty ? ' · ${_stageLabels[_stage]}' : ''}${_needsCall ? ' · to call first' : ''}',
                    style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
              ),
              // Pick a filter (e.g. Registered), then message everyone it shows.
              OutlinedButton.icon(
                onPressed: _shown.isEmpty ? null : _bulk,
                icon: const Icon(Icons.campaign_outlined, size: 18, color: Color(0xFF128C7E)),
                label: Text('WhatsApp these ${_shown.length}', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700, color: const Color(0xFF128C7E))),
              ),
            ]),
          ],
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

class _StageChip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _StageChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 7),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: selected ? color : color.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withValues(alpha: selected ? 1 : 0.3)),
            ),
            child: Text('$label · $count',
                style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : color)),
          ),
        ),
      );
}

const _didLabels = {
  '': 'Everyone',
  'registered': '🎓 Registered',
  'paid': '💰 Paid',
  'signup': '👤 Signed up',
  'login': '🔑 Signed in',
  'enrolment': '📝 Filled the form',
  'callback': '📞 Asked a callback',
  'booking': '📅 Booked a call',
  'roadmap': '🗺 Opened the roadmap',
  'ai_demo': '🤖 AI demo class',
};

/// "today", "3d", "2mo": how long ago, short enough for a row.
String _ago(String iso) {
  final t = DateTime.tryParse(iso);
  if (t == null) return '';
  final d = DateTime.now().difference(t.toLocal());
  if (d.inHours < 24) return 'today';
  if (d.inDays < 31) return '${d.inDays}d ago';
  return '${(d.inDays / 30).floor()}mo ago';
}

class _LeadRow extends StatelessWidget {
  final Map<String, dynamic> lead;
  final List activity;
  final VoidCallback onTap;
  const _LeadRow({required this.lead, required this.onTap, this.activity = const []});

  @override
  Widget build(BuildContext context) {
    final stage = lead['stage'] as String? ?? 'new';
    final heat = (lead['heat'] as Map?) ?? const {};
    final temp = '${heat['temperature'] ?? 'cold'}';
    final color = _heatColors[temp] ?? AppColors.textSecondary;
    final why = ((heat['reasons'] as List?) ?? const []).join('  ·  ');
    final isStudent = lead['student_user_id'] != null;
    final optedOut = lead['opt_in'] == false;
    final last = lead['last_message'] as String? ?? '';
    final plan = lead['plan'] as String? ?? '';
    final occupation = lead['occupation'] as String? ?? '';
    final org = (lead['company'] as String?)?.isNotEmpty == true
        ? lead['company'] as String
        : lead['college'] as String? ?? '';
    final email = lead['email'] as String? ?? '';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black.withValues(alpha: 0.07)),
        ),
        child: Row(children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Text(
                    (lead['name'] as String?)?.isNotEmpty == true
                        ? lead['name'] as String
                        : lead['phone'] as String? ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                        fontSize: 13.5, fontWeight: FontWeight.w600),
                  ),
                ),
                if (isStudent) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.verified_rounded, size: 13, color: AppColors.success),
                ],
                if (optedOut) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.notifications_off_rounded, size: 13, color: AppColors.error),
                ],
              ]),
              const SizedBox(height: 2),
              Row(children: [
                if ((lead['phone'] as String? ?? '').isNotEmpty) ...[
                  Text(lead['phone'] as String,
                      style: GoogleFonts.inter(
                          fontSize: 11.5, color: AppColors.textSecondary)),
                  const SizedBox(width: 8),
                ],
                if (occupation.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: (occupation == 'working'
                              ? const Color(0xFF6A1B9A)
                              : const Color(0xFF0277BD))
                          .withValues(alpha: 0.11),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(occupation == 'working' ? 'WORKING' : 'STUDENT',
                        style: GoogleFonts.inter(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w700,
                            color: occupation == 'working'
                                ? const Color(0xFF6A1B9A)
                                : const Color(0xFF0277BD))),
                  ),
                  const SizedBox(width: 6),
                ],
                if (plan.isNotEmpty && plan != 'free')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.11),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(plan.toUpperCase(),
                        style: GoogleFonts.inter(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary)),
                  ),
              ]),
              // What they did, newest first: the most useful line on the row.
              if (activity.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                    activity.take(4).map((x) {
                      final m = x as Map;
                      final icon = (_didLabels['${m['kind']}'] ?? '').split(' ').first;
                      return '$icon ${m['label']} · ${_ago('${m['at']}')}';
                    }).join('   '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFF263238))),
              ],
              if (org.isNotEmpty || email.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                    [org, email].where((x) => x.isNotEmpty).join('  ·  '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                        fontSize: 11, color: AppColors.textSecondary)),
              ],
              if (why.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(why,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
              ],
              if (last.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(last,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                        fontSize: 10.5,
                        fontStyle: FontStyle.italic,
                        color: AppColors.textSecondary)),
              ],
            ]),
          ),
          if (lead['reachable'] == true) ...[
            IconButton(
              tooltip: 'Call',
              visualDensity: VisualDensity.compact,
              onPressed: () => launchUrl(Uri.parse('tel:+91${lead['phone']}')),
              icon: const Icon(Icons.call_rounded, size: 19, color: Color(0xFF2E7D32)),
            ),
            IconButton(
              tooltip: 'WhatsApp',
              visualDensity: VisualDensity.compact,
              onPressed: () => launchUrl(Uri.parse('https://wa.me/91${lead['phone']}'), mode: LaunchMode.externalApplication),
              icon: const Icon(Icons.chat_rounded, size: 18, color: Color(0xFF128C7E)),
            ),
          ],
          const SizedBox(width: 4),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            _HeatBadge(temp),
            const SizedBox(height: 4),
            Text(_stageLabels[stage] ?? stage,
                style: GoogleFonts.inter(
                    fontSize: 9.5, fontWeight: FontWeight.w600, color: _stageColors[stage] ?? AppColors.textSecondary)),
          ]),
        ]),
      ),
    );
  }
}

/// One lead: stage, owner, notes, the student behind them, and the recent
/// conversation as read-only context.
class LeadDetailScreen extends StatefulWidget {
  final String phone;
  const LeadDetailScreen({super.key, required this.phone});

  @override
  State<LeadDetailScreen> createState() => _LeadDetailScreenState();
}

class _LeadDetailScreenState extends State<LeadDetailScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  bool _changed = false;
  final _noteCtrl = TextEditingController();
  bool _asking = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      _data = await ApiService.crmLead(widget.phone);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  void _toast(String text, {bool bad = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), backgroundColor: bad ? AppColors.error : null));
  }

  // The model reads this lead and says where they stand, what to do, and a message to send.
  Future<void> _copyDemoLink() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final r = await ApiService.crmDemoLink(widget.phone);
      final url = '${r['url'] ?? ''}';
      if (url.isEmpty) throw Exception('no link');
      await Clipboard.setData(ClipboardData(text: url));
      messenger.showSnackBar(SnackBar(content: Text('Copied: $url')));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Could not make the demo link. Please try again.')));
    }
  }

  Future<void> _askAi() async {
    setState(() => _asking = true);
    try {
      final r = await ApiService.crmAskAi(widget.phone);
      _data = {...?_data, 'ai': r};
    } catch (e) {
      _toast(e is ApiException ? e.message : 'The AI could not read this lead just now. Try again in a moment.', bad: true);
    }
    if (mounted) setState(() => _asking = false);
  }

  // The conversation in a chat window of its own, the way the team knows it from WhatsApp.
  Future<void> _openChat() async {
    final lead = _data?['lead'] as Map<String, dynamic>?;
    final ai = _data?['ai'] as Map?;
    final sent = await Navigator.push<bool>(context, MaterialPageRoute(
        builder: (_) => CrmChatScreen(phone: widget.phone, name: '${lead?['name'] ?? ''}', draft: '${ai?['message'] ?? ''}')));
    if (sent == true) {
      _changed = true;
      await _load();
    }
  }

  /// Paid students' course access, in one place: Token paid or Enrolled opens every module and the Altron trainer when
  /// they sign in with this WhatsApp number (the server decides; see live_tutor.has_trainer_access).
  Widget _accessBox(String stage) {
    final on = stage == 'token_paid' || stage == 'enrolled';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: on ? AppColors.success.withValues(alpha: 0.08) : const Color(0xFFF6F8FB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: on ? AppColors.success.withValues(alpha: 0.35) : Colors.black.withValues(alpha: 0.08)),
      ),
      child: Row(children: [
        Icon(on ? Icons.lock_open_rounded : Icons.lock_outline_rounded, color: on ? AppColors.success : AppColors.textSecondary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(on ? 'Course access: ON' : 'Course access: off',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14, color: on ? AppColors.success : AppColors.textPrimary)),
            Text(
                on
                    ? 'All notes, projects, tests and the Altron trainer open when they sign in with WhatsApp +91 ${widget.phone}.'
                    : 'Paid the fee or the seat? Give access: everything opens when they sign in with WhatsApp +91 ${widget.phone}.',
                style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textSecondary, height: 1.4)),
          ]),
        ),
        const SizedBox(width: 12),
        if (on)
          TextButton(onPressed: () => _confirmAccess(false), child: const Text('Remove access'))
        else
          FilledButton.icon(
            onPressed: () => _confirmAccess(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.success, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14)),
            icon: const Icon(Icons.verified_rounded, size: 18),
            label: const Text('Give paid access'),
          ),
      ]),
    );
  }

  Future<void> _confirmAccess(bool give) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(give ? 'Give full course access?' : 'Remove course access?'),
        content: Text(give
            ? 'Marks them Enrolled. Every module, project, test and the Altron trainer opens for +91 ${widget.phone}.'
            : 'Moves them back to Demo done. Paid modules lock again unless they paid online.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: Text(give ? 'Give access' : 'Remove')),
        ],
      ),
    );
    if (ok == true) await _setStage(give ? 'enrolled' : 'demo_done');
  }

  Future<void> _setStage(String stage) async {
    try {
      await ApiService.crmUpdateLead(widget.phone, {'stage': stage});
      _changed = true;
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e is ApiException ? e.message : 'Could not update'),
            backgroundColor: AppColors.error));
      }
    }
  }

  /// Admin filling in what a student never did. Most accounts predate the
  /// occupation question, so without this the CRM can never segment them.
  Future<void> _editStudent(Map<String, dynamic> student) async {
    final name = TextEditingController(text: '${student['name'] ?? ''}');
    final email = TextEditingController(text: '${student['email'] ?? ''}');
    final org = TextEditingController(
        text: '${student['company'] ?? student['college'] ?? ''}');
    var occupation = '${student['occupation'] ?? 'student'}';
    if (occupation != 'working') occupation = 'student';

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text('Edit details',
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Name')),
              const SizedBox(height: 10),
              TextField(
                  controller: email,
                  decoration: const InputDecoration(labelText: 'Email')),
              const SizedBox(height: 14),
              Row(children: [
                for (final o in const [('student', 'Student'), ('working', 'Working')])
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setLocal(() => occupation = o.$1),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: occupation == o.$1
                                ? AppColors.primary.withValues(alpha: 0.1)
                                : Colors.transparent,
                            border: Border.all(
                                color: occupation == o.$1
                                    ? AppColors.primary
                                    : Colors.black26),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Center(
                            child: Text(o.$2,
                                style: GoogleFonts.inter(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: occupation == o.$1
                                        ? AppColors.primary
                                        : AppColors.textSecondary)),
                          ),
                        ),
                      ),
                    ),
                  ),
              ]),
              const SizedBox(height: 10),
              TextField(
                controller: org,
                decoration: InputDecoration(
                    labelText: occupation == 'working' ? 'Company' : 'College'),
              ),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Save')),
          ],
        ),
      ),
    );
    if (saved != true) return;
    try {
      await ApiService.crmUpdateStudent(student['id'] as int, {
        'name': name.text.trim(),
        'email': email.text.trim(),
        'occupation': occupation,
        if (occupation == 'student') 'college': org.text.trim(),
        if (occupation == 'working') 'company': org.text.trim(),
      });
      _changed = true;
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e is ApiException ? e.message : 'Could not save'),
            backgroundColor: AppColors.error));
      }
    }
  }

  Future<void> _addNote() async {
    final text = _noteCtrl.text.trim();
    if (text.isEmpty) return;
    try {
      await ApiService.crmAddNote(widget.phone, text);
      _noteCtrl.clear();
      _changed = true;
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not save the note')));
      }
    }
  }

  // ── the page ──
  //
  // One look should answer: who is this, how warm are they, what do I do now. So the top is the person with the actions
  // (chat, call, ask AI) and the AI's advice; the details and notes sit beside it on a wide screen and below on a phone.

  Widget _header(Map<String, dynamic> lead, Map<String, dynamic>? student) {
    final name = (lead['name'] as String?)?.isNotEmpty == true ? lead['name'] as String : widget.phone;
    final heat = (_data?['heat'] as Map?) ?? const {};
    final temp = '${heat['temperature'] ?? 'cold'}';
    final color = _heatColors[temp] ?? AppColors.textSecondary;
    final stage = lead['stage'] as String? ?? 'new';
    final org = '${student?['company'] ?? student?['college'] ?? ''}';
    final occupation = '${student?['occupation'] ?? ''}';
    final sub = [
      widget.phone,
      if (occupation.isNotEmpty) occupation == 'working' ? 'Working' : 'Student',
      if (org.isNotEmpty && org != 'null') org,
      if (student != null && '${student['plan'] ?? 'free'}' != 'free') '${student['plan']} plan',
    ].join('  ·  ');
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: color.withValues(alpha: 0.14),
            child: Text(name.characters.first.toUpperCase(),
                style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: color)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Text(name, overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(fontSize: 19, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                ),
                if (student != null) ...[
                  const SizedBox(width: 6),
                  Tooltip(message: 'Has a student account', child: Icon(Icons.verified_rounded, size: 17, color: AppColors.success)),
                ],
                if (lead['opt_in'] == false) ...[
                  const SizedBox(width: 6),
                  Tooltip(message: 'Said STOP: no marketing', child: Icon(Icons.notifications_off_rounded, size: 17, color: AppColors.error)),
                ],
              ]),
              const SizedBox(height: 3),
              Text(sub, style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textSecondary)),
            ]),
          ),
          const SizedBox(width: 10),
          _HeatBadge(temp),
        ]),
        const SizedBox(height: 16),
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilledButton.icon(
            onPressed: _openChat,
            icon: const Icon(Icons.chat_rounded, size: 18),
            label: const Text('Chat'),
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14)),
          ),
          OutlinedButton.icon(
            onPressed: () => launchUrl(Uri.parse('tel:+91${widget.phone}')),
            icon: const Icon(Icons.call_rounded, size: 18),
            label: const Text('Call'),
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14)),
          ),
          OutlinedButton.icon(
            onPressed: _asking ? null : _askAi,
            icon: _asking
                ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.auto_awesome_rounded, size: 18),
            label: Text(_asking ? 'Reading…' : 'Ask AI'),
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14)),
          ),
          // Their own roadmap + live demo link: whatever they do there lands on this page, without a sign-in.
          OutlinedButton.icon(
            onPressed: _copyDemoLink,
            icon: const Icon(Icons.link_rounded, size: 18),
            label: const Text('Copy demo link'),
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14)),
          ),
        ]),
        const SizedBox(height: 16),
        Text('STAGE', style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: .6, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        // The pipeline as steps: where they are is filled, and one tap moves them.
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final s in _stageLabels.keys)
            ChoiceChip(
              label: Text(_stageLabels[s]!),
              selected: stage == s,
              onSelected: (_) => _setStage(s),
              showCheckmark: false,
              labelStyle: GoogleFonts.inter(
                  fontSize: 12.5, fontWeight: FontWeight.w600, color: stage == s ? Colors.white : _stageColors[s]),
              selectedColor: _stageColors[s],
              backgroundColor: _stageColors[s]!.withValues(alpha: 0.08),
              side: BorderSide(color: _stageColors[s]!.withValues(alpha: 0.3)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
        ]),
        const SizedBox(height: 16),
        _accessBox(stage),
      ]),
    );
  }

  Widget _advice() {
    final heat = (_data?['heat'] as Map?) ?? const {};
    final temp = '${heat['temperature'] ?? 'cold'}';
    final reasons = ((heat['reasons'] as List?) ?? const []).map((e) => '$e').toList();
    final ai = _data?['ai'] as Map?;
    final message = '${ai?['message'] ?? ''}';
    return _Card(
      title: 'What to do next',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final r in reasons)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: _heatColors[temp]!.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
              child: Text(r, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: _heatColors[temp])),
            ),
        ]),
        const SizedBox(height: 12),
        if (ai == null)
          Text('Press Ask AI: it reads the whole conversation and tells you where they stand, the next step, and a message to send.',
              style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textSecondary, height: 1.45))
        else ...[
          if ('${ai['summary'] ?? ''}'.isNotEmpty)
            Text('${ai['summary']}', style: GoogleFonts.inter(fontSize: 13.5, height: 1.45)),
          if ('${ai['next_step'] ?? ''}'.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(10)),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.flag_rounded, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(child: Text('${ai['next_step']}', style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w600, height: 1.45))),
              ]),
            ),
          ],
          if (message.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFD9FDD3), borderRadius: BorderRadius.circular(10)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Suggested WhatsApp message', style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.black54)),
                const SizedBox(height: 4),
                SelectableText(message, style: GoogleFonts.inter(fontSize: 13.5, height: 1.45)),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: _openChat,
                    icon: const Icon(Icons.send_rounded, size: 16),
                    label: const Text('Review and send'),
                  ),
                ),
              ]),
            ),
          ],
          const SizedBox(height: 6),
          Text('AI read it ${'${ai['at'] ?? ''}'.isEmpty ? 'just now' : 'on ${'${ai['at']}'.split('T').first}'}',
              style: GoogleFonts.inter(fontSize: 10.5, color: AppColors.textSecondary)),
        ],
      ]),
    );
  }

  Widget _conversation(List messages) => _Card(
        title: 'Latest messages',
        trailing: TextButton(onPressed: _openChat, child: Text(messages.isEmpty ? 'Open chat' : 'All ${messages.length} →')),
        child: messages.isEmpty
            ? Text('No messages yet.', style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textSecondary))
            : InkWell(
                onTap: _openChat,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFFEFEAE2), borderRadius: BorderRadius.circular(10)),
                  child: Column(children: [
                    for (final m in messages.skip(messages.length > 4 ? messages.length - 4 : 0))
                      Align(
                        alignment: m['direction'] == 'out' ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 3),
                          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                          constraints: const BoxConstraints(maxWidth: 420),
                          decoration: BoxDecoration(
                            color: m['direction'] == 'out' ? const Color(0xFFD9FDD3) : Colors.white,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Text('${m['body'] ?? ''}', maxLines: 3, overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(fontSize: 13, height: 1.35)),
                        ),
                      ),
                  ]),
                ),
              ),
      );

  Widget _details(Map<String, dynamic> lead, Map<String, dynamic>? student) {
    final consent = lead['opt_in'] == false
        ? 'No — said STOP'
        : lead['opt_in'] == true
            ? 'Yes${lead['opt_in_source'] != null ? ' (${lead['opt_in_source']})' : ''}'
            : 'Not asked yet';
    String day(dynamic v) => v == null ? '' : '$v'.split('T').first;
    final rows = <(String, String)>[
      ('Phone', widget.phone),
      if (student != null && '${student['email'] ?? ''}'.isNotEmpty && '${student['email']}' != 'null') ('Email', '${student['email']}'),
      ('Marketing OK', consent),
      if (lead['last_inbound_at'] != null) ('Last wrote', day(lead['last_inbound_at'])),
      if ('${lead['source'] ?? ''}'.isNotEmpty) ('Came from', '${lead['source']}'.replaceAll('_', ' ')),
      if (student != null) ('Plan', '${student['plan'] ?? 'free'}${student['status'] != null ? ' · ${student['status']}' : ''}'),
      if (student != null && student['created_at'] != null) ('Joined', day(student['created_at'])),
      if (student != null && '${student['address'] ?? ''}'.isNotEmpty && '${student['address']}' != 'null') ('Address', '${student['address']}'),
    ];
    return _Card(
      title: 'Details',
      trailing: student == null
          ? null
          : TextButton.icon(onPressed: () => _editStudent(student), icon: const Icon(Icons.edit_outlined, size: 15), label: const Text('Edit')),
      child: Column(children: [for (final r in rows) _kv(r.$1, r.$2)]),
    );
  }

  Widget _notesCard(List notes) => _Card(
        title: 'Notes',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(
            controller: _noteCtrl,
            minLines: 1,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'What happened on the call, what they want…',
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              suffixIcon: IconButton(onPressed: _addNote, icon: const Icon(Icons.add_circle_rounded), tooltip: 'Add note'),
            ),
            onSubmitted: (_) => _addNote(),
          ),
          const SizedBox(height: 10),
          if (notes.isEmpty)
            Text('No notes yet.', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary))
          else
            for (final n in notes)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFFFFF8E1), borderRadius: BorderRadius.circular(9)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${n['text']}', style: GoogleFonts.inter(fontSize: 12.5, height: 1.4)),
                  const SizedBox(height: 3),
                  Text(['${n['author'] ?? ''}', '${n['created_at']}'.split('T').first].where((x) => x.isNotEmpty).join(' · '),
                      style: GoogleFonts.inter(fontSize: 10, color: AppColors.textSecondary)),
                ]),
              ),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final lead = _data?['lead'] as Map<String, dynamic>?;
    final student = _data?['student'] as Map<String, dynamic>?;
    final messages = (_data?['messages'] as List?) ?? [];
    final notes = (_data?['notes'] as List?) ?? [];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.textPrimary, // the theme's white would hide the back arrow and the title
          surfaceTintColor: Colors.white,
          elevation: 0,
          leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => Navigator.pop(context, _changed)),
          title: Text('Lead', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16, color: AppColors.textPrimary)),
          actions: [
            IconButton(
                tooltip: 'Timeline: every call, note and WhatsApp message',
                onPressed: () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => CrmTimelineScreen(phone: widget.phone, name: '${lead?['name'] ?? ''}'))),
                icon: const Icon(Icons.timeline_rounded)),
            IconButton(tooltip: 'Refresh', onPressed: () { setState(() => _loading = true); _load(); }, icon: const Icon(Icons.refresh_rounded)),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : lead == null
                ? Center(child: Text('Lead not found', style: GoogleFonts.inter(color: AppColors.textSecondary)))
                : LayoutBuilder(builder: (context, box) {
                    final wide = box.maxWidth >= 980;
                    final main = [_header(lead, student), const SizedBox(height: 14), _advice(), const SizedBox(height: 14), _conversation(messages)];
                    final side = [_details(lead, student), const SizedBox(height: 14), _notesCard(notes)];
                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1240),
                        child: ListView(padding: const EdgeInsets.all(16), children: [
                          if (wide)
                            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Expanded(flex: 3, child: Column(children: main)),
                              const SizedBox(width: 16),
                              Expanded(flex: 2, child: Column(children: side)),
                            ])
                          else ...[...main, const SizedBox(height: 14), ...side],
                          const SizedBox(height: 24),
                        ]),
                      ),
                    );
                  }),
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 108,
            child: Text(k,
                style: GoogleFonts.inter(
                    fontSize: 11.5, color: AppColors.textSecondary)),
          ),
          Expanded(
              child: Text(v, style: GoogleFonts.inter(fontSize: 12.5))),
        ]),
      );
}

const _heatLabels = {'': 'Everyone', 'hot': 'Hot', 'warm': 'Warm', 'cold': 'Cold', 'customer': 'Customers', 'out': 'Out'};
const _heatColors = {
  '': AppColors.primary,
  'hot': Color(0xFFD84315),
  'warm': Color(0xFFF9A825),
  'cold': Color(0xFF546E7A),
  'customer': Color(0xFF2E7D32),
  'out': Color(0xFF9E9E9E),
};

class _HeatBadge extends StatelessWidget {
  final String temperature;
  const _HeatBadge(this.temperature);

  @override
  Widget build(BuildContext context) {
    final color = _heatColors[temperature] ?? AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(20)),
      child: Text(temperature == 'hot' ? '🔥 HOT' : (_heatLabels[temperature] ?? temperature).toUpperCase(),
          style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w800, color: color)),
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;
  const _Card({
    required this.title,
    this.subtitle = '',
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black.withValues(alpha: 0.07)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(title,
                  style: GoogleFonts.poppins(
                      fontSize: 13, fontWeight: FontWeight.w600)),
            ),
            if (trailing != null) trailing!,
          ]),
          if (subtitle.isNotEmpty)
            Text(subtitle,
                style: GoogleFonts.inter(fontSize: 10.5, color: AppColors.textSecondary)),
          const SizedBox(height: 10),
          child,
        ]),
      );
}
