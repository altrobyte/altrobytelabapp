// Bulk WhatsApp from the phone (20 Nov 2026, founder: "bulk messaging, with template management, and see what worked").
// Three tabs: Send (pick leads, pick an approved template, add the photo / PDF it needs, now or later), Templates (every
// template on Meta with its status; make a new one and send it for approval; delete) and Report (each campaign: sent,
// not sent and why, replied, booked a call, moved forward; tap for person by person). Backend: crm_campaigns.py.
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'caller_api.dart';
import 'caller_controller.dart';

const _bar = Color(0xFF1A3C5E);
const _teal = Color(0xFF008069);
const _grey = Color(0xFF667781);
const _max = 500;

const _heats = [('', 'All'), ('hot', 'Hot'), ('warm', 'Warm'), ('cold', 'Cold'), ('customer', 'Customers')];

String _firstName(Object? name) {
  final n = '${name ?? ''}'.trim().split(RegExp(r'\s+')).first;
  return n.isEmpty ? 'there' : n[0].toUpperCase() + n.substring(1).toLowerCase();
}

/// The template's words as the lead reads them.
String _filled(Map<String, dynamic> t, String name, String text) {
  final vars = ((t['vars'] as List?) ?? const []).map((e) => '$e').toList();
  var body = '${t['body'] ?? ''}';
  for (var i = 0; i < vars.length; i++) {
    body = body.replaceAll('{{${i + 1}}}', vars[i] == 'name' ? name : (text.isEmpty ? '…' : text));
  }
  return body;
}

String _when(BuildContext context, String iso) {
  final d = DateTime.tryParse(iso)?.toLocal();
  if (d == null) return '';
  return '${MaterialLocalizations.of(context).formatShortDate(d)} ${TimeOfDay.fromDateTime(d).format(context)}';
}

class BulkScreen extends StatelessWidget {
  const BulkScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: _bar,
          foregroundColor: Colors.white,
          title: const Text('Bulk WhatsApp'),
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [Tab(text: 'Send'), Tab(text: 'Templates'), Tab(text: 'Report')],
          ),
        ),
        body: const TabBarView(children: [_SendTab(), _TemplatesTab(), _ReportTab()]),
      ),
    );
  }
}

// ── Send ───────────────────────────────────────────────────────────────────

class _SendTab extends StatefulWidget {
  const _SendTab();

  @override
  State<_SendTab> createState() => _SendTabState();
}

class _SendTabState extends State<_SendTab> with AutomaticKeepAliveClientMixin {
  final _text = TextEditingController();
  final _search = TextEditingController();
  List<Map<String, dynamic>>? _leads;
  List<Map<String, dynamic>> _templates = [];
  Map<String, dynamic>? _tpl;
  String? _problem;
  String _heat = '', _stage = '', _label = '';
  final Set<String> _off = {};
  DateTime? _later;
  bool _sending = false, _uploading = false;
  Map<String, dynamic>? _media; // {media_id, kind, filename}

  CallerApi get _api => context.read<CallerController>().api;

