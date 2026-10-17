// The calling team, from the web CRM: how each telecaller is doing, the leads nobody owns yet (dealt out in turn), the
// labels callers tag leads with, and copies of the CRM for spreadsheets. The telecallers themselves work in the
// Altrobyte Caller app (lib/caller); everything here reads and writes the same CRM.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../constants/app_colors.dart';
import '../../services/api_service.dart';
import '../../utils/file_download.dart';

String _plain(Object e) => '$e'.replaceFirst('Exception: ', '');

String _talk(int s) => s >= 3600 ? '${s ~/ 3600}h ${(s % 3600) ~/ 60}m' : '${s ~/ 60}m';

class CrmTeamScreen extends StatelessWidget {
  const CrmTeamScreen({super.key});

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 5,
        child: Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: Colors.white,
            foregroundColor: AppColors.textPrimary,
            elevation: 0,
            title: Text('Calling team', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 17)),
            bottom: const TabBar(isScrollable: true, labelColor: AppColors.primary, tabs: [
              Tab(text: 'Leaderboard'),
              Tab(text: 'Unassigned leads'),
              Tab(text: 'People'),
              Tab(text: 'Labels'),
              Tab(text: 'Export'),
            ]),
          ),
          body: const TabBarView(children: [_Leaderboard(), _Unassigned(), _People(), _Labels(), _Export()]),
        ),
      );
}

class _Leaderboard extends StatefulWidget {
  const _Leaderboard();

  @override
  State<_Leaderboard> createState() => _LeaderboardState();
}

class _LeaderboardState extends State<_Leaderboard> {
  int _days = 7;
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
      final d = await ApiService.crmTeamStats(_days);
      if (mounted) setState(() => _data = d);
    } catch (e) {
      if (mounted) setState(() => _problem = _plain(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = ((_data?['team'] as List?) ?? const []).cast<Map>();
    final t = Map<String, dynamic>.from((_data?['totals'] as Map?) ?? const {});
    return ListView(padding: const EdgeInsets.all(16), children: [
      Wrap(spacing: 8, children: [
        for (final d in const [1, 7, 30, 90])
          ChoiceChip(
            label: Text(d == 1 ? 'Today' : 'Last $d days'),
            selected: _days == d,
            onSelected: (_) {
              setState(() => _days = d);
              _load();
            },
          ),
      ]),
      const SizedBox(height: 12),
      if (_problem != null)
        Text(_problem!, style: const TextStyle(color: AppColors.error))
      else if (_data == null)
        const Center(child: CircularProgressIndicator())
      else
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingTextStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontSize: 12.5),
            columns: const [
              DataColumn(label: Text('#')),
              DataColumn(label: Text('Caller')),
              DataColumn(label: Text('Calls'), numeric: true),
              DataColumn(label: Text('Connected'), numeric: true),
              DataColumn(label: Text('Talk time'), numeric: true),
              DataColumn(label: Text('Interested'), numeric: true),
              DataColumn(label: Text('Follow-ups done'), numeric: true),
              DataColumn(label: Text('Missed'), numeric: true),
              DataColumn(label: Text('Converted'), numeric: true),
            ],
            rows: [
              for (final (i, r) in rows.indexed)
                DataRow(cells: [
                  DataCell(Text('${i + 1}')),
                  DataCell(Text('${r['name']}', style: const TextStyle(fontWeight: FontWeight.w600))),
                  DataCell(Text('${r['calls']}')),
                  DataCell(Text('${r['connected_pct']}%')),
                  DataCell(Text(_talk((r['talk_time_s'] as num).toInt()))),
                  DataCell(Text('${r['interested']}')),
                  DataCell(Text('${r['followups_done']}')),
                  DataCell(Text('${r['followups_missed']}',
                      style: TextStyle(color: (r['followups_missed'] as num) > 0 ? AppColors.error : null))),
                  DataCell(Text('${r['conversions']}',
                      style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.success))),
                ]),
              DataRow(cells: [
                const DataCell(Text('')),
                const DataCell(Text('Team', style: TextStyle(fontWeight: FontWeight.w800))),
                DataCell(Text('${t['calls'] ?? 0}')),
                DataCell(Text('${t['connected_pct'] ?? 0}%')),
                DataCell(Text(_talk(((t['talk_time_s'] ?? 0) as num).toInt()))),
                DataCell(Text('${t['interested'] ?? 0}')),
                DataCell(Text('${t['followups_done'] ?? 0}')),
                DataCell(Text('${t['followups_missed'] ?? 0}')),
                DataCell(Text('${t['conversions'] ?? 0}')),
              ]),
            ],
          ),
        ),
      const SizedBox(height: 10),
      Text('A conversion counts for whoever last spoke to the lead on the phone, read from the CRM: nobody marks it.',
          style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
    ]);
  }
}

