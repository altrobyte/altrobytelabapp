// Who can open the course, as a switchboard (25 Oct 2026; 8 Nov 2026, founder: "a toggle per person to control access
// and to watch it"). One rule: FULL ACCESS opens every module and note, the GitHub projects and Altron the trainer.
// Every learner is one row with a switch: on gives access, off takes back what the team gave. A payment (plan, module,
// paid seat) or the CRM stage keeps it on, so that switch is locked and says why. Each row also shows how much the
// person has talked with Altron, so the team sees who actually uses it.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../services/api_service.dart';

class AccessScreen extends StatefulWidget {
  const AccessScreen({super.key});

  @override
  State<AccessScreen> createState() => _AccessScreenState();
}

const _filters = [('all', 'All'), ('on', 'Has access'), ('off', 'No access'), ('asked', 'Asking'), ('ai', 'Uses Altron')];

class _AccessScreenState extends State<AccessScreen> {
  List<Map<String, dynamic>> _people = [];
  Map<String, dynamic> _totals = {};
  bool _loading = true;
  String _filter = 'all';
  final _search = TextEditingController();
  final _phone = TextEditingController();
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    _phone.dispose();
    super.dispose();
  }

  String _err(Object e) => e.toString().replaceFirst('Exception: ', '');

  void _toast(String t, {SnackBarAction? action}) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t), action: action));

  Future<void> _load() async {
    try {
      final r = await ApiService.accessPeople();
      _people = [for (final x in (r['people'] as List? ?? const [])) Map<String, dynamic>.from(x as Map)];
      _totals = Map<String, dynamic>.from((r['totals'] as Map?) ?? const {});
    } catch (e) {
      if (mounted) _toast('Could not load: ${_err(e)}');
    }
    if (mounted) setState(() => _loading = false);
  }

  /// The switch: on gives access, off takes back what the team gave. Undo is one tap.
  Future<void> _set(Map<String, dynamic> p, bool on, {bool undo = true}) async {
    final phone = '${p['phone']}';
    if (!on && p['paid'] == true && undo) {
      final why = [for (final w in (p['why'] as List? ?? const [])) '$w'].where((w) => !w.startsWith('Given')).join(', ');
      final ok = await showDialog<bool>(
        context: context,
        builder: (d) => AlertDialog(
          title: Text('Turn off ${_nameOf(p)}?'),
          content: Text('They have access because: $why.\n\nTurning off closes the course and Altron for them until you turn it on again. '
              'Their payment record stays as it is.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
            FilledButton(style: FilledButton.styleFrom(backgroundColor: AppColors.error), onPressed: () => Navigator.pop(d, true), child: const Text('Turn off')),
          ],
        ),
      );
      if (ok != true) return;
    }
    setState(() => _busy.add(phone));
    try {
      if (on) {
        await ApiService.accessGrant(phone);           // also lifts a turn-off
      } else if (p['paid'] == true) {
        await ApiService.accessBlock(phone);           // paid or enrolled: turned off until turned on
      } else {
        await ApiService.accessRemove(phone);
      }
      await _load();
      if (undo && mounted) {
        _toast('${on ? 'Access given to' : 'Access removed for'} ${_nameOf(p)}',
            action: SnackBarAction(label: 'Undo', onPressed: () => _set(p, !on, undo: false)));
      }
    } catch (e) {
      _toast('Not changed: ${_err(e)}');
    }
    if (mounted) setState(() => _busy.remove(phone));
  }

  Future<void> _giveByNumber() async {
    final digits = _phone.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10) {
      _toast('Type a 10-digit WhatsApp number.');
      return;
    }
    final phone = digits.substring(digits.length - 10);
    await _set({'phone': phone, 'name': ''}, true);
    _phone.clear();
  }

  static String _nameOf(Map<String, dynamic> p) {
    final n = '${p['name'] ?? ''}'.trim();
    return n.isEmpty ? '+91 ${p['phone']}' : n;
  }

  static String _date(String? iso) {
    final d = DateTime.tryParse(iso ?? '')?.toLocal();
    if (d == null) return '';
    final days = DateTime.now().difference(d).inDays;
    if (days == 0) return 'today';
    if (days == 1) return 'yesterday';
    if (days < 7) return '$days days ago';
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${m[d.month - 1]}';
  }

  List<Map<String, dynamic>> get _shown {
    final q = _search.text.trim().toLowerCase();
    return _people.where((p) {
      if (q.isNotEmpty && !'${p['name']} ${p['phone']}'.toLowerCase().contains(q)) return false;
      return switch (_filter) {
        'on' => p['access'] == true,
        'off' => p['access'] != true,
        'asked' => p['requested'] == true,
        'ai' => ((p['ai_minutes'] as num?) ?? 0) > 0,
        _ => true,
      };
    }).toList();
  }

  Widget _stat(String label, Object? n, Color c, IconData icon) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.black.withValues(alpha: 0.06))),
          child: Row(children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: c, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${n ?? 0}', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
              ]),
            ),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final shown = _shown;
    final wide = MediaQuery.of(context).size.width > 720;
    final stats = [
      _stat('People', _totals['people'], AppColors.primary, Icons.people_alt_rounded),
      _stat('Have access', _totals['with_access'], AppColors.success, Icons.lock_open_rounded),
      _stat('Asking for access', _totals['requests'], Colors.orange, Icons.front_hand_rounded),
      _stat('Altron min this month', _totals['ai_minutes_month'], const Color(0xFF7C4DFF), Icons.graphic_eq_rounded),
    ];
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: Text('Access', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 17)),
        actions: [IconButton(tooltip: 'Refresh', onPressed: _load, icon: const Icon(Icons.refresh_rounded))],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 40), children: [
                    if (wide)
                      Row(children: [for (var i = 0; i < stats.length; i++) ...[if (i > 0) const SizedBox(width: 10), stats[i]]])
                    else ...[
                      Row(children: [stats[0], const SizedBox(width: 10), stats[1]]),
                      const SizedBox(height: 10),
                      Row(children: [stats[2], const SizedBox(width: 10), stats[3]]),
                    ],
                    const SizedBox(height: 14),
                    // Someone not in the list yet (no sign-up): give by number.
                    Container(
                      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.black.withValues(alpha: 0.06))),
                      child: Row(children: [
                        const Icon(Icons.person_add_alt_1_rounded, color: AppColors.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _phone,
                            keyboardType: TextInputType.phone,
                            onSubmitted: (_) => _giveByNumber(),
                            decoration: const InputDecoration(hintText: 'Give access to a WhatsApp number', border: InputBorder.none, isDense: true),
                          ),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: AppColors.success),
                          onPressed: _giveByNumber,
                          child: const Text('Give access'),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Search name or number',
                        prefixIcon: const Icon(Icons.search_rounded),
                        isDense: true,
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08))),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final f in _filters)
                        ChoiceChip(
                          label: Text(f.$2),
                          selected: _filter == f.$1,
                          onSelected: (_) => setState(() => _filter = f.$1),
                        ),
                    ]),
                    const SizedBox(height: 10),
                    Text('${shown.length} ${shown.length == 1 ? 'person' : 'people'}',
                        style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Container(
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.black.withValues(alpha: 0.06))),
                      child: shown.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(28),
                              child: Text('Nobody here.', textAlign: TextAlign.center, style: GoogleFonts.inter(color: AppColors.textSecondary)),
                            )
                          : Column(children: [
                              for (var i = 0; i < shown.length; i++) ...[
                                if (i > 0) Divider(height: 1, color: Colors.black.withValues(alpha: 0.06)),
                                _row(shown[i]),
                              ],
                            ]),
                    ),
                    const SizedBox(height: 12),
                    Text('Full access = every module and note, the GitHub projects and Altron the trainer. A paid plan, a bought module, '
                        'a paid seat or the CRM stage Token paid / Enrolled turns it on by itself; turning such a person off asks first.',
                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary, height: 1.45)),
                  ]),
                ),
              ),
            ),
    );
  }

  Widget _row(Map<String, dynamic> p) {
    final on = p['access'] == true;
    final blocked = p['blocked'] == true;
    final busy = _busy.contains('${p['phone']}');
    final why = [for (final w in (p['why'] as List? ?? const [])) '$w'];
    final mins = (p['ai_minutes'] as num?)?.toInt() ?? 0;
    final month = (p['ai_minutes_month'] as num?)?.toInt() ?? 0;
    final name = _nameOf(p);
    final tags = <Widget>[
      if (blocked) _tag('Turned off by the team', AppColors.error),
      if (p['requested'] == true) _tag('Asking for access', Colors.orange),
      for (final w in why) _tag(w, w.startsWith('Given') ? AppColors.primary : AppColors.success),
      if (p['signed_up'] != true) _tag('Not signed up yet', AppColors.textSecondary),
    ];
    final use = mins > 0
        ? 'Altron $mins min${month > 0 ? ' ($month this month)' : ''} · last ${_date('${p['ai_last']}')}'
        : 'Has not used Altron';
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      child: Row(children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: (on ? AppColors.success : AppColors.textSecondary).withValues(alpha: 0.12),
          child: Text(name.characters.first.toUpperCase(),
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: on ? AppColors.success : AppColors.textSecondary)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text.rich(TextSpan(children: [
              TextSpan(text: name, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14.5, color: AppColors.textPrimary)),
              if ('${p['name'] ?? ''}'.trim().isNotEmpty)
                TextSpan(text: '  +91 ${p['phone']}', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
            ])),
            const SizedBox(height: 3),
            Row(children: [
              Icon(Icons.graphic_eq_rounded, size: 14, color: mins > 0 ? const Color(0xFF7C4DFF) : AppColors.textSecondary),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                    [use, if (p['joined'] != null) 'joined ${_date('${p['joined']}')}'].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textSecondary)),
              ),
            ]),
            if (tags.isNotEmpty) ...[const SizedBox(height: 6), Wrap(spacing: 6, runSpacing: 4, children: tags)],
          ]),
        ),
        const SizedBox(width: 8),
        busy
            ? const SizedBox(width: 48, height: 24, child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))))
            : Tooltip(
                message: on ? 'On: tap to turn off' : 'Off: tap to give access',
                child: Switch(
                  value: on,
                  activeThumbColor: Colors.white,
                  activeTrackColor: AppColors.success,
                  inactiveThumbColor: Colors.white,
                  inactiveTrackColor: const Color(0xFFCBD2DC),
                  trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
                  onChanged: (v) => _set(p, v),
                ),
              ),
      ]),
    );
  }

  Widget _tag(String t, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
        child: Text(t, style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: c)),
      );
}