  @override
  bool get wantKeepAlive => true;

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
      List<Map<String, dynamic>> t = [];
      try {
        t = (await _api.waTemplates()).where((x) => x['status'] == 'approved').toList();
      } on CallerError {
        t = [];
      }
      if (!mounted) return;
      setState(() {
        _leads = ((r['leads'] as List?) ?? const []).whereType<Map>().map((e) => e.cast<String, dynamic>()).where((l) => l['reachable'] == true).toList();
        _templates = t;
        _tpl ??= t.where((x) => x['name'] == 't1_lab_update').firstOrNull ?? t.firstOrNull;
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

  bool get _needsText => ((_tpl?['vars'] as List?) ?? const []).contains('text');
  String get _mediaKind => '${_tpl?['header_kind'] ?? ''}';
  bool get _needsMedia => const ['image', 'document', 'video'].contains(_mediaKind);

  Future<void> _pickMedia() async {
    final ext = switch (_mediaKind) { 'image' => ['jpg', 'jpeg', 'png'], 'video' => ['mp4'], _ => ['pdf'] };
    final f = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ext, withData: true);
    final file = f?.files.firstOrNull;
    if (file == null || file.bytes == null || !mounted) return;
    setState(() => _uploading = true);
    try {
      final r = await _api.campaignMedia(file.bytes!, file.name);
      if (mounted) setState(() => _media = r);
    } on CallerError catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
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

  bool get _ready =>
      !_sending && _tpl != null && _picked.isNotEmpty && (!_needsText || _text.text.trim().length >= 3) && (!_needsMedia || _media != null);

  Future<void> _send() async {
    final people = _picked, tpl = _tpl!;
    if (people.length > _max) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('At most $_max at a time. Narrow the filter.')));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_later == null ? 'Send to ${people.length} people now?' : 'Schedule for ${people.length} people?'),
        content: Text('Each one reads:\n\n${_filled(tpl, _firstName(people.first['name']), _text.text.trim())}'
            '${_media != null ? '\n\n+ ${_media!['filename']}' : ''}'),
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
      final r = await _api.campaign({
        'phones': [for (final l in people) '${l['phone']}'],
        'template': tpl['name'],
        'language': tpl['language'],
        'category': tpl['category'],
        'vars': tpl['vars'],
        'text': _text.text.trim(),
        if (_media != null) ...{'media_kind': _media!['kind'], 'media_id': _media!['media_id'], 'media_name': _media!['filename']},
        'send_at': (_later ?? DateTime.now()).toUtc().toIso8601String(),
      });
      messenger.showSnackBar(SnackBar(
          content: Text(r['scheduled'] == true
              ? 'Scheduled for ${r['people']} people. See it in Report.'
              : 'Sending to ${r['people']} people, a few at a time. See how it goes in Report.')));
      setState(() {
        _text.clear();
        _later = null;
        _media = null;
      });
    } on CallerError catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Widget _chip(String label, bool on, VoidCallback tap) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(label: Text(label), selected: on, onSelected: (_) => tap(), showCheckmark: false),
      );

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final leads = _leads;
    if (_problem != null) {
      return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(padding: const EdgeInsets.all(24), child: Text(_problem!, textAlign: TextAlign.center)),
        TextButton(onPressed: _load, child: const Text('Try again')),
      ]));
    }
    if (leads == null) return const Center(child: CircularProgressIndicator());
    final stages = {for (final l in leads) '${l['stage']}'}.toList()..sort();
    final labels = {for (final l in leads) ...((l['labels'] as List?) ?? const []).map((e) => '$e')}.toList()..sort();
    final shown = _inFilter, picked = _picked, tpl = _tpl;
    return ListView(padding: const EdgeInsets.fromLTRB(14, 12, 14, 24), children: [
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
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
      ),
      Row(children: [
        Expanded(child: Text('${picked.length} of ${shown.length} ticked', style: const TextStyle(color: _grey, fontSize: 13))),
        TextButton(onPressed: () => setState(() => _off.clear()), child: const Text('Tick all')),
        TextButton(onPressed: () => setState(() => _off.addAll(shown.map((l) => '${l['phone']}'))), child: const Text('None')),
      ]),
      Container(
        height: 240,
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
      const Text('2. Template', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
      const SizedBox(height: 6),
      if (_templates.isEmpty)
        const Text('No approved template found. Make one in the Templates tab.', style: TextStyle(color: _grey))
      else
        DropdownButtonFormField<String>(
          initialValue: tpl?['name'] as String?,
          isExpanded: true,
          decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
          items: [
            for (final t in _templates)
              DropdownMenuItem(
                  value: '${t['name']}',
                  child: Text('${t['name']}  ·  ${'${t['category']}'.toLowerCase()}${'${t['header_kind']}'.isNotEmpty && t['header_kind'] != 'text' ? '  ·  ${t['header_kind']}' : ''}',
                      overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (v) => setState(() {
            _tpl = _templates.firstWhere((t) => t['name'] == v);
            _media = null;
          }),
        ),
      if (tpl != null) ...[
        const SizedBox(height: 10),
        if (_needsText) ...[
          TextField(
            controller: _text,
            maxLines: 4,
            maxLength: 900,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
                border: OutlineInputBorder(), labelText: 'Your message', hintText: 'e.g. our free live demo is this Saturday at 6 pm. Reply YES to get the link.'),
          ),
        ],
        if (_needsMedia)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: OutlinedButton.icon(
              onPressed: _uploading ? null : _pickMedia,
              icon: Icon(_mediaKind == 'image' ? Icons.image_outlined : (_mediaKind == 'video' ? Icons.movie_outlined : Icons.picture_as_pdf_outlined)),
              label: Text(_uploading
                  ? 'Uploading…'
                  : (_media != null ? '${_media!['filename']} ✓ (change)' : 'Add the ${_mediaKind == 'document' ? 'PDF' : _mediaKind}')),
            ),
          ),
        const Text('They will read:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: const Color(0xFFDCF8C6), borderRadius: BorderRadius.circular(8)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (_needsMedia) Text(_media != null ? '📎 ${_media!['filename']}' : '📎 (${_mediaKind == 'document' ? 'PDF' : _mediaKind})', style: const TextStyle(color: _grey)),
            if ('${tpl['header']}'.isNotEmpty) Text('${tpl['header']}', style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(_filled(tpl, _firstName(picked.isEmpty ? null : picked.first['name']), _text.text.trim())),
            if ('${tpl['footer']}'.isNotEmpty) Text('${tpl['footer']}', style: const TextStyle(color: _grey, fontSize: 12)),
            for (final b in (tpl['buttons'] as List? ?? const [])) Text('▸ ${(b as Map)['text']}', style: const TextStyle(color: Color(0xFF027EB5))),
          ]),
        ),
      ],
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
        style: FilledButton.styleFrom(backgroundColor: _teal, minimumSize: const Size.fromHeight(48)),
        onPressed: _ready ? _send : null,
        icon: const Icon(Icons.send),
        label: Text(_sending ? 'Sending…' : (_later == null ? 'Send to ${picked.length}' : 'Schedule for ${picked.length}')),
      ),
    ]);
  }
}

