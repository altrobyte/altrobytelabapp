// One WhatsApp message to many leads, from the phone (20 Nov 2026, founder: "bulk messaging is still not in this app").
// The same send as the admin CRM (crm_bulk.py): the approved "Hi {{name}}, {{text}}" template, so it reaches people
// outside WhatsApp's 24-hour window too; sent slowly in the background, and each message lands in that lead's chat.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'caller_api.dart';
import 'caller_controller.dart';

const _bar = Color(0xFF1A3C5E);
const _grey = Color(0xFF667781);
const _max = 500;

const _heats = [('', 'All'), ('hot', 'Hot'), ('warm', 'Warm'), ('cold', 'Cold'), ('customer', 'Customers')];

class BulkScreen extends StatefulWidget {
  const BulkScreen({super.key});

  @override
  State<BulkScreen> createState() => _BulkScreenState();
}

class _BulkScreenState extends State<BulkScreen> {
  final _text = TextEditingController();
  final _search = TextEditingController();
  List<Map<String, dynamic>>? _leads;
  List<Map<String, dynamic>> _jobs = [];
  String? _problem;
  String _heat = '';
  String _stage = '';
  String _label = '';
  final Set<String> _off = {};        // leads in the filter the user un-ticked
  DateTime? _later;
  bool _sending = false;

