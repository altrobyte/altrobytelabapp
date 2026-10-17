// For team leads: everyone's numbers, and the leads nobody has yet, dealt out to the team in turn.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_colors.dart';
import 'caller_api.dart';
import 'caller_controller.dart';
import 'models.dart';
import 'widgets.dart';

class TeamScreen extends StatelessWidget {
  const TeamScreen({super.key});

  @override
  Widget build(BuildContext context) => const DefaultTabController(
        length: 2,
        child: Column(children: [
          TabBar(labelColor: AppColors.primary, tabs: [Tab(text: 'Leaderboard'), Tab(text: 'Unassigned')]),
          Expanded(child: TabBarView(children: [Leaderboard(), UnassignedLeads()])),
        ]),
      );
}

String talk(int s) => s >= 3600 ? '${s ~/ 3600}h ${(s % 3600) ~/ 60}m' : '${s ~/ 60}m';

class Leaderboard extends StatefulWidget {
  const Leaderboard({super.key});

  @override
  State<Leaderboard> createState() => _LeaderboardState();
}

class _LeaderboardState extends State<Leaderboard> {
  int _days = 1;
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
      final d = await context.read<CallerController>().api.teamStats(_days);
      if (mounted) setState(() => _data = d);
    } on CallerError catch (e) {
      if (mounted) setState(() => _problem = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = ((_data?['team'] as List?) ?? const []).map((e) => (e as Map).cast<String, dynamic>()).toList();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.all(12), children: [
        Wrap(spacing: 8, children: [
          for (final d in const [1, 7, 30])
            ChoiceChip(
              label: Text(d == 1 ? 'Today' : 'Last $d days'),
              selected: _days == d,
              onSelected: (_) {
                setState(() => _days = d);
                _load();
              },
            ),
        ]),
        const SizedBox(height: 8),
        if (_problem != null)
          Column(children: [Text(_problem!), TextButton(onPressed: _load, child: const Text('Try again'))])
        else if (_data == null)
          const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
        else
          for (final (i, r) in rows.indexed)
            Card(
              child: ListTile(
                leading: CircleAvatar(
                    backgroundColor: i == 0 ? AppColors.accent : AppColors.primaryLight,
                    foregroundColor: Colors.white,
                    child: Text('${i + 1}')),
                title: Text('${r['name']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('${r['calls']} calls · ${r['connected_pct']}% connected · talked ${talk((r['talk_time_s'] as num).toInt())}\n'
                    '${r['interested']} interested · follow-ups ${r['followups_done']} done, ${r['followups_missed']} missed'),
                isThreeLine: true,
                trailing: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('${r['conversions']}',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.success)),
                  const Text('converted', style: TextStyle(fontSize: 11)),
                ]),
              ),
            ),
      ]),
    );
  }
}

class UnassignedLeads extends StatefulWidget {
  const UnassignedLeads({super.key});

  @override
  State<UnassignedLeads> createState() => _UnassignedLeadsState();
}

class _UnassignedLeadsState extends State<UnassignedLeads> {
  List<Lead>? _leads;
  List<Map<String, dynamic>> _team = [];
  final Set<String> _picked = {};
  final Set<String> _to = {};
  String? _problem;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = context.read<CallerController>().api;
    setState(() => _problem = null);
    try {
      final leads = await api.unassigned();
      final team = await api.team();
      if (!mounted) return;
      setState(() {
        _leads = leads.map(Lead.fromJson).toList();
        _team = team;
        _picked.clear();
        if (_to.isEmpty) _to.addAll(team.map((m) => '${m['login']}'));
      });
    } on CallerError catch (e) {
      if (mounted) setState(() => _problem = e.message);
    }
  }

  Future<void> _assign() async {
    setState(() => _busy = true);
    final c = context.read<CallerController>();
    try {
      final phones = _picked.isEmpty ? _leads!.map((l) => l.phone).toList() : _picked.toList();
      final r = await c.api.assign(phones, roundRobin: _to.toList());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${r['assigned']} leads shared out.')));
      await _load();
    } on CallerError catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_problem != null) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(_problem!),
        TextButton(onPressed: _load, child: const Text('Try again')),
      ]));
    }
    if (_leads == null) return const Center(child: CircularProgressIndicator());
    final n = _picked.isEmpty ? _leads!.length : _picked.length;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
        child: Wrap(spacing: 6, runSpacing: 6, children: [
          for (final m in _team)
            FilterChip(
              label: Text('${m['name']} (${m['open_leads']})'),
              selected: _to.contains('${m['login']}'),
              onSelected: (on) => setState(() => on ? _to.add('${m['login']}') : _to.remove('${m['login']}')),
            ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.all(12),
        child: FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: AppColors.accent, minimumSize: const Size.fromHeight(48)),
          onPressed: _busy || _leads!.isEmpty || _to.isEmpty ? null : _assign,
          icon: const Icon(Icons.shuffle),
          label: Text('Assign $n round-robin to ${_to.length} ${_to.length == 1 ? 'person' : 'people'}'),
        ),
      ),
      Expanded(
        child: RefreshIndicator(
          onRefresh: _load,
          child: _leads!.isEmpty
              ? ListView(children: const [Padding(padding: EdgeInsets.all(32), child: Text('Every lead has someone.', textAlign: TextAlign.center))])
              : ListView(children: [
                  for (final l in _leads!)
                    CheckboxListTile(
                      value: _picked.contains(l.phone),
                      onChanged: (on) => setState(() => on == true ? _picked.add(l.phone) : _picked.remove(l.phone)),
                      title: Text(l.displayName),
                      subtitle: Row(children: [HeatBadge(l.heat), const SizedBox(width: 6), Tag(stages[l.stage] ?? l.stage)]),
                    ),
                ]),
        ),
      ),
    ]);
  }
}
