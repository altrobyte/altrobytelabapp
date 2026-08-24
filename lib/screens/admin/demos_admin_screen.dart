import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/api_service.dart';

/// Scheduling free demos, and seeing who took a seat.
class DemosAdminScreen extends StatefulWidget {
  const DemosAdminScreen({super.key});

  @override
  State<DemosAdminScreen> createState() => _DemosAdminScreenState();
}

class _DemosAdminScreenState extends State<DemosAdminScreen> {
  List<dynamic> _demos = [];
  bool _loading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final r = await ApiService.adminGetDemos();
      if (mounted) setState(() { _demos = r; _loading = false; });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e is ApiException ? e.message : '$e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _edit({Map<String, dynamic>? demo}) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _DemoDialog(demo: demo),
    );
    if (saved == true) _load();
  }

  Future<void> _delete(Map<String, dynamic> d) async {
    final count = (d['registration_count'] as int?) ?? 0;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Delete this demo?', style: GoogleFonts.poppins(fontSize: 16)),
        content: Text(
          count > 0
              // Naming the number, because deleting a demo with people in it
              // is a different decision from deleting an empty one.
              ? '$count ${count == 1 ? 'person has' : 'people have'} a seat in '
                  '"${d['title']}". Deleting it removes their registrations too, '
                  'and they are not told.'
              : '"${d['title']}" will be removed.',
          style: GoogleFonts.inter(fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Keep')),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFC62828)),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiService.adminDeleteDemo(d['id'] as int);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not delete: $e')));
      }
    }
  }

  Future<void> _sendLink(Map<String, dynamic> d) async {
    final booked = (d['registration_count'] as int?) ?? 0;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Send the joining link?',
            style: GoogleFonts.poppins(fontSize: 16)),
        content: Text(
          'Everyone booked into "${d['title']}" gets the meeting link on '
          'WhatsApp. Anyone already sent it is skipped, so this is safe to '
          'press again.',
          style: GoogleFonts.inter(fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Not now')),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text('Send to $booked'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final r = await ApiService.adminSendDemoLink(d['id'] as int);
      if (!mounted) return;
      final skipped = (r['already_sent'] as int?) ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Sent ${r['sent']}'
            '${(r['failed'] as int? ?? 0) > 0 ? ', ${r['failed']} failed' : ''}'
            '${skipped > 0 ? ', $skipped already had it' : ''}'),
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e is ApiException ? e.message : 'Could not send: $e')));
      }
    }
  }

  Future<void> _attendees(Map<String, dynamic> d) async {
    try {
      final rows = await ApiService.adminGetDemoAttendees(d['id'] as int);
      if (!mounted) return;
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          builder: (_, controller) => Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
              child: Row(children: [
                Expanded(
                  child: Text('${rows.length} booked  ·  ${d['title']}',
                      style: GoogleFonts.poppins(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                ),
                if (rows.isNotEmpty)
                  TextButton.icon(
                    // For messaging the batch by hand. WhatsApp's own
                    // broadcast wants numbers saved as contacts, so a
                    // newline-separated list is what actually gets pasted.
                    onPressed: () {
                      final numbers = rows
                          .map((r) => '+${(r as Map)['phone']}')
                          .join('\n');
                      Clipboard.setData(ClipboardData(text: numbers));
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('${rows.length} numbers copied')));
                    },
                    icon: const Icon(Icons.copy_rounded, size: 15),
                    label: Text('Copy all',
                        style: GoogleFonts.inter(fontSize: 12)),
                  ),
              ]),
            ),
            Expanded(
              child: rows.isEmpty
                  ? Center(
                      child: Text('Nobody yet',
                          style: GoogleFonts.inter(
                              fontSize: 13, color: const Color(0xFF9AA5B5))))
                  : ListView.separated(
                      controller: controller,
                      itemCount: rows.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final a = rows[i] as Map<String, dynamic>;
                        return ListTile(
                          dense: true,
                          title: Text('${a['name']}',
                              style: GoogleFonts.inter(
                                  fontSize: 13, fontWeight: FontWeight.w500)),
                          subtitle: Text(
                              [
                                if ('${a['email'] ?? ''}'.isNotEmpty)
                                  '${a['email']}',
                                '+${a['phone']}',
                              ].join('\n'),
                              style: GoogleFonts.inter(fontSize: 11.5)),
                          isThreeLine: '${a['email'] ?? ''}'.isNotEmpty,
                          trailing: IconButton(
                            icon: const Icon(Icons.chat_rounded,
                                size: 19, color: Color(0xFF25D366)),
                            onPressed: () => launchUrl(
                                Uri.parse('https://wa.me/${a['phone']}'),
                                mode: LaunchMode.externalApplication),
                          ),
                        );
                      },
                    ),
            ),
          ]),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not load: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: Text('Free Demos',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 17)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0B2450),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded, size: 21),
            onPressed: _load,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        backgroundColor: const Color(0xFF12326B),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('New demo',
            style: GoogleFonts.poppins(
                fontSize: 13.5, fontWeight: FontWeight.w600, color: Colors.white)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(
                  child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(_error, textAlign: TextAlign.center)))
              : _demos.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.event_seat_rounded,
                              size: 42, color: Color(0xFF9AA5B5)),
                          const SizedBox(height: 12),
                          Text('No demos scheduled',
                              style: GoogleFonts.poppins(
                                  fontSize: 15, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          Text(
                            'Add one and it appears at altrobytelab.com/demo '
                            'for anyone with the link.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                                fontSize: 12.5,
                                height: 1.5,
                                color: const Color(0xFF5A6B82)),
                          ),
                        ]),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 90),
                        itemCount: _demos.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) =>
                            _row(_demos[i] as Map<String, dynamic>),
                      ),
                    ),
    );
  }

  Widget _row(Map<String, dynamic> d) {
    final booked = (d['registration_count'] as int?) ?? 0;
    final cap = (d['capacity'] as int?) ?? 0;
    final published = d['is_published'] == true;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6EBF3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text('${d['when'] ?? 'No date set'}',
                style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF12326B))),
          ),
          if (!published)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF9AA5B5).withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('Hidden',
                  style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF5A6B82))),
            ),
        ]),
        const SizedBox(height: 6),
        Text('${d['title']}',
            style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF0B2450))),
        const SizedBox(height: 10),
        Row(children: [
          Icon(Icons.people_rounded,
              size: 15,
              color: cap > 0 && booked >= cap
                  ? const Color(0xFFC62828)
                  : const Color(0xFF5A6B82)),
          const SizedBox(width: 5),
          Text(cap > 0 ? '$booked / $cap booked' : '$booked booked',
              style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: cap > 0 && booked >= cap
                      ? const Color(0xFFC62828)
                      : const Color(0xFF5A6B82))),
        ]),
        if (d['needs_link'] == true) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFE65100).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                  color: const Color(0xFFE65100).withValues(alpha: 0.3)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.warning_amber_rounded,
                  size: 16, color: Color(0xFFE65100)),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'No meeting link yet. Confirmations and reminders go out '
                  'without one until you add it.',
                  style: GoogleFonts.inter(
                      fontSize: 11.5,
                      height: 1.4,
                      color: const Color(0xFF0B2450)),
                ),
              ),
            ]),
          ),
        ],
        const Divider(height: 20),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (d['needs_link'] != true && booked > 0)
            _act(Icons.send_rounded, 'Send link', () => _sendLink(d)),
          _act(Icons.group_rounded, 'Who booked', () => _attendees(d)),
          _act(Icons.edit_rounded, 'Edit', () => _edit(demo: d)),
          _act(Icons.delete_outline_rounded, 'Delete', () => _delete(d),
              danger: true),
        ]),
      ]),
    );
  }

  Widget _act(IconData icon, String label, VoidCallback onTap,
          {bool danger = false}) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: danger
                ? const Color(0xFFC62828).withValues(alpha: 0.08)
                : const Color(0xFFF1F4F9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon,
                size: 14,
                color: danger ? const Color(0xFFC62828) : const Color(0xFF12326B)),
            const SizedBox(width: 5),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: danger
                        ? const Color(0xFFC62828)
                        : const Color(0xFF12326B))),
          ]),
        ),
      );
}

