// EdTech CRM — the pipeline over WhatsApp contacts.
//
// Not an inbox. Chats, templates and broadcast live on the altronbotsaas
// dashboard; this owns the part that is EdTech's alone — which lead is at what
// stage, who owns them, what was said about them, and whether they became a
// student. Conversation history appears read-only, as context for that
// decision.

import '../../widgets/lead_import_sheet.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/api_service.dart';

const _stageLabels = {
  'new': 'New',
  'contacted': 'Contacted',
  'interested': 'Interested',
  'enrolled': 'Enrolled',
  'lost': 'Lost',
};

const _stageColors = {
  'new': Color(0xFF757575),
  'contacted': Color(0xFF0277BD),
  'interested': Color(0xFF6A1B9A),
  'enrolled': Color(0xFF2E7D32),
  'lost': Color(0xFFB71C1C),
};

class CrmScreen extends StatefulWidget {
  const CrmScreen({super.key});

  @override
  State<CrmScreen> createState() => _CrmScreenState();
}

class _CrmScreenState extends State<CrmScreen> {
  List<dynamic> _leads = [];
  Map<String, dynamic> _counts = {};
  Map<String, dynamic> _summary = {};
  String _stage = '';
  String _query = '';
  bool _loading = true;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final res = await ApiService.crmLeads(stage: _stage, q: _query);
      _leads = (res['leads'] as List?) ?? [];
      _counts = Map<String, dynamic>.from(res['counts'] ?? {});
    } catch (_) {
      _leads = [];
    }
    try {
      _summary = await ApiService.crmSummary();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _open(Map<String, dynamic> lead) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => LeadDetailScreen(phone: lead['phone'] as String)),
    );
    if (changed == true) {
      setState(() => _loading = true);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        // The theme paints AppBar foreground white for the dark bars used
        // elsewhere; on a white bar that hides the title and every action.
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: Text('CRM',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 17)),
        actions: [
          IconButton(
              tooltip: 'Scholarship test candidates',
              onPressed: () => context.push('/scholars'),
              icon: const Icon(Icons.school_rounded, size: 21)),
          IconButton(
              tooltip: 'Import leads from a CSV',
              onPressed: () => LeadImportSheet.show(context, () {
                    setState(() => _loading = true);
                    _load();
                  }),
              icon: const Icon(Icons.upload_file_rounded, size: 21)),
          IconButton(
              onPressed: () {
                setState(() => _loading = true);
                _load();
              },
              icon: const Icon(Icons.refresh_rounded, size: 21)),
        ],
      ),
      body: Column(children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          child: Column(children: [
            Row(children: [
              _Stat(label: 'Total', value: '${_summary['total'] ?? '—'}'),
              _Stat(label: 'Registered', value: '${_summary['linked_students'] ?? '—'}'),
              _Stat(label: 'Active 24h', value: '${_summary['active_24h'] ?? '—'}'),
              _Stat(
                  label: 'Opted out',
                  value: '${_summary['opted_out'] ?? '—'}',
                  warn: (_summary['opted_out'] ?? 0) is int &&
                      (_summary['opted_out'] ?? 0) > 0),
            ]),
            const SizedBox(height: 10),
            TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search name or number',
                prefixIcon: const Icon(Icons.search_rounded, size: 19),
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onSubmitted: (v) {
                setState(() {
                  _query = v.trim();
                  _loading = true;
                });
                _load();
              },
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 32,
              child: ListView(scrollDirection: Axis.horizontal, children: [
                _StageChip(
                  label: 'All',
                  count: _counts.values.fold<int>(
                      0, (a, b) => a + (b is int ? b : 0)),
                  selected: _stage.isEmpty,
                  color: AppColors.primary,
                  onTap: () {
                    setState(() {
                      _stage = '';
                      _loading = true;
                    });
                    _load();
                  },
                ),
                for (final s in _stageLabels.keys)
                  _StageChip(
                    label: _stageLabels[s]!,
                    count: (_counts[s] as int?) ?? 0,
                    selected: _stage == s,
                    color: _stageColors[s]!,
                    onTap: () {
                      setState(() {
                        _stage = s;
                        _loading = true;
                      });
                      _load();
                    },
                  ),
              ]),
            ),
          ]),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _leads.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          _query.isNotEmpty || _stage.isNotEmpty
                              ? 'No leads match that.'
                              : 'No leads yet. They appear here the moment '
                                  'someone messages the WhatsApp number.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                              color: AppColors.textSecondary, height: 1.5),
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: _leads.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) => _LeadRow(
                          lead: _leads[i] as Map<String, dynamic>,
                          onTap: () => _open(_leads[i] as Map<String, dynamic>),
                        ),
                      ),
                    ),
        ),
      ]),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final bool warn;
  const _Stat({required this.label, required this.value, this.warn = false});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Text(value,
              style: GoogleFonts.poppins(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: warn ? AppColors.error : AppColors.textPrimary)),
          Text(label,
              style: GoogleFonts.inter(fontSize: 10.5, color: AppColors.textSecondary)),
        ]),
      );
}