class _Unassigned extends StatefulWidget {
  const _Unassigned();

  @override
  State<_Unassigned> createState() => _UnassignedState();
}

class _UnassignedState extends State<_Unassigned> {
  List<Map<String, dynamic>>? _leads;
  List<Map<String, dynamic>> _team = [];
  final _picked = <String>{};
  final _to = <String>{};
  String? _problem;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _problem = null);
    try {
      final leads = await ApiService.crmUnassigned();
      final team = await ApiService.crmTeam();
      if (!mounted) return;
      setState(() {
        _leads = leads.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _team = team.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _picked.clear();
        if (_to.isEmpty) _to.addAll(_team.map((m) => '${m['login']}'));
      });
    } catch (e) {
      if (mounted) setState(() => _problem = _plain(e));
    }
  }

  Future<void> _assign({String? owner}) async {
    final messenger = ScaffoldMessenger.of(context);
    final phones = _picked.isEmpty ? _leads!.map((l) => '${l['phone']}').toList() : _picked.toList();
    setState(() => _busy = true);
    try {
      final r = owner == null
          ? await ApiService.crmAssign(phones, roundRobin: _to.toList())
          : await ApiService.crmAssign(phones, owner: owner);
      messenger.showSnackBar(SnackBar(content: Text('${r['assigned']} leads assigned.')));
      await _load();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(_plain(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_problem != null) return Center(child: Text(_problem!, style: const TextStyle(color: AppColors.error)));
    if (_leads == null) return const Center(child: CircularProgressIndicator());
    final n = _picked.isEmpty ? _leads!.length : _picked.length;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: _team.isEmpty
            ? Text('No telecallers yet. Add them as managers (Settings > Managers); give a team lead the "crm_team" permission.',
                style: GoogleFonts.inter(color: AppColors.textSecondary))
            : Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text('Share between:', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                for (final m in _team)
                  FilterChip(
                    label: Text('${m['name']} · ${m['open_leads']} open'),
                    selected: _to.contains('${m['login']}'),
                    onSelected: (on) => setState(() => on ? _to.add('${m['login']}') : _to.remove('${m['login']}')),
                  ),
              ]),
      ),
      Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(spacing: 10, runSpacing: 10, children: [
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
            onPressed: _busy || _leads!.isEmpty || _to.isEmpty ? null : () => _assign(),
            icon: const Icon(Icons.shuffle_rounded),
            label: Text('Assign ${_picked.isEmpty ? 'all ' : ''}$n round-robin'),
          ),
          if (_to.length == 1)
            OutlinedButton(
              onPressed: _busy || _leads!.isEmpty ? null : () => _assign(owner: _to.first),
              child: Text('Give all $n to ${_team.firstWhere((m) => m['login'] == _to.first, orElse: () => {'name': _to.first})['name']}'),
            ),
        ]),
      ),
      Expanded(
        child: _leads!.isEmpty
            ? Center(child: Text('Every lead has someone.', style: GoogleFonts.inter(color: AppColors.textSecondary)))
            : ListView(children: [
                for (final l in _leads!)
                  CheckboxListTile(
                    value: _picked.contains('${l['phone']}'),
                    onChanged: (on) =>
                        setState(() => on == true ? _picked.add('${l['phone']}') : _picked.remove('${l['phone']}')),
                    title: Text('${l['name'] ?? ''}'.isEmpty ? '${l['phone']}' : '${l['name']}'),
                    subtitle: Text('${(l['heat'] as Map?)?['temperature'] ?? ''} · ${l['score_pct']}% · ${l['stage']} · ${l['phone']}'),
                  ),
              ]),
      ),
    ]);
  }
}

/// Who is on the calling team: add a telecaller login, make someone a team lead (they assign leads and see everyone's
/// numbers in the app), or switch a login off.
class _People extends StatefulWidget {
  const _People();

  @override
  State<_People> createState() => _PeopleState();
}

