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

/// Super-admin CRUD for Live Sessions / Workshops + attendee list/CSV
/// export. `is_featured` controls whether it's spotlighted on the
/// student home page.
class LiveSessionsAdminScreen extends StatefulWidget {
  const LiveSessionsAdminScreen({super.key});

  @override
  State<LiveSessionsAdminScreen> createState() => _LiveSessionsAdminScreenState();
}

class _LiveSessionsAdminScreenState extends State<LiveSessionsAdminScreen> {
  List<dynamic> _sessions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _sessions = await ApiService.getLiveSessionsAdmin();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _openForm({Map<String, dynamic>? existing}) async {
    final formKey = GlobalKey<FormState>();
    final titleCtrl = TextEditingController(text: existing?['title'] ?? '');
    final hostCtrl = TextEditingController(text: existing?['host_name'] ?? '');
    final bannerCtrl = TextEditingController(text: existing?['banner_url'] ?? '');
    final platformCtrl = TextEditingController(text: existing?['platform'] ?? '');
    final meetingCtrl = TextEditingController(text: existing?['meeting_link'] ?? '');
    final recordingCtrl = TextEditingController(text: existing?['recording_url'] ?? '');
    final redirectCtrl = TextEditingController(text: existing?['redirect_link'] ?? '');
    final durationCtrl = TextEditingController(text: '${existing?['duration_minutes'] ?? 60}');
    final descCtrl = TextEditingController(text: existing?['description_html'] ?? '');
    final priceCtrl = TextEditingController(text: '${existing?['price'] ?? 0}');
    final taxCtrl = TextEditingController(text: '${existing?['tax_percent'] ?? 0}');
    final bookingCtrl =
        TextEditingController(text: '${existing?['booking_amount'] ?? 0}');
    final originalPriceCtrl = TextEditingController(text: '${existing?['original_price'] ?? ''}');
    bool isPaid = ((existing?['price'] as num?) ?? 0) > 0;
    bool featured = existing?['is_featured'] == true;
    int? linkedModuleId = existing?['linked_module_id'] as int?;
    List<dynamic> availableModules = [];
    try {
      availableModules = await ApiService.getAllTrainingModulesLite();
    } catch (_) {}
    DateTime? date;
    try {
      date = existing?['session_date'] != null ? DateTime.parse(existing!['session_date']) : null;
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
                Text(existing == null ? 'New Live Session / Workshop' : 'Edit Session',
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
                TextFormField(controller: hostCtrl, decoration: const InputDecoration(labelText: 'Host name')),
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
                TextFormField(controller: durationCtrl, keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Duration (minutes)')),
                const SizedBox(height: 10),
                TextFormField(controller: platformCtrl, decoration: const InputDecoration(labelText: 'Platform (Zoom / Meet / Jitsi)')),
                const SizedBox(height: 10),
                TextFormField(
                  controller: meetingCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Meeting link * (internal only — never shown in-app)',
                    helperText: 'Sent to registrants over WhatsApp separately. Students never see this in the app.',
                    helperMaxLines: 2,
                  ),
                  validator: (v) {
                    final t = (v ?? '').trim();
                    if (t.isEmpty) return 'Meeting link is required';
                    final uri = Uri.tryParse(t);
                    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
                      return 'Enter a valid http(s) URL';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: redirectCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Redirect link (e.g. WhatsApp group invite)',
                    helperText: 'Shown to students on the registration-confirmation screen.',
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(controller: recordingCtrl, decoration: const InputDecoration(labelText: 'Recording link (add after session ends)')),
                const SizedBox(height: 10),
                ImageUploadField(controller: bannerCtrl, label: 'Banner image'),
                const SizedBox(height: 10),
                TextFormField(controller: descCtrl, maxLines: 5,
                    decoration: const InputDecoration(labelText: 'Description (HTML)', alignLabelWithHint: true)),
                const SizedBox(height: 6),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Paid session'),
                  subtitle: const Text('Off = free registration. On = students pay before their spot is confirmed.', style: TextStyle(fontSize: 12)),
                  value: isPaid,
                  onChanged: (v) => setSheetState(() => isPaid = v),
                  activeColor: AppColors.accent,
                ),
                if (isPaid) ...[
                  const SizedBox(height: 6),
                  Row(children: [
                    Expanded(
                      child: TextFormField(
                        controller: priceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Price (₹) *', prefixText: '₹ '),
                        validator: (v) {
                          if (!isPaid) return null;
                          final n = double.tryParse((v ?? '').trim());
                          if (n == null || n <= 0) return 'Enter a valid price';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: taxCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Tax %', suffixText: '%'),
                        validator: (v) {
                          final n = double.tryParse((v ?? '0').trim());
                          if (n == null || n < 0) return 'Invalid';
                          return null;
                        },
                      ),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: bookingCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'Booking amount', prefixText: '₹ '),
                    validator: (v) {
                      final n = double.tryParse((v ?? '0').trim());
                      if (n == null || n < 0) return 'Invalid';
                      return null;
                    },
                  ),
                  const SizedBox(height: 4),
                  Text('Leave tax at 0 if not applicable. A booking amount '
                      'above 0 lets students hold a seat by paying that much '
                      'now, with the balance due before it starts — set it to '
                      '0 to require the whole fee at registration.',
                      style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: originalPriceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Original price (optional)',
                      prefixText: '₹ ',
                      helperText: 'Shown crossed-out next to the real price, e.g. "₹1500 → ₹499". Leave blank to hide.',
                      helperMaxLines: 2,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Feature on home page'),
                  subtitle: const Text('Spotlights this workshop for every student on the home feed', style: TextStyle(fontSize: 12)),
                  value: featured,
                  onChanged: (v) => setSheetState(() => featured = v),
                  activeColor: AppColors.accent,
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int?>(
                  initialValue: linkedModuleId,
                  decoration: const InputDecoration(
                    labelText: 'Bundle a Training Module (optional)',
                    helperText: 'Registering for this workshop also unlocks the picked course for free — it stays a normal paid course for everyone else.',
                    helperMaxLines: 3,
                  ),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('None')),
                    ...availableModules.map((m) => DropdownMenuItem<int?>(
                          value: m['id'] as int,
                          child: Text(m['title'] as String, overflow: TextOverflow.ellipsis),
                        )),
                  ],
                  onChanged: (v) => setSheetState(() => linkedModuleId = v),
                ),
                if (saveError != null) ...[
                  const SizedBox(height: 10),
                  Text(saveError!, style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.error)),
                ],
                const SizedBox(height: 12),
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
                        'host_name': hostCtrl.text.trim(),
                        'description_html': descCtrl.text.trim(),
                        'banner_url': bannerCtrl.text.trim(),
                        'session_date': date?.toIso8601String(),
                        'duration_minutes': int.tryParse(durationCtrl.text.trim()) ?? 60,
                        'platform': platformCtrl.text.trim(),
                        'meeting_link': meetingCtrl.text.trim(),
                        'recording_url': recordingCtrl.text.trim(),
                        'redirect_link': redirectCtrl.text.trim(),
                        'is_featured': featured,
                        'price': isPaid ? (double.tryParse(priceCtrl.text.trim()) ?? 0) : 0,
                        'tax_percent': isPaid ? (double.tryParse(taxCtrl.text.trim()) ?? 0) : 0,
                        'booking_amount':
                            isPaid ? (double.tryParse(bookingCtrl.text.trim()) ?? 0) : 0,
                        if (isPaid && originalPriceCtrl.text.trim().isNotEmpty)
                          'original_price': double.tryParse(originalPriceCtrl.text.trim()),
                        if (!isPaid || originalPriceCtrl.text.trim().isEmpty) 'clear_original_price': true,
                        if (linkedModuleId != null) 'linked_module_id': linkedModuleId,
                        if (linkedModuleId == null) 'clear_linked_module': true,
                      };
                      try {
                        if (existing == null) {
                          await ApiService.createLiveSession(body);
                        } else {
                          await ApiService.updateLiveSession(existing['id'] as int, body);
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

  Future<void> _delete(Map<String, dynamic> session) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete session?'),
        content: Text('Delete "${session['title']}"? Registrations will be removed too.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    await ApiService.deleteLiveSession(session['id'] as int);
    _load();
  }

  Future<void> _togglePublish(Map<String, dynamic> session) async {
    await ApiService.updateLiveSession(session['id'] as int, {'is_published': !(session['is_published'] == true)});
    _load();
  }

  Future<void> _toggleFeatured(Map<String, dynamic> session) async {
    await ApiService.updateLiveSession(session['id'] as int, {'is_featured': !(session['is_featured'] == true)});
    _load();
  }

  Future<void> _showAttendees(Map<String, dynamic> session) async {
    final sessionId = session['id'] as int;
    final attendees = List<Map<String, dynamic>>.from(
        (await ApiService.getLiveSessionAttendees(sessionId)).map((e) => Map<String, dynamic>.from(e as Map)));
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => DraggableScrollableSheet(
          initialChildSize: 0.7,
          expand: false,
          builder: (ctx, scrollCtrl) => Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text('Attendees — ${session['title']} (${attendees.length})',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
                ),
                TextButton.icon(
                  onPressed: () => _exportCsv(sessionId),
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: const Text('Export CSV'),
                ),
              ]),
              const Divider(),
              Expanded(
                child: attendees.isEmpty
                    ? Center(child: Text('No registrations yet', style: GoogleFonts.inter(color: AppColors.textSecondary)))
                    : ListView.separated(
                        controller: scrollCtrl,
                        itemCount: attendees.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) => _AttendeeCard(
                          attendee: attendees[i],
                          onMarkPaid: attendees[i]['status'] == 'paid' ? null : () async {
                            final confirmed = await showDialog<bool>(
                              context: ctx,
                              builder: (dCtx) => AlertDialog(
                                title: const Text('Mark as paid?'),
                                content: Text(
                                    'Only do this after you\'ve actually collected payment from ${attendees[i]['name'] ?? 'this person'} directly (UPI/cash) — this records it without going through Cashfree.'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Cancel')),
                                  FilledButton(
                                      onPressed: () => Navigator.pop(dCtx, true),
                                      style: FilledButton.styleFrom(backgroundColor: AppColors.success),
                                      child: const Text('Mark Paid')),
                                ],
                              ),
                            );
                            if (confirmed != true) return;
                            final updated = await ApiService.markLiveSessionAttendeePaid(sessionId, attendees[i]['id'] as int);
                            setSheetState(() => attendees[i] = updated);
                          },
                          onDelete: () async {
                            final confirmed = await showDialog<bool>(
                              context: ctx,
                              builder: (dCtx) => AlertDialog(
                                title: const Text('Remove this registration?'),
                                content: Text(
                                    'This deletes ${attendees[i]['name'] ?? 'this entry'} permanently — use this for stuck/test registrations, not real attendees.'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Cancel')),
                                  FilledButton(
                                      onPressed: () => Navigator.pop(dCtx, true),
                                      style: FilledButton.styleFrom(backgroundColor: AppColors.error),
                                      child: const Text('Delete')),
                                ],
                              ),
                            );
                            if (confirmed != true) return;
                            await ApiService.deleteLiveSessionAttendee(sessionId, attendees[i]['id'] as int);
                            setSheetState(() => attendees.removeAt(i));
                          },
                        ),
                      ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Future<void> _exportCsv(int sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final res = await http.get(
      Uri.parse(ApiConstants.liveSessionAttendeesExport(sessionId)),
      headers: {if (token != null) 'Authorization': 'Bearer $token'},
    );
    if (res.statusCode != 200) return;
    final blob = html.Blob([utf8.encode(res.body)], 'text/csv');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', 'live_session_${sessionId}_attendees.csv')
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
        title: Text('Live Sessions — Admin', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(icon: const Icon(Icons.add_rounded, color: Colors.white), onPressed: () => _openForm()),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _sessions.isEmpty
              ? Center(child: Text('No sessions yet', style: GoogleFonts.inter(color: AppColors.textSecondary)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _sessions.length,
                  itemBuilder: (context, i) {
                    final s = _sessions[i] as Map<String, dynamic>;
                    final published = s['is_published'] == true;
                    final featured = s['is_featured'] == true;
                    final price = (s['price'] as num?) ?? 0;
                    DateTime? date;
                    try {
                      date = s['session_date'] != null ? DateTime.parse(s['session_date']) : null;
                    } catch (_) {}
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        title: Row(children: [
                          Expanded(child: Text(s['title'] ?? '', style: GoogleFonts.inter(fontWeight: FontWeight.w600))),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                                color: (price > 0 ? AppColors.accent : AppColors.success).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(5)),
                            child: Text(price > 0 ? '₹$price' : 'FREE',
                                style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w700,
                                    color: price > 0 ? AppColors.accent : AppColors.success)),
                          ),
                          if (featured) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                  color: AppColors.accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(5)),
                              child: Text('FEATURED',
                                  style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w700, color: AppColors.accent)),
                            ),
                          ],
                        ]),
                        subtitle: Text(
                            '${date != null ? DateFormat('d MMM yyyy, h:mm a').format(date) : 'No date'} · '
                            '${s['registration_count'] ?? 0} registered',
                            style: GoogleFonts.inter(fontSize: 12)),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(
                            icon: Icon(featured ? Icons.star_rounded : Icons.star_border_rounded,
                                color: featured ? AppColors.accent : Colors.grey, size: 20),
                            tooltip: 'Feature on home page',
                            onPressed: () => _toggleFeatured(s),
                          ),
                          IconButton(
                            icon: const Icon(Icons.people_outline_rounded, size: 20),
                            onPressed: () => _showAttendees(s),
                            tooltip: 'Attendees',
                          ),
                          IconButton(
                            icon: Icon(published ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                                color: published ? AppColors.success : Colors.grey, size: 20),
                            onPressed: () => _togglePublish(s),
                          ),
                          IconButton(icon: const Icon(Icons.edit_outlined, size: 20), onPressed: () => _openForm(existing: s)),
                          IconButton(icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                              onPressed: () => _delete(s)),
                        ]),
                      ),
                    );
                  },
                ),
    );
  }
}

