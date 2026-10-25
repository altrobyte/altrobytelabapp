// Who can open the course, in one place (25 Oct 2026). One rule: FULL ACCESS opens every module and note, the GitHub
// projects and Altron the trainer. This screen shows who asked for it, who has it and why, and gives or removes it.
// A payment (plan, module, paid seat) also gives it; that is shown here but not removed from here.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../services/api_service.dart';

class AccessScreen extends StatefulWidget {
  const AccessScreen({super.key});

  @override
  State<AccessScreen> createState() => _AccessScreenState();
}

class _AccessScreenState extends State<AccessScreen> {
  List<Map<String, dynamic>> _requests = [];
  List<Map<String, dynamic>> _people = [];
  bool _loading = true;
  final _phone = TextEditingController();
  final _filter = TextEditingController();
  Map<String, dynamic>? _checked;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _phone.dispose();
    _filter.dispose();
    super.dispose();
  }

  void _toast(String t) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  Future<void> _load() async {
    try {
      final r = await ApiService.accessOverview();
      _requests = [for (final x in (r['requests'] as List? ?? const [])) Map<String, dynamic>.from(x as Map)];
      _people = [for (final x in (r['with_access'] as List? ?? const [])) Map<String, dynamic>.from(x as Map)];
    } catch (e) {
      if (mounted) _toast('Could not load: ${e.toString().replaceFirst('Exception: ', '')}');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _check([String? phone]) async {
    final p = (phone ?? _phone.text).trim();
    if (p.replaceAll(RegExp(r'\D'), '').length < 10) {
      _toast('Type a 10-digit number.');
      return;
    }
    _phone.text = p;
    setState(() => _checking = true);
    try {
      _checked = await ApiService.accessCheck(p);
    } catch (e) {
      _toast(e.toString().replaceFirst('Exception: ', ''));
    }
    if (mounted) setState(() => _checking = false);
  }

  Future<void> _give(String phone, {String note = ''}) async {
    try {
      await ApiService.accessGrant(phone, note: note);
      _toast('Full access given to $phone. They see everything after signing in with this WhatsApp number.');
      await _load();
      if (_checked != null) await _check(phone);
    } catch (e) {
      _toast('Not given: ${e.toString().replaceFirst('Exception: ', '')}');
    }
  }

  Future<void> _remove(String phone) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Remove access?'),
        content: Text('Access given by the team to $phone is taken back. A payment they made still counts.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Remove')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final r = await ApiService.accessRemove(phone);
      _toast(r['still_has_access'] == true
          ? 'Removed what the team gave, but they still have access: ${(r['because'] as List).join(', ')}'
          : 'Access removed.');
      await _load();
      if (_checked != null) await _check(phone);
    } catch (e) {
      _toast(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _giveWithNote(String phone) async {
    final note = TextEditingController();
    final go = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('Give full access to $phone'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Every module and note, the GitHub projects and Altron the trainer open for this WhatsApp number.'),
          const SizedBox(height: 12),
          TextField(controller: note, decoration: const InputDecoration(labelText: 'Why (optional)', hintText: 'e.g. tester, paid by UPI', border: OutlineInputBorder())),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Give access')),
        ],
      ),
    );
    if (go == true) await _give(phone, note: note.text.trim());
  }

  Widget _section(String title, int n) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 22, 4, 8),
        child: Text('$title ($n)', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
      );

  Widget _checkCard() {
    final c = _checked!;
    final on = c['access'] == true;
    final why = [for (final w in (c['why'] as List? ?? const [])) '$w'];
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: on ? AppColors.success.withValues(alpha: 0.08) : const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: on ? AppColors.success.withValues(alpha: 0.4) : const Color(0xFFFFB74D)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(on ? Icons.lock_open_rounded : Icons.lock_outline_rounded, color: on ? AppColors.success : const Color(0xFFE65100)),
          const SizedBox(width: 10),
          Expanded(
            child: Text('${(c['name'] ?? '').toString().isEmpty ? 'No name' : c['name']} · +91 ${c['phone']}',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14.5)),
          ),
          Text(on ? 'FULL ACCESS' : 'NO ACCESS',
              style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: on ? AppColors.success : const Color(0xFFE65100))),
        ]),
        const SizedBox(height: 8),
        if (why.isEmpty) Text('Nothing gives them access yet.', style: GoogleFonts.inter(fontSize: 13)),
        for (final w in why) Text('• $w', style: GoogleFonts.inter(fontSize: 13, height: 1.5)),
        if (c['signed_up'] != true)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('They have not signed up yet: access starts when they sign in with this number.',
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
          ),
        const SizedBox(height: 10),
        Wrap(spacing: 8, children: [
          if (c['given_here'] != true)
            FilledButton.icon(
                onPressed: () => _giveWithNote('${c['phone']}'),
                style: FilledButton.styleFrom(backgroundColor: AppColors.success),
                icon: const Icon(Icons.verified_rounded, size: 18),
                label: const Text('Give full access')),
          if (c['given_here'] == true)
            OutlinedButton(onPressed: () => _remove('${c['phone']}'), child: const Text('Remove what the team gave')),
        ]),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final f = _filter.text.trim().toLowerCase();
    final people = f.isEmpty
        ? _people
        : _people.where((p) => '${p['name']} ${p['phone']}'.toLowerCase().contains(f)).toList();
    return Scaffold(
      appBar: AppBar(
        title: Text('Access', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 17)),
        actions: [IconButton(tooltip: 'Refresh', onPressed: _load, icon: const Icon(Icons.refresh_rounded))],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: ListView(padding: const EdgeInsets.all(18), children: [
                  Text('Full access = every module and note, the GitHub projects and Altron the trainer. '
                      'A paid plan, a bought module or a paid seat gives it too.',
                      style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textSecondary, height: 1.4)),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        onSubmitted: (_) => _check(),
                        decoration: const InputDecoration(
                            labelText: 'Check a WhatsApp number', hintText: '9876543210', border: OutlineInputBorder(), isDense: true),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(onPressed: _checking ? null : _check, child: Text(_checking ? 'Checking…' : 'Check')),
                  ]),
                  if (_checked != null) _checkCard(),
                  _section('Asked for access', _requests.length),
                  if (_requests.isEmpty)
                    Text('No one is waiting. Learners ask from the desktop app ("Request access" on a locked module).',
                        style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textSecondary)),
                  for (final r in _requests)
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFFFB74D))),
                      child: ListTile(
                        leading: const Icon(Icons.front_hand_rounded, color: Color(0xFFE65100)),
                        title: Text('${(r['name'] ?? '').toString().isEmpty ? 'No name' : r['name']} · +91 ${r['phone']}'),
                        subtitle: Text([if ('${r['what'] ?? ''}'.isNotEmpty) 'Wanted: ${r['what']}', _ago('${r['created_at']}')].join(' · ')),
                        trailing: Wrap(spacing: 6, children: [
                          TextButton(
                              onPressed: () async {
                                await ApiService.accessIgnore(r['id'] as int);
                                _load();
                              },
                              child: const Text('Ignore')),
                          FilledButton(
                              onPressed: () => _give('${r['phone']}', note: 'asked in the app'),
                              style: FilledButton.styleFrom(backgroundColor: AppColors.success),
                              child: const Text('Give')),
                        ]),
                      ),
                    ),
                  _section('Have full access', _people.length),
                  TextField(
                    controller: _filter,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Find by name or number', isDense: true, border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 8),
                  for (final p in people)
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 6),
                      leading: const Icon(Icons.lock_open_rounded, color: AppColors.success),
                      title: Text('${(p['name'] ?? '').toString().isEmpty ? 'No name' : p['name']} · +91 ${p['phone']}'),
                      subtitle: Wrap(spacing: 6, runSpacing: 4, children: [
                        for (final w in (p['why'] as List? ?? const []))
                          Chip(label: Text('$w', style: const TextStyle(fontSize: 11)), visualDensity: VisualDensity.compact),
                      ]),
                      trailing: TextButton(onPressed: () => _check('${p['phone']}'), child: const Text('Details')),
                    ),
                ]),
              ),
            ),
    );
  }

  String _ago(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return '';
    final m = DateTime.now().difference(d.toLocal()).inMinutes;
    if (m < 60) return '$m min ago';
    if (m < 60 * 24) return '${m ~/ 60} h ago';
    return '${m ~/ (60 * 24)} days ago';
  }
}