// ── Templates ──────────────────────────────────────────────────────────────

class _TemplatesTab extends StatefulWidget {
  const _TemplatesTab();

  @override
  State<_TemplatesTab> createState() => _TemplatesTabState();
}

class _TemplatesTabState extends State<_TemplatesTab> {
  List<Map<String, dynamic>>? _list;
  String? _problem;

  CallerApi get _api => context.read<CallerController>().api;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _problem = null);
    try {
      final t = await _api.waTemplates();
      if (mounted) setState(() => _list = t);
    } on CallerError catch (e) {
      if (mounted) setState(() => _problem = e.message);
    }
  }

  Future<void> _delete(Map<String, dynamic> t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${t['name']}?'),
        content: const Text('WhatsApp does not let the same name be used again for about 4 weeks.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.deleteTemplate('${t['name']}');
      await _load();
    } on CallerError catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _list;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'newtpl',
        backgroundColor: _teal,
        foregroundColor: Colors.white,
        onPressed: () async {
          final made = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const _NewTemplate()));
          if (made == true) _load();
        },
        icon: const Icon(Icons.add),
        label: const Text('New template'),
      ),
      body: _problem != null
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Padding(padding: const EdgeInsets.all(24), child: Text(_problem!, textAlign: TextAlign.center)),
              TextButton(onPressed: _load, child: const Text('Try again')),
            ]))
          : list == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(padding: const EdgeInsets.fromLTRB(12, 12, 12, 90), children: [
                    const Text('Approval by WhatsApp takes a few minutes to a day. Pull down to refresh.', style: TextStyle(color: _grey, fontSize: 12.5)),
                    const SizedBox(height: 8),
                    for (final t in list) _card(t),
                  ]),
                ),
    );
  }

  Widget _card(Map<String, dynamic> t) {
    final s = '${t['status']}';
    final color = s == 'approved' ? Colors.green : (s == 'rejected' || s == 'disabled' || s == 'paused' ? Colors.red : Colors.orange);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('${t['name']}', style: const TextStyle(fontWeight: FontWeight.w700))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: color.withValues(alpha: .14), borderRadius: BorderRadius.circular(99)),
              child: Text(s == 'pending' ? 'waiting for approval' : s, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ]),
          Text('${'${t['category']}'.toLowerCase()} · ${t['language']}${'${t['header_kind']}'.isNotEmpty ? ' · ${t['header_kind']} header' : ''}',
              style: const TextStyle(color: _grey, fontSize: 12)),
          const SizedBox(height: 6),
          Text(_filled(t, 'Rahul', '<your message>'), style: const TextStyle(fontSize: 13.5)),
          if ('${t['rejected_reason']}'.isNotEmpty) Text('Why rejected: ${t['rejected_reason']}', style: const TextStyle(color: Colors.red, fontSize: 12.5)),
          if (!'${t['name']}'.startsWith('t1_lab_'))
            Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => _delete(t), child: const Text('Delete'))),
        ]),
      ),
    );
  }
}