class _AttendeeCard extends StatelessWidget {
  final Map<String, dynamic> attendee;
  final VoidCallback? onDelete;
  final VoidCallback? onMarkPaid;
  const _AttendeeCard({required this.attendee, this.onDelete, this.onMarkPaid});

  @override
  Widget build(BuildContext context) {
    final a = attendee;
    final status = (a['status'] ?? '').toString();
    final statusColor = switch (status) {
      'paid' || 'registered' => AppColors.success,
      'pending' => AppColors.warning,
      _ => AppColors.textSecondary,
    };
    final totalAmount = (a['total_amount'] as num?) ?? 0;
    String? registeredAt;
    try {
      final raw = a['registered_at'];
      if (raw != null) registeredAt = DateFormat('d MMM yyyy, h:mm a').format(DateTime.parse(raw.toString()));
    } catch (_) {}

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text((a['name'] ?? '').toString(),
                style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14.5)),
          ),
          if (status.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
              child: Text(status.toUpperCase(),
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: statusColor, letterSpacing: 0.3)),
            ),
          if (onMarkPaid != null)
            IconButton(
              icon: const Icon(Icons.check_circle_outline_rounded, size: 19, color: AppColors.success),
              tooltip: 'Mark as paid (manual UPI/cash)',
              onPressed: onMarkPaid,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.only(left: 8),
            ),
          if (onDelete != null)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 19, color: AppColors.error),
              tooltip: 'Delete registration',
              onPressed: onDelete,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.only(left: 8),
            ),
        ]),
        const SizedBox(height: 10),
        _AttendeeRow(icon: Icons.phone_rounded, label: (a['phone'] ?? '').toString()),
        if ((a['email'] ?? '').toString().isNotEmpty)
          _AttendeeRow(icon: Icons.email_rounded, label: (a['email']).toString()),
        if ((a['college'] ?? '').toString().isNotEmpty)
          _AttendeeRow(icon: Icons.school_rounded, label: (a['college']).toString()),
        if ((a['branch'] ?? '').toString().isNotEmpty)
          _AttendeeRow(icon: Icons.category_rounded, label: (a['branch']).toString()),
        if ((a['address'] ?? '').toString().isNotEmpty || (a['city'] ?? '').toString().isNotEmpty)
          _AttendeeRow(
            icon: Icons.location_on_rounded,
            label: [
              (a['address'] ?? '').toString(),
              (a['city'] ?? '').toString(),
            ].where((s) => s.isNotEmpty).join(', '),
          ),
        if ((a['occupation'] ?? '').toString() == 'professional')
          _AttendeeRow(icon: Icons.work_rounded, label: 'Working professional'),
        // A held seat that still owes money. Said loudly, because it is the
        // only row on this list somebody has to act on.
        if ((a['status'] ?? '').toString() == 'pay_later')
          _AttendeeRow(
              icon: Icons.schedule_rounded,
              label: 'PAY LATER — ₹${(a['amount'] ?? 0)} still owed',
              colour: AppColors.warning),
        if (totalAmount > 0 && (a['status'] ?? '').toString() != 'pay_later')
          _AttendeeRow(icon: Icons.payments_rounded, label: '₹$totalAmount paid'),
        if ((double.tryParse('${a['balance_due'] ?? 0}') ?? 0) > 0)
          _AttendeeRow(
              icon: Icons.account_balance_wallet_rounded,
              label: 'Balance ₹${a['balance_due']} due',
              colour: AppColors.warning),
        if ((a['receipt_number'] ?? '').toString().isNotEmpty)
          _AttendeeRow(icon: Icons.receipt_long_rounded, label: 'Receipt ${a['receipt_number']}'),
        if ((a['payment_proof_url'] ?? '').toString().isNotEmpty)
          InkWell(
            onTap: () => html.window.open((a['payment_proof_url'] as String), '_blank'),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(children: [
                const Icon(Icons.image_rounded, size: 14, color: AppColors.accent),
                const SizedBox(width: 6),
                Text('View payment screenshot',
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.accent, fontWeight: FontWeight.w600, decoration: TextDecoration.underline)),
              ]),
            ),
          ),
        if (registeredAt != null)
          _AttendeeRow(icon: Icons.event_available_rounded, label: 'Registered $registeredAt'),
      ]),
    );
  }
}

class _AttendeeRow extends StatelessWidget {
  final IconData icon;
  final String label;

  /// Set for the one row that needs acting on rather than reading.
  final Color? colour;
  const _AttendeeRow({required this.icon, required this.label, this.colour});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 14, color: colour ?? AppColors.textSecondary),
        const SizedBox(width: 8),
        Expanded(
            child: Text(label,
                style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: colour == null ? FontWeight.w400 : FontWeight.w700,
                    color: colour ?? AppColors.textPrimary))),
      ]),
    );
  }
}
