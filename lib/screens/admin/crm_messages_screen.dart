import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../constants/api_constants.dart';
import '../../constants/app_colors.dart';
import 'crm_screen.dart' show LeadDetailScreen;

/// Every WhatsApp the CRM sent or received, in one list (30 Oct 2026, founder: Jarvis sent to 30 people and there was no
/// screen to see what went and what came back). Read-only; a row opens that lead, where the chat and the reply are.
class CrmMessagesScreen extends StatefulWidget {
  const CrmMessagesScreen({super.key});
  @override
  State<CrmMessagesScreen> createState() => _CrmMessagesScreenState();
}

class _CrmMessagesScreenState extends State<CrmMessagesScreen> {
  String _filter = 'all';
  int _days = 7;
  final _q = TextEditingController();
  Map<String, dynamic>? _data;
  String? _problem;
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
      final uri = Uri.parse('${ApiConstants.baseUrl}/crm/messages').replace(queryParameters: {
        'filter': _filter, 'days': '$_days', if (_q.text.trim().isNotEmpty) 'q': _q.text.trim(),
      });
      final res = await http.get(uri, headers: {'Authorization': 'Bearer $token'});
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode != 200) throw '${body['detail'] ?? 'Could not load the messages.'}';
      if (mounted) setState(() => _data = body);
    } catch (e) {
      if (mounted) setState(() => _problem = e is String ? e : 'Could not load the messages. Check the internet and try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _when(String? iso) {
    final d = DateTime.tryParse(iso ?? '')?.toLocal();
    if (d == null) return '';
    final now = DateTime.now();
    final hm = '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    if (d.year == now.year && d.month == now.month && d.day == now.day) return 'Today $hm';
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${m[d.month - 1]} $hm';
  }

  Widget _stat(String n, String label, Color c) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E6EC))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(n, style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, color: c)),
            Text(label, style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textSecondary)),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final t = (_data?['totals'] as Map?) ?? const {};
    final msgs = (_data?['messages'] as List?) ?? const [];
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: Text('WhatsApp messages', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 17)),
        actions: [IconButton(tooltip: 'Refresh', onPressed: _load, icon: const Icon(Icons.refresh_rounded))],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: Row(children: [
            _stat('${t['sent'] ?? '-'}', 'sent', AppColors.primary),
            const SizedBox(width: 10),
            _stat('${t['received'] ?? '-'}', 'received', AppColors.success),
            const SizedBox(width: 10),
            _stat('${t['replied_people'] ?? '-'}', 'people replied', AppColors.success),
            const SizedBox(width: 10),
            _stat('${t['failed'] ?? '-'}', 'not sent', AppColors.error),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            for (final f in const [('all', 'All'), ('sent', 'Sent'), ('received', 'Received'), ('failed', 'Not sent')])
              ChoiceChip(label: Text(f.$2), selected: _filter == f.$1, onSelected: (_) { setState(() => _filter = f.$1); _load(); }),
            const SizedBox(width: 8),
            DropdownButton<int>(
              value: _days,
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(value: 1, child: Text('Today')),
                DropdownMenuItem(value: 7, child: Text('Last 7 days')),
                DropdownMenuItem(value: 30, child: Text('Last 30 days')),
              ],
              onChanged: (v) { setState(() => _days = v ?? 7); _load(); },
            ),
            SizedBox(
              width: 260,
              child: TextField(
                controller: _q,
                onSubmitted: (_) => _load(),
                decoration: const InputDecoration(isDense: true, prefixIcon: Icon(Icons.search_rounded), hintText: 'Name, phone or text'),
              ),
            ),
          ]),
        ),
        const Divider(height: 1),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _problem != null
                  ? Center(child: Text(_problem!, style: GoogleFonts.inter(color: AppColors.error)))
                  : msgs.isEmpty
                      ? Center(child: Text('No messages here.', style: GoogleFonts.inter(color: AppColors.textSecondary)))
                      : ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: msgs.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final m = msgs[i] as Map;
                            final status = '${m['status']}';
                            final (label, color, icon) = switch (status) {
                              'received' => ('Received', AppColors.success, Icons.call_received_rounded),
                              'failed' => ('Not sent', AppColors.error, Icons.error_outline_rounded),
                              _ => ('Sent', AppColors.primary, Icons.call_made_rounded),
                            };
                            final name = '${m['name'] ?? ''}'.trim();
                            return Material(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LeadDetailScreen(phone: '${m['phone']}'))),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Icon(icon, color: color, size: 20),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                        Row(children: [
                                          Expanded(
                                            child: Text(name.isEmpty ? '${m['phone']}' : '$name · ${m['phone']}',
                                                style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13.5)),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(99)),
                                            child: Text(label, style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: color)),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(_when(m['at'] as String?), style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                                        ]),
                                        const SizedBox(height: 4),
                                        Text('${m['body'] ?? ''}', maxLines: 3, overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.inter(fontSize: 13.5, color: AppColors.textPrimary)),
                                      ]),
                                    ),
                                  ]),
                                ),
                              ),
                            );
                          },
                        ),
        ),
      ]),
    );
  }
}