class _StageChip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _StageChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 7),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: selected ? color : color.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withValues(alpha: selected ? 1 : 0.3)),
            ),
            child: Text('$label · $count',
                style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : color)),
          ),
        ),
      );
}

class _LeadRow extends StatelessWidget {
  final Map<String, dynamic> lead;
  final VoidCallback onTap;
  const _LeadRow({required this.lead, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final stage = lead['stage'] as String? ?? 'new';
    final color = _stageColors[stage] ?? AppColors.textSecondary;
    final isStudent = lead['student_user_id'] != null;
    final optedOut = lead['opt_in'] == false;
    final last = lead['last_message'] as String? ?? '';
    final plan = lead['plan'] as String? ?? '';
    final occupation = lead['occupation'] as String? ?? '';
    final org = (lead['company'] as String?)?.isNotEmpty == true
        ? lead['company'] as String
        : lead['college'] as String? ?? '';
    final email = lead['email'] as String? ?? '';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black.withValues(alpha: 0.07)),
        ),
        child: Row(children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Text(
                    (lead['name'] as String?)?.isNotEmpty == true
                        ? lead['name'] as String
                        : lead['phone'] as String? ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                        fontSize: 13.5, fontWeight: FontWeight.w600),
                  ),
                ),
                if (isStudent) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.verified_rounded, size: 13, color: AppColors.success),
                ],
                if (optedOut) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.notifications_off_rounded, size: 13, color: AppColors.error),
                ],
              ]),
              const SizedBox(height: 2),
              Row(children: [
                if ((lead['phone'] as String? ?? '').isNotEmpty) ...[
                  Text(lead['phone'] as String,
                      style: GoogleFonts.inter(
                          fontSize: 11.5, color: AppColors.textSecondary)),
                  const SizedBox(width: 8),
                ],
                if (occupation.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: (occupation == 'working'
                              ? const Color(0xFF6A1B9A)
                              : const Color(0xFF0277BD))
                          .withValues(alpha: 0.11),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(occupation == 'working' ? 'WORKING' : 'STUDENT',
                        style: GoogleFonts.inter(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w700,
                            color: occupation == 'working'
                                ? const Color(0xFF6A1B9A)
                                : const Color(0xFF0277BD))),
                  ),
                  const SizedBox(width: 6),
                ],
                if (plan.isNotEmpty && plan != 'free')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.11),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(plan.toUpperCase(),
                        style: GoogleFonts.inter(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary)),
                  ),
              ]),
              if (org.isNotEmpty || email.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                    [org, email].where((x) => x.isNotEmpty).join('  ·  '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                        fontSize: 11, color: AppColors.textSecondary)),
              ],
              if (last.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(last,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                        fontSize: 10.5,
                        fontStyle: FontStyle.italic,
                        color: AppColors.textSecondary)),
              ],
            ]),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(_stageLabels[stage] ?? stage,
                style: GoogleFonts.inter(
                    fontSize: 9.5, fontWeight: FontWeight.w700, color: color)),
          ),
        ]),
      ),
    );
  }
}

/// One lead: stage, owner, notes, the student behind them, and the recent
/// conversation as read-only context.
class LeadDetailScreen extends StatefulWidget {
  final String phone;
  const LeadDetailScreen({super.key, required this.phone});

  @override
  State<LeadDetailScreen> createState() => _LeadDetailScreenState();
}