  CallerApi get _api => context.read<CallerController>().api;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _text.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _problem = null);
    try {
      final r = await _api.browse();
      final j = await _api.bulkJobs().catchError((_) => <Map<String, dynamic>>[]);
      if (!mounted) return;
      setState(() {
        _leads = ((r['leads'] as List?) ?? const []).whereType<Map>().map((e) => e.cast<String, dynamic>()).where((l) => l['reachable'] == true).toList();
        _jobs = j;
      });
    } on CallerError catch (e) {
      if (mounted) setState(() => _problem = e.status == 403 ? 'Bulk messages are for the owner and admins.' : e.message);
    }
  }

  String _temp(Map<String, dynamic> l) => '${(l['heat'] as Map?)?['temperature'] ?? ''}';

  List<Map<String, dynamic>> get _inFilter {
    final q = _search.text.trim().toLowerCase();
    return [
      for (final l in _leads ?? const <Map<String, dynamic>>[])
        if ((_heat.isEmpty || _temp(l) == _heat) &&
            (_stage.isEmpty || '${l['stage']}' == _stage) &&
            (_label.isEmpty || ((l['labels'] as List?) ?? const []).contains(_label)) &&
            (q.isEmpty || '${l['name']}'.toLowerCase().contains(q) || '${l['phone']}'.contains(q)))
          l
    ];
  }

  List<Map<String, dynamic>> get _picked => [for (final l in _inFilter) if (!_off.contains('${l['phone']}')) l];

  String _first(Map<String, dynamic>? l) {
    final n = '${l?['name'] ?? ''}'.trim().split(RegExp(r'\s+')).first;
    return n.isEmpty ? 'there' : n[0].toUpperCase() + n.substring(1).toLowerCase();
  }

  Future<void> _pickLater() async {
    final now = DateTime.now();
    final day = await showDatePicker(context: context, firstDate: now, lastDate: now.add(const Duration(days: 30)), initialDate: now);
    if (day == null || !mounted) return;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))));
    if (t == null) return;
    final at = DateTime(day.year, day.month, day.day, t.hour, t.minute);
    setState(() => _later = at.isAfter(now) ? at : null);
  }

  Future<void> _send() async {
    final people = _picked;
    final text = _text.text.trim();
    if (people.isEmpty || text.length < 3) return;
    if (people.length > _max) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('At most $_max at a time. Narrow the filter.')));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_later == null ? 'Send to ${people.length} people now?' : 'Schedule for ${people.length} people?'),
        content: Text('Each one reads:\n\nHi ${_first(people.first)}, $text'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(_later == null ? 'Send' : 'Schedule')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _sending = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final r = await _api.bulk([for (final l in people) '${l['phone']}'], text, sendAt: _later);
      messenger.showSnackBar(SnackBar(
          content: Text(r['scheduled'] != null
              ? 'Scheduled for ${r['scheduled']} people.'
              : 'Sending to ${r['queued']} people, a few at a time. Each one shows in their chat.')));
      _text.clear();
      _later = null;
      await _load();
    } on CallerError catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _cancel(Map<String, dynamic> j) async {
    try {
      await _api.bulkCancel(j['id'] as int);
      await _load();
    } on CallerError catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Widget _chip(String label, bool on, VoidCallback tap) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(label: Text(label), selected: on, onSelected: (_) => tap(), showCheckmark: false),
      );

  @override
  Widget build(BuildContext context) {
    final leads = _leads;
    final stages = {for (final l in leads ?? const <Map<String, dynamic>>[]) '${l['stage']}'}.toList()..sort();
    final labels = {for (final l in leads ?? const <Map<String, dynamic>>[]) ...((l['labels'] as List?) ?? const []).map((e) => '$e')}.toList()..sort();
    final shown = _inFilter;
    final picked = _picked;
    return Scaffold(
      appBar: AppBar(backgroundColor: _bar, foregroundColor: Colors.white, title: const Text('Bulk message')),
      body: _problem != null
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Padding(padding: const EdgeInsets.all(24), child: Text(_problem!, textAlign: TextAlign.center)),
              TextButton(onPressed: _load, child: const Text('Try again')),
            ]))
          : leads == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(padding: const EdgeInsets.fromLTRB(14, 12, 14, 24), children: [
                  const Text('1. Who gets it', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 6),
                  SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
                    for (final h in _heats) _chip(h.$2, _heat == h.$1, () => setState(() { _heat = h.$1; _off.clear(); })),
                  ])),
                  if (stages.length > 1)
                    SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
                      _chip('Any stage', _stage.isEmpty, () => setState(() { _stage = ''; _off.clear(); })),
                      for (final s in stages) _chip(s.replaceAll('_', ' '), _stage == s, () => setState(() { _stage = s; _off.clear(); })),
                    ])),
                  if (labels.isNotEmpty)
                    SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
                      _chip('Any label', _label.isEmpty, () => setState(() { _label = ''; _off.clear(); })),
                      for (final s in labels) _chip(s, _label == s, () => setState(() { _label = s; _off.clear(); })),
                    ])),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search name or number', isDense: true, prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  Row(children: [
                    Expanded(child: Text('${picked.length} of ${shown.length} ticked', style: const TextStyle(color: _grey, fontSize: 13))),
                    TextButton(onPressed: () => setState(() => _off.clear()), child: const Text('Tick all')),
                    TextButton(onPressed: () => setState(() => _off.addAll(shown.map((l) => '${l['phone']}'))), child: const Text('None')),
                  ]),
                  Container(
                    height: 260,
                    decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE0E0E0)), borderRadius: BorderRadius.circular(12)),
                    child: shown.isEmpty
                        ? const Center(child: Text('Nobody in this filter.', style: TextStyle(color: _grey)))
                        : ListView.builder(
                            itemCount: shown.length,
                            itemBuilder: (_, i) {
                              final l = shown[i], p = '${l['phone']}';
                              return CheckboxListTile(
                                dense: true,
                                value: !_off.contains(p),
                                onChanged: (v) => setState(() => v == true ? _off.remove(p) : _off.add(p)),
                                title: Text('${l['name']}'.isEmpty ? p : '${l['name']}'),
                                subtitle: Text('${_temp(l)} · ${'${l['stage']}'.replaceAll('_', ' ')}'),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 16),
                  const Text('2. The message', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _text,
                    maxLines: 5,
                    maxLength: 900,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                        border: OutlineInputBorder(), hintText: 'e.g. our free live demo is this Saturday at 6 pm. Reply YES to get the link.'),
                  ),
                  const Text('They will read:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0xFFDCF8C6), borderRadius: BorderRadius.circular(8)),
                    child: Text('Hi ${_first(picked.isEmpty ? null : picked.first)}, ${_text.text.trim()}'),
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    Icon(Icons.schedule_rounded, size: 18, color: _later == null ? Colors.black38 : _bar),
                    const SizedBox(width: 6),
                    Expanded(child: Text(_later == null
                        ? 'Sends now'
                        : 'Sends ${MaterialLocalizations.of(context).formatMediumDate(_later!)} at ${TimeOfDay.fromDateTime(_later!).format(context)}')),
                    TextButton(onPressed: _pickLater, child: Text(_later == null ? 'Send later' : 'Change')),
                    if (_later != null) TextButton(onPressed: () => setState(() => _later = null), child: const Text('Now')),
                  ]),
                  const SizedBox(height: 6),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF008069), minimumSize: const Size.fromHeight(48)),
                    onPressed: _sending || picked.isEmpty || _text.text.trim().length < 3 ? null : _send,
                    icon: const Icon(Icons.send),
                    label: Text(_sending ? 'Sending…' : (_later == null ? 'Send to ${picked.length}' : 'Schedule for ${picked.length}')),
                  ),
                  if (_jobs.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    const Text('Scheduled and sent', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    for (final j in _jobs)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('${j['text']}', maxLines: 2, overflow: TextOverflow.ellipsis),
                        subtitle: Text('${j['people']} people · ${j['status']} · ${_when('${j['send_at']}')}'),
                        trailing: j['status'] == 'waiting' ? TextButton(onPressed: () => _cancel(j), child: const Text('Cancel')) : null,
                      ),
                  ],
                ]),
    );
  }

  String _when(String iso) {
    final d = DateTime.tryParse(iso)?.toLocal();
    if (d == null) return '';
    return '${MaterialLocalizations.of(context).formatShortDate(d)} ${TimeOfDay.fromDateTime(d).format(context)}';
  }
}