class _NewTemplate extends StatefulWidget {
  const _NewTemplate();

  @override
  State<_NewTemplate> createState() => _NewTemplateState();
}

class _NewTemplateState extends State<_NewTemplate> {
  final _name = TextEditingController(), _body = TextEditingController(text: 'Hi {{name}}, ');
  final _headerText = TextEditingController(), _footer = TextEditingController(text: 'Reply STOP to unsubscribe');
  final _btnText = TextEditingController(), _btnUrl = TextEditingController(), _quick = TextEditingController();
  String _category = 'MARKETING', _header = '';
  PlatformFile? _sample;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_name, _body, _headerText, _footer, _btnText, _btnUrl, _quick]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickSample() async {
    final ext = switch (_header) { 'image' => ['jpg', 'jpeg', 'png'], 'video' => ['mp4'], _ => ['pdf'] };
    final f = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ext, withData: true);
    if (f?.files.firstOrNull != null) setState(() => _sample = f!.files.first);
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    final api = context.read<CallerController>().api;
    try {
      final r = await api.createTemplate({
        'name': _name.text.trim(),
        'category': _category,
        'language': 'en',
        'body': _body.text.trim(),
        'header_kind': _header,
        'header_text': _headerText.text.trim(),
        'footer': _footer.text.trim(),
        'button_text': _btnText.text.trim(),
        'button_url': _btnUrl.text.trim(),
        'quick_replies': _quick.text.trim(),
      }, sample: _sample?.bytes, sampleName: _sample?.name);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sent to WhatsApp for approval: ${r['name']}')));
      Navigator.pop(context, true);
    } on CallerError catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), duration: const Duration(seconds: 8)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = const ['image', 'document', 'video'].contains(_header);
    final preview = _body.text.replaceAll(RegExp(r'\{\{\s*name\s*\}\}', caseSensitive: false), 'Rahul')
        .replaceAll(RegExp(r'\{\{\s*text\s*\}\}', caseSensitive: false), '<your message at send time>');
    return Scaffold(
      appBar: AppBar(backgroundColor: _bar, foregroundColor: Colors.white, title: const Text('New template')),
      body: ListView(padding: const EdgeInsets.all(14), children: [
        TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name (e.g. demo saturday offer)', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        SegmentedButton<String>(
          segments: const [ButtonSegment(value: 'MARKETING', label: Text('Marketing')), ButtonSegment(value: 'UTILITY', label: Text('Utility'))],
          selected: {_category},
          onSelectionChanged: (s) => setState(() => _category = s.first),
        ),
        const Text('Offers, demos, fees: Marketing. Reminders and updates for someone who signed up: Utility.', style: TextStyle(color: _grey, fontSize: 12)),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _header,
          decoration: const InputDecoration(labelText: 'Header', border: OutlineInputBorder(), isDense: true),
          items: const [
            DropdownMenuItem(value: '', child: Text('None')),
            DropdownMenuItem(value: 'text', child: Text('Bold title')),
            DropdownMenuItem(value: 'image', child: Text('Photo')),
            DropdownMenuItem(value: 'document', child: Text('PDF')),
            DropdownMenuItem(value: 'video', child: Text('Video')),
          ],
          onChanged: (v) => setState(() {
            _header = v ?? '';
            _sample = null;
          }),
        ),
        if (_header == 'text')
          Padding(padding: const EdgeInsets.only(top: 8), child: TextField(controller: _headerText, maxLength: 60, decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()))),
        if (media)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: OutlinedButton.icon(
              onPressed: _pickSample,
              icon: const Icon(Icons.attach_file),
              label: Text(_sample != null ? '${_sample!.name} ✓' : 'Add a sample ${_header == 'document' ? 'PDF' : _header} (WhatsApp asks for one)'),
            ),
          ),
        const SizedBox(height: 12),
        TextField(
          controller: _body,
          maxLines: 6,
          maxLength: 1000,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(labelText: 'Message', border: OutlineInputBorder(), alignLabelWithHint: true),
        ),
        const Text('{{name}} = the lead\'s first name.  {{text}} = a line you type each time you send (leave it out for a fixed message). '
            'Not at the very start or end.', style: TextStyle(color: _grey, fontSize: 12)),
        const SizedBox(height: 10),
        TextField(controller: _footer, maxLength: 60, decoration: const InputDecoration(labelText: 'Footer (optional)', border: OutlineInputBorder())),
        TextField(controller: _btnText, maxLength: 25, decoration: const InputDecoration(labelText: 'Link button text (optional), e.g. Book my seat', border: OutlineInputBorder())),
        const SizedBox(height: 8),
        TextField(controller: _btnUrl, decoration: const InputDecoration(labelText: 'Link (https://…)', border: OutlineInputBorder())),
        const SizedBox(height: 8),
        TextField(controller: _quick, decoration: const InputDecoration(labelText: 'Reply buttons (optional), split with |  e.g. Yes, interested | Call me', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        const Text('Preview', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 4),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: const Color(0xFFDCF8C6), borderRadius: BorderRadius.circular(8)),
          child: Text(preview),
        ),
        const SizedBox(height: 14),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: _teal, minimumSize: const Size.fromHeight(48)),
          onPressed: _busy || (media && _sample == null) ? null : _submit,
          child: Text(_busy ? 'Sending…' : 'Send to WhatsApp for approval'),
        ),
      ]),
    );
  }
}

