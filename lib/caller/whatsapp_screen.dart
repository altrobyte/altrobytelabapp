// WhatsApp, the way WhatsApp itself looks (8 Nov 2026, founder: "what did Jarvis send to whom, who replied what"; then
// "the list must look like WhatsApp"). The chats, one per person, newest first: a round initial, the name, the last
// message with who sent it (Jarvis, the WhatsApp AI, the team), its time, and a green count of their messages waiting
// for us. Today's numbers in one thin line on top. A chat opens like a WhatsApp chat: our messages on the right with
// who sent each, theirs on the left, a day marker between days, and the box to write while WhatsApp allows it.
// For the owner and team leads (the server allows admins only; anyone else is told why).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'caller_api.dart';
import 'caller_controller.dart';

const _bar = Color(0xFF1A3C5E);           // the app's navy, as WhatsApp's header green would be
const _green = Color(0xFF25D366);
const _wallpaper = Color(0xFFEFEAE2);
const _mineBubble = Color(0xFFD9FDD3);
const _ink = Color(0xFF111B21);
const _grey = Color(0xFF667781);

/// Who sent it, in a colour of its own: Jarvis, a team member, a bulk send, an automation, the WhatsApp AI.
Color byColor(String by) {
  final b = by.toLowerCase();
  if (b.contains('jarvis')) return const Color(0xFF7C4DFF);
  if (b.startsWith('team') || b.startsWith('caller')) return const Color(0xFF1F6FEB);
  if (b.contains('whatsapp ai')) return const Color(0xFF128C7E);
  if (b.startsWith('bulk')) return const Color(0xFFE67E22);
  return _grey;
}

String _shortBy(String by) => by.replaceFirst(RegExp(r'^(Team|Caller): '), '');

/// WhatsApp's own way of showing a time: today the time, yesterday "Yesterday", this week the day, else the date.
String chatTime(DateTime? d, {bool full = false}) {
  if (d == null) return '';
  d = d.toLocal();
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final t = '$h:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'am' : 'pm'}';
  if (full) return t;
  final now = DateTime.now();
  final days = DateTime(now.year, now.month, now.day).difference(DateTime(d.year, d.month, d.day)).inDays;
  if (days == 0) return t;
  if (days == 1) return 'Yesterday';
  if (days < 7) return const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d.weekday - 1];
  return '${d.day}/${d.month}/${d.year % 100}';
}

class WhatsAppScreen extends StatefulWidget {
  const WhatsAppScreen({super.key});

  @override
  State<WhatsAppScreen> createState() => _WhatsAppScreenState();
}

const _filters = [('all', 'All'), ('reply', 'Unread'), ('jarvis', 'Jarvis'), ('failed', 'Not sent')];

