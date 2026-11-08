// WhatsApp: every message the CRM sent and got, newest first, with who sent it (8 Nov 2026, founder: "I want to see what
// Jarvis sent to whom, who replied what, and the other activity, on my phone"). The totals for today or the week on top;
// tap a message to open that lead with everything that happened with them. For the owner and team leads (the server
// allows admins only; anyone else sees why).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_colors.dart';
import 'caller_api.dart';
import 'caller_controller.dart';
import 'lead_screen.dart';

class WhatsAppScreen extends StatefulWidget {
  const WhatsAppScreen({super.key});

  @override
  State<WhatsAppScreen> createState() => _WhatsAppScreenState();
}

const _filters = [('all', 'All'), ('received', 'Replies'), ('jarvis', 'Jarvis'), ('sent', 'Sent'), ('failed', 'Not sent')];

class _WhatsAppScreenState extends State<WhatsAppScreen> {
  final _search = TextEditingController();
  String _filter = 'all';
  int _days = 1;
  List<Map<String, dynamic>>? _messages;
  Map<String, dynamic> _totals = {};
  String? _problem;
  Timer? _typing;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    _typing?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _problem = null);
    try {
      final r = await context.read<CallerController>().api
          .messages(filter: _filter == 'jarvis' ? 'sent' : _filter, days: _days, q: _search.text.trim());
      if (!mounted) return;
      var list = ((r['messages'] as List?) ?? const []).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
      if (_filter == 'jarvis') list = list.where((m) => '${m['by']}'.toLowerCase().contains('jarvis')).toList();
      setState(() {
        _messages = list;
        _totals = Map<String, dynamic>.from((r['totals'] as Map?) ?? const {});
      });
    } on CallerError catch (e) {
      if (mounted) setState(() => _problem = e.status == 403 ? 'WhatsApp messages are for the owner and admins.' : e.message);
    }
  }

  Widget _stat(String label, Object? n, Color color) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
          child: Column(children: [
            Text('${n ?? 0}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
            Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
        child: Row(children: [
          for (final d in const [(1, 'Today'), (7, '7 days'), (30, '30 days')])
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(d.$2),
                selected: _days == d.$1,
                onSelected: (_) {
                  setState(() => _days = d.$1);
                  _load();
                },
              ),
            ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        child: Row(children: [
          _stat('Sent', _totals['sent'], AppColors.primary),
          const SizedBox(width: 6),
          _stat('Replies', _totals['received'], AppColors.success),
          const SizedBox(width: 6),
          _stat('People replied', _totals['replied_people'], AppColors.whatsapp),
          const SizedBox(width: 6),
          _stat('Not sent', _totals['failed'], AppColors.error),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
        child: TextField(
          controller: _search,
          decoration: InputDecoration(
            hintText: 'Search name, number or words',
            prefixIcon: const Icon(Icons.search),
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onChanged: (_) {
            _typing?.cancel();
            _typing = Timer(const Duration(milliseconds: 400), _load);
          },
        ),
      ),
      SizedBox(
        height: 44,
        child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: [
          for (final f in _filters)
            Padding(
              padding: const EdgeInsets.only(right: 6, top: 4),
              child: ChoiceChip(
                label: Text(f.$2),
                selected: _filter == f.$1,
                onSelected: (_) {
                  setState(() => _filter = f.$1);
                  _load();
                },
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
            : _messages == null
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: _messages!.isEmpty
                        ? ListView(children: const [
                            Padding(
                                padding: EdgeInsets.all(32),
                                child: Text('No messages here yet.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary))),
                          ])
                        : ListView.builder(
                            padding: const EdgeInsets.only(bottom: 24),
                            itemCount: _messages!.length,
                            itemBuilder: (context, i) => _Message(_messages![i]),
                          ),
                  ),
      ),
    ]);
  }
}

/// Who sent it, as a coloured tag: Jarvis, a team member, a bulk send, an automation, the WhatsApp AI.
Color _byColor(String by) {
  final b = by.toLowerCase();
  if (b.contains('jarvis')) return const Color(0xFF7C4DFF);
  if (b.startsWith('team') || b.startsWith('caller')) return AppColors.primary;
  if (b.contains('whatsapp ai')) return AppColors.whatsapp;
  if (b.startsWith('bulk')) return const Color(0xFFE67E22);
  return AppColors.textSecondary;
}

class _Message extends StatelessWidget {
  final Map<String, dynamic> m;
  const _Message(this.m);

  @override
  Widget build(BuildContext context) {
    final inbound = m['direction'] == 'in', failed = m['status'] == 'failed';
    final at = DateTime.tryParse('${m['at'] ?? ''}');
    final name = '${m['name'] ?? ''}'.trim();
    final by = '${m['by'] ?? ''}';
    final tag = inbound ? 'Reply' : (failed ? 'Not sent' : (by.isEmpty ? 'Sent' : by));
    final color = inbound ? AppColors.success : (failed ? AppColors.error : _byColor(by));
    return InkWell(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => LeadScreen(phone: '${m['phone']}'))),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black.withValues(alpha: 0.06)))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(inbound ? Icons.call_received : Icons.call_made, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(name.isEmpty ? '${m['phone']}' : '$name · ${m['phone']}',
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                if (at != null) Text(CallerController.when(at), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ]),
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                child: Text(inbound ? 'Reply from them' : tag, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color)),
              ),
              const SizedBox(height: 3),
              Text('${m['body'] ?? ''}', maxLines: 3, overflow: TextOverflow.ellipsis),
            ]),
          ),
        ]),
      ),
    );
  }
}
