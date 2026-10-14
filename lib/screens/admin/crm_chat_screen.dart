// One lead's WhatsApp conversation, laid out the way the team knows from WhatsApp and the Altron dashboard: their messages
// on the left, ours on the right with the time, a day marker between days, and the box to write at the bottom.
//
// It shows what they wrote, the Lab's own messages and the AI assistant's replies (the engine forwards those). Writing is
// allowed while WhatsApp's 24-hour window is open; after that the box says so and offers a call instead.

import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/api_service.dart';

const _bar = Color(0xFF4F46E5);
const _wallpaper = Color(0xFFEFEAE2);
const _mine = Color(0xFFD9FDD3);

class CrmChatScreen extends StatefulWidget {
  final String phone;
  final String name;

  /// A message to start from (the AI's suggestion), put in the box for the team to read and change.
  final String draft;
  const CrmChatScreen({super.key, required this.phone, this.name = '', this.draft = ''});

  @override
  State<CrmChatScreen> createState() => _CrmChatScreenState();
}

class _CrmChatScreenState extends State<CrmChatScreen> {
  final _box = TextEditingController();
  final _scroll = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _open = false;
  bool _loading = true;
  bool _sending = false;
  bool _suggesting = false;
  bool sent = false; // the screen behind refreshes when something was sent
  String _mode = ''; // who answers this chat on WhatsApp: bot (the AI) or human (the team); '' = not known
  bool _switching = false;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _box.text = widget.draft;
    _load(first: true);
    ApiService.crmMode(widget.phone).then((m) {
      if (mounted) setState(() => _mode = m);
    }).catchError((_) {});
    // New messages (theirs, or the AI's reply) appear without anyone pressing refresh.
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
      final r = await ApiService.crmLead(widget.phone);
      final next = [for (final m in (r['messages'] as List? ?? const [])) Map<String, dynamic>.from(m as Map)];
      // A message still on its way stays on screen until the server's list has it.
      final waiting = _messages.where((m) => m['pending'] == true && !next.any((n) => n['direction'] == 'out' && n['body'] == m['body']));
      next.addAll(waiting);
      final grew = next.length != _messages.length;
      _messages = next;
      _open = r['window_open'] == true;
      if (mounted) setState(() => _loading = false);
      if (first || grew) _toBottom();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  void _toast(String text, {bool bad = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), backgroundColor: bad ? Colors.red.shade700 : null));
  }

  // The message appears at once, with a clock, the way WhatsApp shows it; the tick comes when the server has handed it
  // to WhatsApp. If it could not go, it is taken back out and the words return to the box.
  Future<void> _send() async {
    final text = _box.text.trim();
    if (text.isEmpty) return;
    final mine = <String, dynamic>{'direction': 'out', 'type': 'text', 'body': text,
        'created_at': DateTime.now().toUtc().toIso8601String(), 'pending': true};
    setState(() {
      _messages = [..._messages, mine];
      _box.clear();
    });
    _toBottom();
    try {
      final r = await ApiService.crmSend(widget.phone, text);
      if ('${r['mode'] ?? ''}'.isNotEmpty) _mode = '${r['mode']}';
      sent = true;
      if (mounted) setState(() => mine['pending'] = false);
      _load(); // the saved copy replaces this one; nobody waits for it
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages = [for (final m in _messages) if (!identical(m, mine)) m];
          if (_box.text.trim().isEmpty) _box.text = text;
        });
      }
      _toast(e is ApiException ? e.message : 'Could not send.', bad: true);
    }
  }

  // Hand the chat to the AI, or take it over: while the team has it, the AI does not answer this person.
  Future<void> _switchMode() async {
    final next = _mode == 'human' ? 'bot' : 'human';
    setState(() => _switching = true);
    try {
      _mode = await ApiService.crmMode(widget.phone, set: next);
      _toast(next == 'bot' ? 'The AI assistant answers this chat again.' : 'You have the chat. The AI stays quiet until you hand it back.');
    } catch (e) {
      _toast(e is ApiException ? e.message : 'Could not switch just now.', bad: true);
    }
    if (mounted) setState(() => _switching = false);
  }

  static const _mimes = {
    'jpg': 'image/jpeg', 'jpeg': 'image/jpeg', 'png': 'image/png', 'mp4': 'video/mp4', '3gp': 'video/3gpp',
    'pdf': 'application/pdf', 'txt': 'text/plain', 'doc': 'application/msword',
    'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xls': 'application/vnd.ms-excel', 'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'ppt': 'application/vnd.ms-powerpoint',
    'pptx': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  };

  // A photo, video or document: picked, given a caption, sent.
  Future<void> _attach() async {
    final picked = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: _mimes.keys.toList(), withData: true);
    final f = picked?.files.single;
    if (f == null || f.bytes == null || !mounted) return;
    final mime = _mimes[(f.extension ?? '').toLowerCase()] ?? '';
    final caption = TextEditingController(text: _box.text.trim());
    final kind = mime.startsWith('image') ? 'photo' : mime.startsWith('video') ? 'video' : 'document';
    final go = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('Send this $kind?'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (kind == 'photo')
            ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.memory(f.bytes!, height: 180, fit: BoxFit.cover))
          else
            Row(children: [
              Icon(kind == 'video' ? Icons.movie_rounded : Icons.description_rounded, color: _bar),
              const SizedBox(width: 8),
              Expanded(child: Text(f.name, style: GoogleFonts.inter(fontWeight: FontWeight.w600))),
            ]),
          const SizedBox(height: 6),
          Text('${(f.size / (1024 * 1024)).toStringAsFixed(1)} MB', style: GoogleFonts.inter(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 10),
          TextField(controller: caption, maxLines: 3, minLines: 1, decoration: const InputDecoration(hintText: 'Add a caption (optional)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
          FilledButton.icon(onPressed: () => Navigator.pop(d, true), icon: const Icon(Icons.send_rounded, size: 16), label: const Text('Send')),
        ],
      ),
    );
    if (go != true) return;
    setState(() => _sending = true);
    try {
      final r = await ApiService.crmSendMedia(widget.phone, f.bytes!, f.name, mime, caption.text.trim());
      if ('${r['mode'] ?? ''}'.isNotEmpty) _mode = '${r['mode']}';
      if (caption.text.trim() == _box.text.trim()) _box.clear();
      sent = true;
      await _load();
      _toBottom();
    } catch (e) {
      _toast(e is ApiException ? e.message : 'Could not send the file.', bad: true);
    }
    if (mounted) setState(() => _sending = false);
  }

  // A message written by the AI from this conversation, put in the box to read and change before sending.
  Future<void> _suggest() async {
    setState(() => _suggesting = true);
    try {
      final r = await ApiService.crmAskAi(widget.phone);
      final text = '${r['message'] ?? ''}'.trim();
      if (text.isEmpty) {
        _toast('${r['next_step'] ?? 'The AI suggests not sending anything right now.'}');
      } else {
        _box.text = text;
        _box.selection = TextSelection.collapsed(offset: text.length);
      }
    } catch (e) {
      _toast(e is ApiException ? e.message : 'The AI could not suggest a message just now.', bad: true);
    }
    if (mounted) setState(() => _suggesting = false);
  }

  static DateTime? _at(Map<String, dynamic> m) => DateTime.tryParse('${m['created_at'] ?? ''}')?.toLocal();

  static String _time(DateTime? d) {
    if (d == null) return '';
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    return '$h:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'AM' : 'PM'}';
  }

  static String _day(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(d.year, d.month, d.day);
    final diff = today.difference(that).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.name.isNotEmpty ? widget.name : widget.phone;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, sent);
      },
      child: Scaffold(
        backgroundColor: _wallpaper,
        appBar: AppBar(
          backgroundColor: _bar,
          foregroundColor: Colors.white,
          elevation: 0,
          titleSpacing: 0,
          leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => Navigator.pop(context, sent)),
          title: Row(children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white.withValues(alpha: 0.18),
              child: Text(title.isNotEmpty ? title.characters.first.toUpperCase() : '?',
                  style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(fontSize: 15.5, fontWeight: FontWeight.w600, color: Colors.white)),
                Text(widget.phone, style: GoogleFonts.inter(fontSize: 11.5, color: Colors.white70)),
              ]),
            ),
          ]),
          actions: [
            if (_mode.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: ActionChip(
                  onPressed: _switching ? null : _switchMode,
                  avatar: Icon(_mode == 'human' ? Icons.person_rounded : Icons.smart_toy_rounded, size: 16, color: _bar),
                  label: Text(_mode == 'human' ? 'Team replying · Hand to AI' : 'AI replying · Take over',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: _bar)),
                  backgroundColor: Colors.white,
                  side: BorderSide.none,
                ),
              ),
            IconButton(
              tooltip: 'Call',
              onPressed: () => launchUrl(Uri.parse('tel:+91${widget.phone}')),
              icon: const Icon(Icons.call_rounded),
            ),
          ],
        ),
        body: Column(children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(child: Text('No messages yet.', style: GoogleFonts.inter(color: Colors.black54)))
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                        itemCount: _messages.length,
                        itemBuilder: (_, i) {
                          final m = _messages[i];
                          final at = _at(m);
                          final prev = i > 0 ? _at(_messages[i - 1]) : null;
                          final newDay = at != null && (prev == null || prev.day != at.day || prev.month != at.month || prev.year != at.year);
                          return Column(children: [
                            if (newDay) _DayMarker(_day(at)),
                            _Bubble(
                              text: '${m['body'] ?? ''}',
                              mine: m['direction'] == 'out',
                              time: _time(at),
                              automated: m['type'] == 'template',
                              pending: m['pending'] == true,
                            ),
                          ]);
                        },
                      ),
          ),
          _composer(),
        ]),
      ),
    );
  }

  Widget _composer() {
    if (!_open) {
      return Container(
        width: double.infinity,
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        child: Row(children: [
          const Icon(Icons.lock_clock_rounded, size: 20, color: Colors.black45),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
                'They have not written in the last 24 hours, so WhatsApp only allows an approved template now. '
                'Call them, or send a template from the WhatsApp dashboard.',
                style: GoogleFonts.inter(fontSize: 12.5, color: Colors.black54, height: 1.35)),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: () => launchUrl(Uri.parse('tel:+91${widget.phone}')),
            icon: const Icon(Icons.call_rounded, size: 17),
            label: const Text('Call'),
          ),
        ]),
      );
    }
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(26)),
              padding: const EdgeInsets.only(left: 4, right: 6),
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                IconButton(
                  tooltip: 'Let the AI write it',
                  onPressed: _suggesting ? null : _suggest,
                  icon: _suggesting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.auto_awesome_rounded, color: _bar),
                ),
                IconButton(
                  tooltip: 'Photo, video or document',
                  onPressed: _sending ? null : _attach,
                  icon: const Icon(Icons.attach_file_rounded, color: Colors.black54),
                ),
                Expanded(
                  child: TextField(
                    controller: _box,
                    minLines: 1,
                    maxLines: 6,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      hintText: 'Message',
                      border: InputBorder.none,
                      hintStyle: GoogleFonts.inter(color: Colors.black38),
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    style: GoogleFonts.inter(fontSize: 15),
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 52,
            height: 52,
            child: FloatingActionButton(
              heroTag: 'crm-send',
              elevation: 0,
              backgroundColor: _bar,
              onPressed: _send,
              child: _sending
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded, color: Colors.white),
            ),
          ),
        ]),
      ),
    );
  }
}