class _PeopleState extends State<_People> {
  List<Map<String, dynamic>>? _team;
  final _name = TextEditingController(), _email = TextEditingController(), _password = TextEditingController();
  bool _lead = false;
  String? _said;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final t = await ApiService.crmTeam();
      if (mounted) setState(() => _team = t.map((e) => Map<String, dynamic>.from(e as Map)).toList());
    } catch (e) {
      if (mounted) setState(() => _said = _plain(e));
    }
  }

  Future<void> _do(Future<void> Function() f, String done) async {
    try {
      await f();
      setState(() => _said = done);
      await _load();
    } catch (e) {
      setState(() => _said = _plain(e));
    }
  }

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [
        if (_team == null)
          const Center(child: CircularProgressIndicator())
        else
          for (final m in _team!)
            Card(
              child: ListTile(
                title: Text('${m['name']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('${m['login']} · ${m['open_leads']} open leads'),
                trailing: Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  FilterChip(
                    label: const Text('Team lead'),
                    selected: m['team_lead'] == true,
                    onSelected: (on) => _do(() => ApiService.crmEditMember('${m['login']}', teamLead: on),
                        on ? '${m['name']} is a team lead.' : '${m['name']} is a caller.'),
                  ),
                  TextButton(
                    onPressed: () => _do(() => ApiService.crmEditMember('${m['login']}', active: false),
                        '${m['name']} can no longer sign in. Their leads stay theirs until you assign them on.'),
                    child: const Text('Switch off', style: TextStyle(color: AppColors.error)),
                  ),
                ]),
              ),
            ),
        const Divider(height: 32),
        Text('Add a telecaller', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder(), isDense: true)),
        const SizedBox(height: 8),
        TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email (their login)', border: OutlineInputBorder(), isDense: true)),
        const SizedBox(height: 8),
        TextField(
            controller: _password,
            decoration: const InputDecoration(labelText: 'Password (8 characters or more)', border: OutlineInputBorder(), isDense: true)),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _lead,
          onChanged: (v) => setState(() => _lead = v ?? false),
          title: const Text('Team lead (assigns leads, sees everyone\'s numbers)'),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(
            onPressed: () => _do(() async {
              await ApiService.crmAddMember(_name.text.trim(), _email.text.trim(), _password.text, teamLead: _lead);
              _name.clear();
              _email.clear();
              _password.clear();
            }, 'Added. They sign in to Altrobyte Caller with that email and password.'),
            child: const Text('Add'),
          ),
        ),
        if (_said != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_said!)),
      ]);
}

class _Labels extends StatefulWidget {
  const _Labels();

  @override
  State<_Labels> createState() => _LabelsState();
}

class _LabelsState extends State<_Labels> {
  List<String>? _labels;
  final _add = TextEditingController();

  @override
  void initState() {
    super.initState();
    ApiService.crmLabels().then((l) {
      if (mounted) setState(() => _labels = l);
    }).catchError((e) {
      if (mounted) setState(() => _labels = []);
    });
  }

  @override
  void dispose() {
    _add.dispose();
    super.dispose();
  }

  Future<void> _save(List<String> next) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final saved = await ApiService.crmSetLabels(next);
      if (mounted) setState(() => _labels = saved);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(_plain(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_labels == null) return const Center(child: CircularProgressIndicator());
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('Callers tag leads with these from the call log sheet. Removing one keeps it on leads that already have it.',
          style: GoogleFonts.inter(color: AppColors.textSecondary)),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final l in _labels!) InputChip(label: Text(l), onDeleted: () => _save([..._labels!]..remove(l))),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(
          child: TextField(
            controller: _add,
            decoration: const InputDecoration(hintText: 'New label, e.g. wants weekend batch', isDense: true, border: OutlineInputBorder()),
            onSubmitted: (_) => _addOne(),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(onPressed: _addOne, child: const Text('Add')),
      ]),
    ]);
  }

  void _addOne() {
    final t = _add.text.trim();
    if (t.isEmpty) return;
    _add.clear();
    _save([..._labels!, t]);
  }
}

class _Export extends StatefulWidget {
  const _Export();

  @override
  State<_Export> createState() => _ExportState();
}

class _ExportState extends State<_Export> {
  final _sheet = TextEditingController();
  String? _said;

  @override
  void dispose() {
    _sheet.dispose();
    super.dispose();
  }

  Future<void> _csv(String what) async {
    try {
      final bytes = await ApiService.crmExportCsv(what: what);
      downloadBytes('crm-$what.csv', bytes, mime: 'text/csv');
    } catch (e) {
      setState(() => _said = _plain(e));
    }
  }

