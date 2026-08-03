import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants/api_constants.dart';
import '../../constants/app_colors.dart';
import '../../services/api_service.dart';
import '../../widgets/image_upload_field.dart';

/// Super-admin CRUD for Events + attendee list/CSV export.
class EventsAdminScreen extends StatefulWidget {
  const EventsAdminScreen({super.key});

  @override
  State<EventsAdminScreen> createState() => _EventsAdminScreenState();
}

class _EventsAdminScreenState extends State<EventsAdminScreen> {
  List<dynamic> _events = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _events = await ApiService.getEventsAdmin();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _openForm({Map<String, dynamic>? existing}) async {
    final formKey = GlobalKey<FormState>();
    final titleCtrl = TextEditingController(text: existing?['title'] ?? '');
    final bannerCtrl = TextEditingController(text: existing?['banner_url'] ?? '');
    final locationCtrl = TextEditingController(text: existing?['location'] ?? '');
    final meetingCtrl = TextEditingController(text: existing?['meeting_link'] ?? '');
    final descCtrl = TextEditingController(text: existing?['description_html'] ?? '');
    DateTime? date;
    try {
      date = existing?['event_date'] != null ? DateTime.parse(existing!['event_date']) : null;
    } catch (_) {}
    String? dateError;
    String? saveError;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(existing == null ? 'New Event' : 'Edit Event',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16)),
                const SizedBox(height: 4),
                Text('Fields marked * are required',
                    style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.textSecondary)),
                const SizedBox(height: 14),
                TextFormField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Title *'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Title is required' : null,
                ),
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(date == null ? 'Pick date & time *' : DateFormat('d MMM yyyy, h:mm a').format(date!)),
                  subtitle: dateError != null
                      ? Text(dateError!, style: GoogleFonts.inter(fontSize: 12, color: AppColors.error))
                      : null,
                  trailing: const Icon(Icons.calendar_today_rounded, size: 18),
                  onTap: () async {
                    final d = await showDatePicker(
                        context: ctx, initialDate: date ?? DateTime.now(),
                        firstDate: DateTime.now().subtract(const Duration(days: 1)),
                        lastDate: DateTime.now().add(const Duration(days: 730)));
                    if (d == null) return;
                    final t = await showTimePicker(context: ctx, initialTime: TimeOfDay.fromDateTime(date ?? DateTime.now()));
                    if (t == null) return;
                    setSheetState(() {
                      date = DateTime(d.year, d.month, d.day, t.hour, t.minute);
                      dateError = null;
                    });
                  },
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: locationCtrl,
                  decoration: const InputDecoration(labelText: 'Location * (or "Online")'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Location is required' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(controller: meetingCtrl, decoration: const InputDecoration(labelText: 'Meeting link (Zoom/Meet/Jitsi)')),
                const SizedBox(height: 10),
                ImageUploadField(controller: bannerCtrl, label: 'Banner image'),
                const SizedBox(height: 10),
                TextFormField(controller: descCtrl, maxLines: 5,
                    decoration: const InputDecoration(labelText: 'Description (HTML)', alignLabelWithHint: true)),
                if (saveError != null) ...[
                  const SizedBox(height: 10),
                  Text(saveError!, style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.error)),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      final formOk = formKey.currentState?.validate() ?? false;
                      final missingDate = date == null;
                      if (missingDate) setSheetState(() => dateError = 'Date & time is required');
                      if (!formOk || missingDate) {
                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                          content: Text(missingDate
                              ? 'Please pick a date & time before saving'
                              : 'Please fix the highlighted fields above'),
                          backgroundColor: AppColors.error,
                        ));
                        return;
                      }
                      final body = {
                        'title': titleCtrl.text.trim(),
                        'description_html': descCtrl.text.trim(),
                        'banner_url': bannerCtrl.text.trim(),
                        'event_date': date?.toIso8601String(),
                        'location': locationCtrl.text.trim(),
                        'meeting_link': meetingCtrl.text.trim(),
                      };
                      try {
                        if (existing == null) {
                          await ApiService.createEvent(body);
                        } else {
                          await ApiService.updateEvent(existing['id'] as int, body);
                        }
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      } catch (e) {
                        setSheetState(() => saveError = e.toString());
                      }
                    },
                    child: const Text('Save'),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
    if (saved == true) _load();
  }

  Future<void> _delete(Map<String, dynamic> event) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete event?'),
        content: Text('Delete "${event['title']}"? Registrations will be removed too.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    await ApiService.deleteEvent(event['id'] as int);
    _load();
  }

  Future<void> _togglePublish(Map<String, dynamic> event) async {
    await ApiService.updateEvent(event['id'] as int, {'is_published': !(event['is_published'] == true)});
    _load();
  }

  Future<void> _showAttendees(Map<String, dynamic> event) async {
    final attendees = await ApiService.getEventAttendees(event['id'] as int);
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        expand: false,
        builder: (ctx, scrollCtrl) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text('Attendees — ${event['title']} (${attendees.length})',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
              ),
              TextButton.icon(
                onPressed: () => _exportCsv(event['id'] as int),
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text('Export CSV'),
              ),
            ]),
            const Divider(),
            Expanded(
              child: attendees.isEmpty
                  ? Center(child: Text('No registrations yet', style: GoogleFonts.inter(color: AppColors.textSecondary)))
                  : ListView.builder(
                      controller: scrollCtrl,
                      itemCount: attendees.length,
                      itemBuilder: (context, i) {
                        final a = attendees[i] as Map<String, dynamic>;
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.person_outline_rounded),
                          title: Text(a['name'] ?? ''),
                          subtitle: Text('${a['phone'] ?? ''}  ${a['email'] ?? ''}'),
                        );
                      },
                    ),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _exportCsv(int eventId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final res = await http.get(
      Uri.parse(ApiConstants.eventAttendeesExport(eventId)),
      headers: {if (token != null) 'Authorization': 'Bearer $token'},
    );
    if (res.statusCode != 200) return;
    final blob = html.Blob([utf8.encode(res.body)], 'text/csv');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', 'event_${eventId}_attendees.csv')
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text('Events — Admin', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(icon: const Icon(Icons.add_rounded, color: Colors.white), onPressed: () => _openForm()),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _events.isEmpty
              ? Center(child: Text('No events yet', style: GoogleFonts.inter(color: AppColors.textSecondary)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _events.length,
                  itemBuilder: (context, i) {
                    final e = _events[i] as Map<String, dynamic>;
                    final published = e['is_published'] == true;
                    DateTime? date;
                    try {
                      date = e['event_date'] != null ? DateTime.parse(e['event_date']) : null;
                    } catch (_) {}
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        title: Text(e['title'] ?? '', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                            '${date != null ? DateFormat('d MMM yyyy, h:mm a').format(date) : 'No date'} · '
                            '${e['registration_count'] ?? 0} registered',
                            style: GoogleFonts.inter(fontSize: 12)),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(
                            icon: const Icon(Icons.people_outline_rounded, size: 20),
                            onPressed: () => _showAttendees(e),
                            tooltip: 'Attendees',
                          ),
                          IconButton(
                            icon: Icon(published ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                                color: published ? AppColors.success : Colors.grey, size: 20),
                            onPressed: () => _togglePublish(e),
                          ),
                          IconButton(icon: const Icon(Icons.edit_outlined, size: 20), onPressed: () => _openForm(existing: e)),
                          IconButton(icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                              onPressed: () => _delete(e)),
                        ]),
                      ),
                    );
                  },
                ),
    );
  }
}