class _DemoDialog extends StatefulWidget {
  final Map<String, dynamic>? demo;
  const _DemoDialog({this.demo});

  @override
  State<_DemoDialog> createState() => _DemoDialogState();
}

class _DemoDialogState extends State<_DemoDialog> {
  late final TextEditingController _title;
  late final TextEditingController _host;
  late final TextEditingController _link;
  late final TextEditingController _capacity;
  late final TextEditingController _duration;
  DateTime? _when;
  bool _published = true;
  bool _saving = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    final d = widget.demo;
    _title = TextEditingController(text: d?['title'] as String? ?? '');
    _host = TextEditingController(text: d?['host_name'] as String? ?? '');
    _link = TextEditingController(text: d?['meeting_link'] as String? ?? '');
    _capacity =
        TextEditingController(text: '${(d?['capacity'] as int?) ?? 30}');
    _duration =
        TextEditingController(text: '${(d?['duration_minutes'] as int?) ?? 60}');
    _published = d == null ? true : d['is_published'] == true;
    final raw = d?['session_date'];
    if (raw != null) _when = DateTime.tryParse('$raw');
  }

  @override
  void dispose() {
    _title.dispose();
    _host.dispose();
    _link.dispose();
    _capacity.dispose();
    _duration.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _when ?? now.add(const Duration(days: 1)),
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
          _when ?? now.add(const Duration(hours: 1))),
    );
    if (time == null) return;
    setState(() => _when =
        DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'Give the demo a title');
      return;
    }
    if (_when == null) {
      setState(() => _error = 'Pick a date and time');
      return;
    }
    setState(() { _saving = true; _error = ''; });
    try {
      await ApiService.adminSaveDemo({
        'title': _title.text.trim(),
        // Sent without a zone: the column is a naive timestamp holding IST,
        // which is what the rest of the sessions admin already writes.
        'session_date': _when!.toIso8601String().split('.').first,
        'duration_minutes': int.tryParse(_duration.text) ?? 60,
        'capacity': int.tryParse(_capacity.text) ?? 30,
        'host_name': _host.text.trim(),
        'meeting_link': _link.text.trim(),
        'platform': 'Google Meet',
        'is_published': _published,
      }, id: widget.demo?['id'] as int?);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() =>
            _error = e is ApiException ? e.message : 'Could not save. $e');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.demo == null ? 'New free demo' : 'Edit demo',
            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _f(_title, 'Title, e.g. Intro to Embedded Systems'),
              const SizedBox(height: 10),
              InkWell(
                onTap: _pick,
                child: InputDecorator(
                  decoration: const InputDecoration(
                      labelText: 'When', border: OutlineInputBorder()),
                  child: Text(
                    _when == null
                        ? 'Pick a date and time'
                        : '${_when!.day}/${_when!.month}/${_when!.year}  '
                            '${_when!.hour.toString().padLeft(2, '0')}:'
                            '${_when!.minute.toString().padLeft(2, '0')}',
                    style: GoogleFonts.inter(fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _f(_capacity, 'Seats', number: true)),
                const SizedBox(width: 10),
                Expanded(child: _f(_duration, 'Minutes', number: true)),
              ]),
              const SizedBox(height: 10),
              _f(_host, 'Host name (optional)'),
              const SizedBox(height: 10),
              _f(_link, 'Meeting link (shown after booking)'),
              const SizedBox(height: 4),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: _published,
                onChanged: (v) => setState(() => _published = v),
                title: Text('Visible on the demo page',
                    style: GoogleFonts.inter(fontSize: 13)),
              ),
              if (_error.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_error,
                      style: GoogleFonts.inter(
                          fontSize: 12, color: const Color(0xFFC62828))),
                ),
            ]),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving...' : 'Save'),
          ),
        ],
      );

  Widget _f(TextEditingController c, String label, {bool number = false}) =>
      TextField(
        controller: c,
        keyboardType: number ? TextInputType.number : TextInputType.text,
        style: GoogleFonts.inter(fontSize: 13.5),
        decoration: InputDecoration(
            labelText: label,
            labelStyle: GoogleFonts.inter(fontSize: 13),
            border: const OutlineInputBorder(),
            isDense: true),
      );
}