// ── Report ─────────────────────────────────────────────────────────────────

class _ReportTab extends StatefulWidget {
  const _ReportTab();

  @override
  State<_ReportTab> createState() => _ReportTabState();
}

class _ReportTabState extends State<_ReportTab> {
  List<Map<String, dynamic>>? _list;
  String? _problem;

  CallerApi get _api => context.read<CallerController>().api;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _problem = null);
    try {
      final c = await _api.campaigns();
      if (mounted) setState(() => _list = c);
    } on CallerError catch (e) {
      if (mounted) setState(() => _problem = e.message);
    }
  }

  Future<void> _cancel(Map<String, dynamic> c) async {
    try {
      await _api.campaignCancel(c['id'] as int);
      await _load();
    } on CallerError catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _list;
    if (_problem != null) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(padding: const EdgeInsets.all(24), child: Text(_problem!, textAlign: TextAlign.center)),
        TextButton(onPressed: _load, child: const Text('Try again')),
      ]));
    }
    if (list == null) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _load,
      child: list.isEmpty
          ? ListView(children: const [Padding(padding: EdgeInsets.all(32), child: Text('No campaigns yet.', textAlign: TextAlign.center, style: TextStyle(color: _grey)))])
          : ListView(padding: const EdgeInsets.all(12), children: [for (final c in list) _card(c)]),
    );
  }

  Widget _stat(String n, String label, Color color) => Expanded(
        child: Column(children: [
          Text(n, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: color)),
          Text(label, style: const TextStyle(fontSize: 11.5, color: _grey), textAlign: TextAlign.center),
        ]),
      );

  Widget _card(Map<String, dynamic> c) {
    final status = '${c['status']}';
    final why = Map<String, dynamic>.from((c['why_not'] as Map?) ?? const {});
    return Card(
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _CampaignPeople(id: c['id'] as int))),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text('${c['template']}', style: const TextStyle(fontWeight: FontWeight.w700))),
              Text(status == 'taken' ? 'sending' : status, style: const TextStyle(color: _grey, fontSize: 12)),
            ]),
            Text('${_when(context, '${c['send_at']}')} · ${c['people']} people${'${c['author']}'.isNotEmpty ? ' · ${c['author']}' : ''}',
                style: const TextStyle(color: _grey, fontSize: 12)),
            if ('${c['text']}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('${c['text']}', maxLines: 2, overflow: TextOverflow.ellipsis)),
            const SizedBox(height: 10),
            Row(children: [
              _stat('${c['sent']}', 'sent', _bar),
              _stat('${c['not_sent']}', 'not sent', Colors.red),
              _stat('${c['replied']}', 'replied', _teal),
              _stat('${c['booked']}', 'booked a call', Colors.deepPurple),
              _stat('${c['keen']}', 'moved forward', Colors.orange),
            ]),
            if (why.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Not sent: ${why.entries.map((e) => '${e.key} (${e.value})').join(', ')}', style: const TextStyle(color: Colors.red, fontSize: 12)),
              ),
            if (status == 'waiting') Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => _cancel(c), child: const Text('Cancel'))),
          ]),
        ),
      ),
    );
  }
}