class _WhatsAppScreenState extends State<WhatsAppScreen> {
  final _search = TextEditingController();
  String _filter = 'all';
  List<Map<String, dynamic>>? _chats;
  Map<String, dynamic> _today = {};
  String? _problem;
  Timer? _typing, _poll;

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(const Duration(seconds: 30), (_) => _load(quiet: true));
  }

  @override
  void dispose() {
    _search.dispose();
    _typing?.cancel();
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load({bool quiet = false}) async {
    if (!quiet) setState(() => _problem = null);
    final api = context.read<CallerController>().api;
    try {
      final r = await api.conversations(filter: _filter, q: _search.text.trim());
      final t = await api.messages(days: 1).catchError((_) => <String, dynamic>{});
      if (!mounted) return;
      setState(() {
        _chats = ((r['conversations'] as List?) ?? const []).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
        _today = Map<String, dynamic>.from((t['totals'] as Map?) ?? const {});
      });
    } on CallerError catch (e) {
      if (mounted && !quiet) setState(() => _problem = e.status == 403 ? 'WhatsApp chats are for the owner and admins.' : e.message);
    }
  }

  Future<void> _open(Map<String, dynamic> c) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatScreen(phone: '${c['phone']}', name: '${c['name'] ?? ''}')));
    _load(quiet: true);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(children: [
        // Today, in one thin line.
        Container(
          width: double.infinity,
          color: const Color(0xFFF0F2F5),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text.rich(
            TextSpan(style: const TextStyle(fontSize: 13, color: _grey), children: [
              const TextSpan(text: 'Today  '),
              TextSpan(text: '${_today['sent'] ?? 0} sent', style: const TextStyle(color: _ink, fontWeight: FontWeight.w600)),
              const TextSpan(text: '  ·  '),
              TextSpan(text: '${_today['received'] ?? 0} replies', style: const TextStyle(color: Color(0xFF128C7E), fontWeight: FontWeight.w600)),
              TextSpan(text: ' from ${_today['replied_people'] ?? 0}'),
              if ((_today['failed'] ?? 0) != 0) ...[
                const TextSpan(text: '  ·  '),
                TextSpan(text: '${_today['failed']} not sent', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
              ],
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: TextField(
            controller: _search,
            decoration: InputDecoration(
              hintText: 'Search',
              prefixIcon: const Icon(Icons.search, color: _grey),
              isDense: true,
              filled: true,
              fillColor: const Color(0xFFF0F2F5),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
            ),
            onChanged: (_) {
              _typing?.cancel();
              _typing = Timer(const Duration(milliseconds: 400), _load);
            },
          ),
        ),
        SizedBox(
          height: 46,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.fromLTRB(12, 6, 12, 6), children: [
            for (final f in _filters)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () {
                    setState(() => _filter = f.$1);
                    _load();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: _filter == f.$1 ? const Color(0xFFD9FDD3) : const Color(0xFFF0F2F5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(f.$2,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: _filter == f.$1 ? const Color(0xFF008069) : _grey)),
                  ),
                ),
              ),
          ]),
        ),
        Expanded(
          child: _problem != null
              ? Center(
                  child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(_problem!, textAlign: TextAlign.center),
                    TextButton(onPressed: _load, child: const Text('Try again')),
                  ]),
                ))
              : _chats == null
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: _chats!.isEmpty
                          ? ListView(children: const [
                              Padding(padding: EdgeInsets.all(32), child: Text('No chats here.', textAlign: TextAlign.center, style: TextStyle(color: _grey))),
                            ])
                          : ListView.builder(
                              itemCount: _chats!.length,
                              itemBuilder: (context, i) => _ChatRow(_chats![i], onTap: () => _open(_chats![i])),
                            ),
                    ),
        ),
      ]),
    );
  }
}

