import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../constants/api_constants.dart';
import '../../constants/app_colors.dart';
import 'crm_chat_screen.dart';

/// The team's WhatsApp, laid out like WhatsApp Web (30 Oct 2026, founder: Jarvis sent to 30 people and there was no screen
/// to see what went and what came back; it should look like the Altrobyte bot). The chats on the left, newest first, each
/// with its last message, its time and how many of their messages wait for a reply; the chosen chat on the right, where the
/// team reads and replies. On a narrow screen a chat opens on its own page.
class CrmMessagesScreen extends StatefulWidget {
  const CrmMessagesScreen({super.key});
  @override
  State<CrmMessagesScreen> createState() => _CrmMessagesScreenState();
}

class _CrmMessagesScreenState extends State<CrmMessagesScreen> {
  static const _bar = Color(0xFF4F46E5);
  static const _green = Color(0xFF25D366);
  String _filter = 'all';
  final _q = TextEditingController();
  List<Map<String, dynamic>> _chats = [];
  int _waiting = 0;
  String? _problem, _open, _openName;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _problem = null; });
    try {
      final token = (await SharedPreferences.getInstance()).getString('token') ?? '';
      final uri = Uri.parse('${ApiConstants.baseUrl}/crm/conversations').replace(queryParameters: {
        'filter': _filter, 'days': '60', if (_q.text.trim().isNotEmpty) 'q': _q.text.trim(),
      });
      final res = await http.get(uri, headers: {'Authorization': 'Bearer $token'});
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode != 200) throw '${body['detail'] ?? 'Could not load the chats.'}';
      if (!mounted) return;
      setState(() {
        _chats = [for (final c in (body['conversations'] as List? ?? const [])) Map<String, dynamic>.from(c as Map)];
        _waiting = (body['waiting'] as num?)?.toInt() ?? 0;
      });
    } catch (e) {
      if (mounted) setState(() => _problem = e is String ? e : 'Could not load the chats. Check the internet and try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _when(String? iso) {
    final d = DateTime.tryParse(iso ?? '')?.toLocal();
    if (d == null) return '';
    final now = DateTime.now();
    if (d.year == now.year && d.month == now.month && d.day == now.day) {
      return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    }
    final y = now.subtract(const Duration(days: 1));
    if (d.year == y.year && d.month == y.month && d.day == y.day) return 'Yesterday';
    return '${d.day}/${d.month}/${d.year % 100}';
  }

  void _choose(Map<String, dynamic> c, bool wide) {
    final phone = '${c['phone']}', name = '${c['name'] ?? ''}';
    if (wide) {
      setState(() { _open = phone; _openName = name; });
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (_) => CrmChatScreen(phone: phone, name: name))).then((_) => _load());
    }
  }

  Widget _list(bool wide) {
    return Container(
      color: Colors.white,
      child: Column(children: [
        Container(
          color: _bar,
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
          child: SafeArea(
            bottom: false,
            child: Row(children: [
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_rounded, color: Colors.white)),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('WhatsApp', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 18)),
                  Text(_waiting == 0 ? 'Every chat answered' : '$_waiting waiting for a reply',
                      style: GoogleFonts.inter(color: Colors.white70, fontSize: 12)),
                ]),
              ),
              IconButton(tooltip: 'Refresh', onPressed: _load, icon: const Icon(Icons.refresh_rounded, color: Colors.white)),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
          child: TextField(
            controller: _q,
            onSubmitted: (_) => _load(),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: const Color(0xFFF0F2F5),
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              hintText: 'Search a name, number or message',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
            ),
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 10), children: [
            for (final f in const [('all', 'All'), ('reply', 'Waiting for reply'), ('failed', 'Not sent')])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(f.$2),
                  selected: _filter == f.$1,
                  selectedColor: _bar.withValues(alpha: 0.14),
                  onSelected: (_) { setState(() => _filter = f.$1); _load(); },
                ),
              ),
          ]),
        ),
        const Divider(height: 1),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _problem != null
                  ? Center(child: Padding(padding: const EdgeInsets.all(20), child: Text(_problem!, style: GoogleFonts.inter(color: AppColors.error))))
                  : _chats.isEmpty
                      ? Center(child: Text('No chats here.', style: GoogleFonts.inter(color: AppColors.textSecondary)))
                      : ListView.separated(
                          itemCount: _chats.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, indent: 76),
                          itemBuilder: (_, i) => _row(_chats[i], wide),
                        ),
        ),
      ]),
    );
  }

  Widget _row(Map<String, dynamic> c, bool wide) {
    final name = '${c['name'] ?? ''}'.trim();
    final title = name.isEmpty ? '+91 ${c['phone']}' : name;
    final waiting = (c['waiting'] as num?)?.toInt() ?? 0;
    final theirs = c['last_direction'] == 'in';
    final failed = c['failed'] == true;
    final open = _open == c['phone'];
    return Material(
      color: open ? const Color(0xFFF0F2F5) : Colors.white,
      child: InkWell(
        onTap: () => _choose(c, wide),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: _bar.withValues(alpha: 0.12),
              child: Text(title.characters.first.toUpperCase(), style: GoogleFonts.poppins(color: _bar, fontWeight: FontWeight.w600, fontSize: 18)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15))),
                  Text(_when(c['at'] as String?),
                      style: GoogleFonts.inter(fontSize: 12, color: waiting > 0 ? _green : AppColors.textSecondary, fontWeight: waiting > 0 ? FontWeight.w700 : FontWeight.w400)),
                ]),
                const SizedBox(height: 3),
                Row(children: [
                  if (!theirs)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Icon(failed ? Icons.error_outline_rounded : Icons.done_all_rounded, size: 16, color: failed ? AppColors.error : const Color(0xFF53BDEB)),
                    ),
                  Expanded(
                    child: Text(failed ? 'Not sent: ${c['last']}' : '${c['last'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(fontSize: 13.5, color: failed ? AppColors.error : AppColors.textSecondary)),
                  ),
                  if (waiting > 0)
                    Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(color: _green, borderRadius: BorderRadius.circular(99)),
                      child: Text('$waiting', style: GoogleFonts.inter(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700)),
                    ),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, box) {
      final wide = box.maxWidth >= 900;
      if (!wide) return Scaffold(body: _list(false));
      return Scaffold(
        body: Row(children: [
          SizedBox(width: 400, child: _list(true)),
          const VerticalDivider(width: 1),
          Expanded(
            child: _open == null
                ? Container(
                    color: const Color(0xFFF0F2F5),
                    child: Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.forum_rounded, size: 64, color: Colors.black26),
                        const SizedBox(height: 12),
                        Text('Choose a chat to read and reply', style: GoogleFonts.poppins(fontSize: 18, color: Colors.black54)),
                        const SizedBox(height: 4),
                        Text('Messages sent by the team, Jarvis and automations, and every reply.',
                            style: GoogleFonts.inter(fontSize: 13, color: Colors.black45)),
                      ]),
                    ),
                  )
                : CrmChatScreen(key: ValueKey(_open), phone: _open!, name: _openName ?? '', embedded: true),
          ),
        ]),
      );
    });
  }
}