class _CampaignPeople extends StatefulWidget {
  final int id;
  const _CampaignPeople({required this.id});

  @override
  State<_CampaignPeople> createState() => _CampaignPeopleState();
}

class _CampaignPeopleState extends State<_CampaignPeople> {
  Map<String, dynamic>? _c;
  String? _problem;
  String _show = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final c = await context.read<CallerController>().api.campaignOne(widget.id);
      if (mounted) setState(() => _c = c);
    } on CallerError catch (e) {
      if (mounted) setState(() => _problem = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    final people = ((c?['people_list'] as List?) ?? const []).whereType<Map>().map((e) => e.cast<String, dynamic>()).where((p) => switch (_show) {
          'replied' => p['replied'] == true,
          'not' => p['state'] == 'not sent',
          'silent' => p['state'] == 'sent' && p['replied'] != true,
          _ => true,
        }).toList();
    return Scaffold(
      appBar: AppBar(backgroundColor: _bar, foregroundColor: Colors.white, title: Text(c == null ? 'Campaign' : '${c['template']}')),
      body: _problem != null
          ? Center(child: Text(_problem!))
          : c == null
              ? const Center(child: CircularProgressIndicator())
              : Column(children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.all(8),
                    child: Row(children: [
                      for (final f in const [('all', 'Everyone'), ('replied', 'Replied'), ('silent', 'No reply yet'), ('not', 'Not sent')])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(label: Text(f.$2), selected: _show == f.$1, showCheckmark: false, onSelected: (_) => setState(() => _show = f.$1)),
                        ),
                    ]),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: people.length,
                      itemBuilder: (_, i) {
                        final p = people[i];
                        return ListTile(
                          dense: true,
                          leading: Icon(
                              p['replied'] == true ? Icons.reply : (p['state'] == 'sent' ? Icons.done : (p['state'] == 'waiting' ? Icons.schedule : Icons.error_outline)),
                              color: p['replied'] == true ? _teal : (p['state'] == 'not sent' ? Colors.red : _grey)),
                          title: Text('${p['name']}'.isEmpty ? '${p['phone']}' : '${p['name']}'),
                          subtitle: Text([
                            '${p['phone']}',
                            if ('${p['stage']}'.isNotEmpty) '${p['stage']}'.replaceAll('_', ' '),
                            if ('${p['reason']}'.isNotEmpty) '${p['reason']}',
                          ].join(' · ')),
                        );
                      },
                    ),
                  ),
                ]),
    );
  }
}