class _ChatRow extends StatelessWidget {
  final Map<String, dynamic> c;
  final VoidCallback onTap;
  const _ChatRow(this.c, {required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = '${c['name'] ?? ''}'.trim();
    final title = name.isEmpty ? '+91 ${c['phone']}' : name;
    final waiting = (c['waiting'] as num?)?.toInt() ?? 0;
    final theirs = c['last_direction'] == 'in';
    final failed = c['failed'] == true;
    final by = '${c['last_by'] ?? ''}';
    final unread = theirs && waiting > 0;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: const Color(0xFFDFE5E7),
            child: Text(title.characters.first.toUpperCase(), style: const TextStyle(fontSize: 20, color: _grey, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w600, color: _ink)),
                ),
                Text(chatTime(DateTime.tryParse('${c['at'] ?? ''}')),
                    style: TextStyle(fontSize: 12, color: unread ? _green : _grey, fontWeight: unread ? FontWeight.w600 : FontWeight.normal)),
              ]),
              const SizedBox(height: 3),
              Row(children: [
                if (!theirs) ...[
                  Icon(failed ? Icons.error_outline : Icons.done_all, size: 16, color: failed ? Colors.red : const Color(0xFF53BDEB)),
                  const SizedBox(width: 3),
                ],
                if (!theirs && by.isNotEmpty) ...[
                  Text('${_shortBy(by)}: ', style: TextStyle(fontSize: 14, color: byColor(by), fontWeight: FontWeight.w600)),
                ],
                Expanded(
                  child: Text('${c['last'] ?? ''}'.replaceAll('\n', ' '), maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, color: unread ? _ink : _grey, fontWeight: unread ? FontWeight.w500 : FontWeight.normal)),
                ),
                if (unread)
                  Container(
                    margin: const EdgeInsets.only(left: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: const BoxDecoration(color: _green, borderRadius: BorderRadius.all(Radius.circular(12))),
                    child: Text('$waiting', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// One person's chat, laid out like WhatsApp.
class ChatScreen extends StatefulWidget {
  final String phone, name;
  const ChatScreen({super.key, required this.phone, this.name = ''});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _box = TextEditingController();
  final _scroll = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true, _open = false, _sending = false, _switching = false;
  String _mode = '';
  Timer? _poll;

  CallerApi get _api => context.read<CallerController>().api;

  @override
  void initState() {
    super.initState();
    _load(first: true);
    _api.chatMode(widget.phone).then((m) {
      if (mounted) setState(() => _mode = m);
    }).catchError((_) {});
    _poll = Timer.periodic(const Duration(seconds: 15), (_) => _load());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _box.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool first = false}) async {
    try {
      final r = await _api.lead(widget.phone);
      final next = [for (final m in (r['messages'] as List? ?? const [])) Map<String, dynamic>.from(m as Map)];
      final waiting = _messages.where((m) => m['pending'] == true && !next.any((n) => n['direction'] == 'out' && n['body'] == m['body']));
      next.addAll(waiting);
      final grew = next.length != _messages.length;
      _messages = next;
      _open = r['window_open'] == true;
      if (mounted) setState(() => _loading = false);
      if (first || grew) _toBottom();
    } on CallerError catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        if (first) _toast(e.message, bad: true);
      }
    }
  }

  void _toBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
      });

  void _toast(String text, {bool bad = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), backgroundColor: bad ? Colors.red.shade700 : null));
  }

  Future<void> _send() async {
    final text = _box.text.trim();
    if (text.isEmpty || _sending) return;
    final mine = <String, dynamic>{'direction': 'out', 'body': text, 'created_at': DateTime.now().toUtc().toIso8601String(), 'pending': true, 'sent_by': 'You'};
    setState(() {
      _messages = [..._messages, mine];
      _box.clear();
      _sending = true;
    });
    _toBottom();
    try {
      final r = await _api.sendWhatsApp(widget.phone, text);
      if ('${r['mode'] ?? ''}'.isNotEmpty) _mode = '${r['mode']}';
      mine['pending'] = false;
      _load();
    } on CallerError catch (e) {
      setState(() {
        _messages = _messages.where((m) => !identical(m, mine)).toList();
        _box.text = text;
      });
      _toast(e.message, bad: true);
    }
    if (mounted) setState(() => _sending = false);
  }

  Future<void> _switchMode() async {
    setState(() => _switching = true);
    try {
      _mode = await _api.chatMode(widget.phone, set: _mode == 'human' ? 'bot' : 'human');
      _toast(_mode == 'human' ? 'The WhatsApp AI stops answering this chat. You reply.' : 'The WhatsApp AI answers this chat again.');
    } on CallerError catch (e) {
      _toast(e.message, bad: true);
    }
    if (mounted) setState(() => _switching = false);
  }

  static DateTime? _at(Map<String, dynamic> m) => DateTime.tryParse('${m['created_at'] ?? ''}')?.toLocal();

  static String _day(DateTime d) {
    final now = DateTime.now();
    final diff = DateTime(now.year, now.month, now.day).difference(DateTime(d.year, d.month, d.day)).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.name.isNotEmpty ? widget.name : '+91 ${widget.phone}';
    return Scaffold(
      backgroundColor: _wallpaper,
      appBar: AppBar(
        backgroundColor: _bar,
        foregroundColor: Colors.white,
        titleSpacing: 0,
        title: Row(children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            child: Text(title.characters.first.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              Text(_mode == 'human' ? 'Team is replying' : (_mode == 'bot' ? 'WhatsApp AI is replying' : widget.phone),
                  style: const TextStyle(fontSize: 12, color: Colors.white70)),
            ]),
          ),
        ]),
        actions: [
          if (_mode.isNotEmpty)
            IconButton(
              tooltip: _mode == 'human' ? 'Hand back to the WhatsApp AI' : 'Take over from the WhatsApp AI',
              onPressed: _switching ? null : _switchMode,
              icon: Icon(_mode == 'human' ? Icons.smart_toy_outlined : Icons.person_outline),
            ),
          IconButton(tooltip: 'Call', onPressed: () => launchUrl(Uri.parse('tel:+91${widget.phone}')), icon: const Icon(Icons.call)),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _messages.isEmpty
                  ? const Center(child: Text('No messages yet.', style: TextStyle(color: _grey)))
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                      itemCount: _messages.length,
                      itemBuilder: (_, i) {
                        final m = _messages[i];
                        final at = _at(m);
                        final prev = i > 0 ? _at(_messages[i - 1]) : null;
                        final newDay = at != null && (prev == null || prev.day != at.day || prev.month != at.month || prev.year != at.year);
                        return Column(children: [
                          if (newDay)
                            Container(
                              margin: const EdgeInsets.symmetric(vertical: 10),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.92), borderRadius: BorderRadius.circular(8)),
                              child: Text(_day(at), style: const TextStyle(fontSize: 12, color: _grey, fontWeight: FontWeight.w500)),
                            ),
                          _Bubble(m),
                        ]);
                      },
                    ),
        ),
        _composer(),
      ]),
    );
  }

  Widget _composer() {
    final first = widget.name.trim().split(' ').first;
    final box = _writeBox();
    if (_loading || _open) return box;
    // After 24 hours WhatsApp takes only an approved template: the words go in "Hi <name>, ..." as Jarvis sends them.
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(color: const Color(0xFFFFF3C4), borderRadius: BorderRadius.circular(10)),
        child: Text('No message from them in 24 hours: yours goes as "Hi ${first.isEmpty ? 'there' : first}, <your message>" '
            "(WhatsApp's approved format, the way Jarvis sends).",
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF54656F), height: 1.3)),
      ),
      box,
    ]);
  }

  Widget _writeBox() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(26)),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _box,
                minLines: 1,
                maxLines: 6,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(hintText: 'Message', border: InputBorder.none, contentPadding: EdgeInsets.symmetric(vertical: 13)),
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 50,
            height: 50,
            child: FloatingActionButton(
              heroTag: 'wa-send',
              elevation: 0,
              backgroundColor: const Color(0xFF008069),
              onPressed: _send,
              child: _sending
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send, color: Colors.white),
            ),
          ),
        ]),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final Map<String, dynamic> m;
  const _Bubble(this.m);

  @override
  Widget build(BuildContext context) {
    final mine = m['direction'] == 'out';
    var text = '${m['body'] ?? ''}';
    final notSent = text.startsWith('(not sent) ');
    if (notSent) text = text.substring(11);
    final by = '${m['sent_by'] ?? ''}';
    final pending = m['pending'] == true;
    final time = chatTime(DateTime.tryParse('${m['created_at'] ?? ''}'), full: true);
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 2.5),
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 5),
          decoration: BoxDecoration(
            color: notSent ? const Color(0xFFFDECEA) : (mine ? _mineBubble : Colors.white),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(mine ? 10 : 2),
              topRight: Radius.circular(mine ? 2 : 10),
              bottomLeft: const Radius.circular(10),
              bottomRight: const Radius.circular(10),
            ),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.07), blurRadius: 1, offset: const Offset(0, 1))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            if (mine && by.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(_shortBy(by), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: byColor(by))),
              ),
            Text(text, style: const TextStyle(fontSize: 15, height: 1.35, color: _ink)),
            const SizedBox(height: 2),
            Align(
              alignment: Alignment.centerRight,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(notSent ? 'not delivered · $time' : time, style: TextStyle(fontSize: 11, color: notSent ? Colors.red : _grey)),
                if (mine && !notSent) ...[
                  const SizedBox(width: 3),
                  Icon(pending ? Icons.schedule : Icons.done_all, size: 15, color: pending ? _grey : const Color(0xFF53BDEB)),
                ],
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
