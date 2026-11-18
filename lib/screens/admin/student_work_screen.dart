import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/api_service.dart';

/// Student work (18 Nov 2026, founder): every assignment hand-in; Publish puts it on altrobytelab.com/work with a short
/// AI-written post (by name only when the learner agreed), Hide takes it off. "Add" enters a hand-in sent on WhatsApp.
class StudentWorkScreen extends StatefulWidget {
  const StudentWorkScreen({super.key});

  @override
  State<StudentWorkScreen> createState() => _StudentWorkScreenState();
}

class _StudentWorkScreenState extends State<StudentWorkScreen> {
  List<Map<String, dynamic>>? _work;
  String? _error;
  final Set<int> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await ApiService.studentWork();
      setState(() {
        _work = [for (final w in (d['work'] as List? ?? const [])) Map<String, dynamic>.from(w as Map)];
        _error = null;
      });
    } catch (e) {
      setState(() => _error = 'Could not load the student work. Pull to try again.');
    }
  }

  Future<void> _act(Map<String, dynamic> w, String what) async {
    final id = w['id'] as int;
    setState(() => _busy.add(id));
    try {
      final r = await ApiService.studentWorkAct(id, what);
      if (!mounted) return;
      if (what == 'publish' && r['slug'] != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Published: altrobytelab.com/work/${r['slug']}')));
      }
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not do that just now. Try again.')));
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  Future<void> _add() async {
    final name = TextEditingController(), title = TextEditingController(), mentor = TextEditingController(text: 'Pawan Meena');
    final link = TextEditingController(), learned = TextEditingController(), phone = TextEditingController();
    var consent = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: const Text('Add a hand-in'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Learner name')),
                TextField(controller: phone, decoration: const InputDecoration(labelText: 'WhatsApp number (optional)')),
                TextField(controller: title, decoration: const InputDecoration(labelText: 'Assignment')),
                TextField(controller: mentor, decoration: const InputDecoration(labelText: 'Mentor')),
                TextField(controller: link, decoration: const InputDecoration(labelText: 'Link to the work (https://…)')),
                TextField(controller: learned, maxLines: 3, decoration: const InputDecoration(labelText: 'What they learnt (their words)')),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: consent,
                  onChanged: (v) => set(() => consent = v ?? false),
                  title: const Text('The learner agreed to be shown by name'),
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await ApiService.studentWorkAdd({
        'name': name.text.trim(), 'phone': phone.text.trim(), 'title': title.text.trim(), 'mentor': mentor.text.trim(),
        'link': link.text.trim(), 'learned': learned.text.trim(), 'consent': consent,
      });
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = _work;
    return Scaffold(
      appBar: AppBar(title: const Text('Student work'), actions: [
        TextButton.icon(onPressed: () => launchUrl(Uri.parse('https://altrobytelab.com/work')), icon: const Icon(Icons.open_in_new), label: const Text('Public page')),
      ]),
      floatingActionButton: FloatingActionButton.extended(onPressed: _add, icon: const Icon(Icons.add), label: const Text('Add')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _error != null
            ? ListView(children: [Padding(padding: const EdgeInsets.all(24), child: Text(_error!))])
            : w == null
                ? const Center(child: CircularProgressIndicator())
                : w.isEmpty
                    ? ListView(children: const [Padding(padding: EdgeInsets.all(24), child: Text('No hand-ins yet.'))])
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
                        itemCount: w.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) => _card(w[i]),
                      ),
      ),
    );
  }

  Widget _card(Map<String, dynamic> w) {
    final status = '${w['status'] ?? 'new'}';
    final busy = _busy.contains(w['id']);
    final color = status == 'published' ? Colors.green : (status == 'hidden' ? Colors.grey : Colors.orange);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('${w['name'] ?? ''} · ${'${w['title'] ?? ''}'.replaceFirst('Assignment: ', '')}', style: const TextStyle(fontWeight: FontWeight.w700))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: color.withValues(alpha: .15), borderRadius: BorderRadius.circular(99)),
              child: Text(status, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ]),
          const SizedBox(height: 4),
          Text('Mentor: ${w['mentor'] ?? '-'} · ${w['consent'] == true ? 'shown by name' : 'shown as "A learner"'}', style: const TextStyle(fontSize: 12.5, color: Colors.black54)),
          InkWell(onTap: () => launchUrl(Uri.parse('${w['link']}')), child: Text('${w['link']}', style: const TextStyle(color: Colors.blue, fontSize: 13))),
          if ('${w['note'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('“${w['note']}”', style: const TextStyle(fontSize: 13.5))),
          if ('${w['summary'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('${w['summary']}', style: const TextStyle(fontSize: 13, color: Colors.black87))),
          const SizedBox(height: 8),
          Row(children: [
            if (status != 'published')
              FilledButton(onPressed: busy ? null : () => _act(w, 'publish'), child: Text(busy ? 'Writing…' : 'Publish')),
            if (status == 'published') ...[
              OutlinedButton(onPressed: () => launchUrl(Uri.parse('https://altrobytelab.com/work/${w['slug']}')), child: const Text('View')),
              const SizedBox(width: 8),
              TextButton(onPressed: busy ? null : () => _act(w, 'hide'), child: const Text('Hide')),
            ],
          ]),
        ]),
      ),
    );
  }
}