class _LeadDetailScreenState extends State<LeadDetailScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  bool _changed = false;
  final _noteCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      _data = await ApiService.crmLead(widget.phone);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _setStage(String stage) async {
    try {
      await ApiService.crmUpdateLead(widget.phone, {'stage': stage});
      _changed = true;
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e is ApiException ? e.message : 'Could not update'),
            backgroundColor: AppColors.error));
      }
    }
  }

  /// Admin filling in what a student never did. Most accounts predate the
  /// occupation question, so without this the CRM can never segment them.
  Future<void> _editStudent(Map<String, dynamic> student) async {
    final name = TextEditingController(text: '${student['name'] ?? ''}');
    final email = TextEditingController(text: '${student['email'] ?? ''}');
    final org = TextEditingController(
        text: '${student['company'] ?? student['college'] ?? ''}');
    var occupation = '${student['occupation'] ?? 'student'}';
    if (occupation != 'working') occupation = 'student';

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text('Edit details',
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Name')),
              const SizedBox(height: 10),
              TextField(
                  controller: email,
                  decoration: const InputDecoration(labelText: 'Email')),
              const SizedBox(height: 14),
              Row(children: [
                for (final o in const [('student', 'Student'), ('working', 'Working')])
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setLocal(() => occupation = o.$1),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: occupation == o.$1
                                ? AppColors.primary.withValues(alpha: 0.1)
                                : Colors.transparent,
                            border: Border.all(
                                color: occupation == o.$1
                                    ? AppColors.primary
                                    : Colors.black26),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Center(
                            child: Text(o.$2,
                                style: GoogleFonts.inter(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: occupation == o.$1
                                        ? AppColors.primary
                                        : AppColors.textSecondary)),
                          ),
                        ),
                      ),
                    ),
                  ),
              ]),
              const SizedBox(height: 10),
              TextField(
                controller: org,
                decoration: InputDecoration(
                    labelText: occupation == 'working' ? 'Company' : 'College'),
              ),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Save')),
          ],
        ),
      ),
    );
    if (saved != true) return;
    try {
      await ApiService.crmUpdateStudent(student['id'] as int, {
        'name': name.text.trim(),
        'email': email.text.trim(),
        'occupation': occupation,
        if (occupation == 'student') 'college': org.text.trim(),
        if (occupation == 'working') 'company': org.text.trim(),
      });
      _changed = true;
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e is ApiException ? e.message : 'Could not save'),
            backgroundColor: AppColors.error));
      }
    }
  }

  Future<void> _addNote() async {
    final text = _noteCtrl.text.trim();
    if (text.isEmpty) return;
    try {
      await ApiService.crmAddNote(widget.phone, text);
      _noteCtrl.clear();
      _changed = true;
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not save the note')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lead = _data?['lead'] as Map<String, dynamic>?;
    final student = _data?['student'] as Map<String, dynamic>?;
    final messages = (_data?['messages'] as List?) ?? [];
    final notes = (_data?['notes'] as List?) ?? [];
    final stage = lead?['stage'] as String? ?? 'new';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context, _changed),
          ),
          title: Text(
            (lead?['name'] as String?)?.isNotEmpty == true
                ? lead!['name'] as String
                : widget.phone,
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16),
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : lead == null
                ? Center(
                    child: Text('Lead not found',
                        style: GoogleFonts.inter(color: AppColors.textSecondary)))
                : ListView(padding: const EdgeInsets.all(14), children: [
                    _Card(title: 'Stage', child: Wrap(spacing: 7, runSpacing: 7, children: [
                      for (final s in _stageLabels.keys)
                        _StageChip(
                          label: _stageLabels[s]!,
                          count: 0,
                          selected: stage == s,
                          color: _stageColors[s]!,
                          onTap: () => _setStage(s),
                        ),
                    ])),
                    const SizedBox(height: 12),
                    _Card(
                      title: 'Contact',
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        _kv('Phone', lead['phone'] as String? ?? ''),
                        _kv('Opted in',
                            // Three states, not two. Null is "never asked",
                            // which is the honest answer for an imported lead
                            // and a different thing from consent.
                            lead['opt_in'] == false
                                ? 'No — do not send marketing'
                                : lead['opt_in'] == true
                                    ? 'Yes'
                                    : 'Not asked — imported, no consent on file'),
                        if (lead['opt_in_source'] != null)
                          _kv('Opt-in source', '${lead['opt_in_source']}'),
                        if (lead['last_inbound_at'] != null)
                          _kv('Last message', '${lead['last_inbound_at']}'.split('T').first),
                      ]),
                    ),
                    if (student != null) ...[
                      const SizedBox(height: 12),
                      _Card(
                        title: 'Student account',
                        trailing: TextButton.icon(
                          onPressed: () => _editStudent(student),
                          icon: const Icon(Icons.edit_outlined, size: 15),
                          label: const Text('Edit'),
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          _kv('Name', '${student['name'] ?? ''}'),
                          if (student['phone'] != null) _kv('Phone', '${student['phone']}'),
                          if (student['email'] != null) _kv('Email', '${student['email']}'),
                          if ((student['occupation'] as String? ?? '').isNotEmpty)
                            _kv('Occupation',
                                student['occupation'] == 'working'
                                    ? 'Working professional'
                                    : 'Student'),
                          if (student['college'] != null) _kv('College', '${student['college']}'),
                          if (student['company'] != null) _kv('Company', '${student['company']}'),
                          if (student['address'] != null) _kv('Address', '${student['address']}'),
                          _kv('Plan', '${student['plan'] ?? 'free'}'),
                          if (student['status'] != null) _kv('Status', '${student['status']}'),
                          if (student['created_at'] != null)
                            _kv('Joined', '${student['created_at']}'.split('T').first),
                        ]),
                      ),
                    ],
                    const SizedBox(height: 12),
                    _Card(
                      title: 'Notes',
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(
                            child: TextField(
                              controller: _noteCtrl,
                              decoration: InputDecoration(
                                hintText: 'Add a note',
                                isDense: true,
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(9)),
                              ),
                              onSubmitted: (_) => _addNote(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(onPressed: _addNote, child: const Text('Add')),
                        ]),
                        const SizedBox(height: 10),
                        if (notes.isEmpty)
                          Text('No notes yet.',
                              style: GoogleFonts.inter(
                                  fontSize: 12, color: AppColors.textSecondary))
                        else
                          for (final n in notes)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${n['text']}',
                                        style: GoogleFonts.inter(
                                            fontSize: 12.5, height: 1.4)),
                                    Text('${n['created_at']}'.split('T').first,
                                        style: GoogleFonts.inter(
                                            fontSize: 10,
                                            color: AppColors.textSecondary)),
                                  ]),
                            ),
                      ]),
                    ),
                    const SizedBox(height: 12),
                    _Card(
                      title: 'Recent conversation',
                      subtitle: 'What they sent us. The full thread, the AI '
                          'replies and the reply box are on the WhatsApp dashboard.',
                      child: messages.isEmpty
                          ? Text('No messages yet.',
                              style: GoogleFonts.inter(
                                  fontSize: 12, color: AppColors.textSecondary))
                          : Column(
                              children: [
                                for (final m in messages)
                                  Align(
                                    alignment: m['direction'] == 'out'
                                        ? Alignment.centerRight
                                        : Alignment.centerLeft,
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 6),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 11, vertical: 7),
                                      constraints: const BoxConstraints(maxWidth: 300),
                                      decoration: BoxDecoration(
                                        color: m['direction'] == 'out'
                                            ? AppColors.primary.withValues(alpha: 0.1)
                                            : Colors.black.withValues(alpha: 0.05),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text('${m['body'] ?? ''}',
                                          style: GoogleFonts.inter(
                                              fontSize: 12.5, height: 1.35)),
                                    ),
                                  ),
                              ],
                            ),
                    ),
                    if ((_data?['dashboard_url'] as String? ?? '').isNotEmpty) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => launchUrl(
                              Uri.parse(_data!['dashboard_url'] as String),
                              mode: LaunchMode.externalApplication),
                          icon: const Icon(Icons.open_in_new_rounded, size: 17),
                          label: const Text('Open chat in WhatsApp dashboard'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(11)),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 30),
                  ]),
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 96,
            child: Text(k,
                style: GoogleFonts.inter(
                    fontSize: 11.5, color: AppColors.textSecondary)),
          ),
          Expanded(
              child: Text(v, style: GoogleFonts.inter(fontSize: 12.5))),
        ]),
      );
}

class _Card extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;
  const _Card({
    required this.title,
    this.subtitle = '',
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black.withValues(alpha: 0.07)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(title,
                  style: GoogleFonts.poppins(
                      fontSize: 13, fontWeight: FontWeight.w600)),
            ),
            if (trailing != null) trailing!,
          ]),
          if (subtitle.isNotEmpty)
            Text(subtitle,
                style: GoogleFonts.inter(fontSize: 10.5, color: AppColors.textSecondary)),
          const SizedBox(height: 10),
          child,
        ]),
      );
}