class _DayMarker extends StatelessWidget {
  final String label;
  const _DayMarker(this.label);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(8)),
          child: Text(label, style: GoogleFonts.inter(fontSize: 11.5, color: Colors.black54, fontWeight: FontWeight.w500)),
        ),
      );
}

class _Bubble extends StatelessWidget {
  final String text;
  final bool mine;
  final String time;
  final bool automated;
  final bool pending;
  const _Bubble({required this.text, required this.mine, required this.time, this.automated = false, this.pending = false});

  @override
  Widget build(BuildContext context) {
    final notSent = text.startsWith('(not sent) ');
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.fromLTRB(11, 7, 11, 6),
          decoration: BoxDecoration(
            color: notSent ? const Color(0xFFFDECEA) : (mine ? _mine : Colors.white),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(10),
              topRight: const Radius.circular(10),
              bottomLeft: Radius.circular(mine ? 10 : 2),
              bottomRight: Radius.circular(mine ? 2 : 10),
            ),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 1, offset: const Offset(0, 1))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
            if (automated)
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Automated message',
                    style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w600, color: Colors.black45)),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: SelectableText(text, style: GoogleFonts.inter(fontSize: 14.5, height: 1.35, color: const Color(0xFF111B21))),
            ),
            const SizedBox(height: 2),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Text(notSent ? 'not delivered · $time' : time, style: GoogleFonts.inter(fontSize: 10.5, color: Colors.black45)),
              if (mine && !notSent) ...[
                const SizedBox(width: 3),
                Icon(pending ? Icons.schedule_rounded : Icons.done_rounded, size: 13, color: Colors.black45),
              ],
            ]),
          ]),
        ),
      ),
    );
  }
}