  Future<void> _run(Future<Map<String, dynamic>> Function() f, String Function(Map<String, dynamic>) say) async {
    try {
      final r = await f();
      setState(() => _said = say(r));
    } catch (e) {
      setState(() => _said = _plain(e));
    }
  }

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [
        Text('Copies for spreadsheets. The CRM stays the master: nothing is read back from these.',
            style: GoogleFonts.inter(color: AppColors.textSecondary)),
        const SizedBox(height: 12),
        Wrap(spacing: 10, runSpacing: 10, children: [
          OutlinedButton.icon(onPressed: () => _csv('leads'), icon: const Icon(Icons.download_rounded), label: const Text('All leads (CSV)')),
          OutlinedButton.icon(onPressed: () => _csv('calls'), icon: const Icon(Icons.download_rounded), label: const Text('All calls (CSV)')),
        ]),
        const Divider(height: 36),
        Text('Nightly Google Sheet', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text('Every night new calls are added to the end of one Google Sheet. Share the sheet (as Editor) with the service '
            'account email, set GOOGLE_SHEETS_SA_JSON on the server, then paste the sheet id here (the long part of its link '
            'between /d/ and /edit).', style: GoogleFonts.inter(color: AppColors.textSecondary, height: 1.4)),
        const SizedBox(height: 10),
        TextField(controller: _sheet, decoration: const InputDecoration(labelText: 'Sheet id', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        Wrap(spacing: 10, children: [
          FilledButton(
            onPressed: () => _run(() => ApiService.crmSetCallsSheet(_sheet.text.trim()),
                (r) => r['service_account_set'] == true ? 'Saved. Calls go there every night.' : 'Saved. The server still needs GOOGLE_SHEETS_SA_JSON.'),
            child: const Text('Save'),
          ),
          OutlinedButton(
            onPressed: () => _run(ApiService.crmPushCallsSheet,
                (r) => (r['pushed'] ?? 0) > 0 ? 'Added ${r['pushed']} calls to the sheet.' : '${r['reason'] ?? 'Nothing new to add.'}'),
            child: const Text('Send new calls now'),
          ),
        ]),
        if (_said != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_said!)),
      ]);
}

/// One lead, everything in order: calls (who, how it went), notes and WhatsApp messages.
class CrmTimelineScreen extends StatefulWidget {
  final String phone;
  final String name;
  const CrmTimelineScreen({super.key, required this.phone, this.name = ''});

  @override
  State<CrmTimelineScreen> createState() => _CrmTimelineScreenState();
}

class _CrmTimelineScreenState extends State<CrmTimelineScreen> {
  Map<String, dynamic>? _data;
  String? _problem;

  @override
  void initState() {
    super.initState();
    ApiService.crmTimeline(widget.phone).then((d) {
      if (mounted) setState(() => _data = d);
    }).catchError((e) {
      if (mounted) setState(() => _problem = _plain(e));
    });
  }

  static const _outcomes = {
    'connected': 'Connected',
    'no_answer': 'No answer',
    'busy': 'Busy',
    'switched_off': 'Switched off',
    'wrong_number': 'Wrong number',
    'call_back': 'Call back later',
  };

  @override
  Widget build(BuildContext context) {
    final events = ((_data?['events'] as List?) ?? const []).cast<Map>();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: Text('Timeline · ${widget.name.isEmpty ? widget.phone : widget.name}',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16)),
      ),
      body: _problem != null
          ? Center(child: Text(_problem!))
          : _data == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(padding: const EdgeInsets.all(16), children: [
                  if ('${_data!['next_step'] ?? ''}'.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text('Next: ${_data!['next_step']}', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                    ),
                  if (events.isEmpty) const Text('Nothing yet.'),
                  for (final e in events) _event(e),
                ]),
    );
  }

  Widget _event(Map e) {
    final at = DateTime.tryParse('${e['at'] ?? ''}')?.toLocal();
    final when = at == null ? '' : '${at.day}/${at.month}/${at.year} ${at.hour}:${at.minute.toString().padLeft(2, '0')}';
    final kind = '${e['kind']}';
    final (icon, color, title) = switch (kind) {
      'call' => (
          e['direction'] == 'in' ? Icons.call_received_rounded : Icons.call_made_rounded,
          AppColors.primary,
          [
            _outcomes[e['outcome']] ?? '${e['outcome']}',
            if ((e['duration_s'] ?? 0) > 0) '${(e['duration_s'] as num) ~/ 60}m ${(e['duration_s'] as num).toInt() % 60}s',
            if ('${e['interest'] ?? ''}'.isNotEmpty) '${e['interest']}',
            if ('${e['stage_after'] ?? ''}'.isNotEmpty) '→ ${e['stage_after']}',
            'by ${e['by']}',
          ].join(' · ')
        ),
      'note' => (Icons.sticky_note_2_outlined, AppColors.accent, 'Note by ${e['by'] ?? ''}'),
      _ => (Icons.chat_rounded, AppColors.whatsapp, e['direction'] == 'in' ? 'WhatsApp from them' : 'WhatsApp from us'),
    };
    final text = [
      if ('${e['lost_reason'] ?? ''}'.isNotEmpty) 'Lost: ${e['lost_reason']}',
      if ('${e['text'] ?? ''}'.isNotEmpty) '${e['text']}',
      if (((e['labels'] as List?) ?? const []).isNotEmpty) 'Labels: ${(e['labels'] as List).join(', ')}',
    ].join('\n');
    return Card(
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13.5)),
        subtitle: Text([if (text.isNotEmpty) text, when].join('\n')),
      ),
    );
  }
}
