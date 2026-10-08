import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants/api_constants.dart';
import '../../constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

const publicBase = 'https://altrobytelab.com';

/// Enrolment forms: make a form, copy its link, see who filled it. People fill it after signing in with Google.
class EnrolmentFormsScreen extends StatefulWidget {
  const EnrolmentFormsScreen({super.key});

  @override
  State<EnrolmentFormsScreen> createState() => _EnrolmentFormsScreenState();
}

class _EnrolmentFormsScreenState extends State<EnrolmentFormsScreen> {
  List<Map<String, dynamic>> _forms = [];
  bool _loading = true;
  String? _error;

  int? get _instituteId => context.read<AuthProvider>().instituteId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final id = _instituteId;
    if (id == null) {
      setState(() {
        _loading = false;
        _error = 'Sign in as an institute admin to manage enrolment forms.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await ApiService.listEnrolmentForms(id);
      _forms = [for (final f in (r['forms'] as List? ?? const [])) Map<String, dynamic>.from(f as Map)];
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    }
    if (mounted) setState(() => _loading = false);
  }

  String _link(Map<String, dynamic> f) => '$publicBase/enroll/${f['slug']}';

  Future<void> _copy(Map<String, dynamic> f) async {
    await Clipboard.setData(ClipboardData(text: _link(f)));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Link copied: ${_link(f)}')));
  }

  Future<void> _edit([Map<String, dynamic>? form]) async {
    final saved = await showDialog<bool>(context: context, barrierDismissible: false, builder: (_) => _FormEditor(instituteId: _instituteId!, form: form));
    if (saved == true) _load();
  }

  Future<void> _delete(Map<String, dynamic> f) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete this form?'),
        content: Text('"${f['title']}" and its ${f['submissions']} response(s) will be deleted for good. The link will stop working.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white), onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiService.deleteEnrolmentForm(f['id'] as int);
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _toggleOpen(Map<String, dynamic> f, bool open) async {
    try {
      await ApiService.updateEnrolmentForm(f['id'] as int, {...f, 'is_open': open});
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text('Enrolment forms', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
        actions: [IconButton(tooltip: 'New form', icon: const Icon(Icons.add_rounded, color: Colors.white), onPressed: () => _edit())],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!)))
              : _forms.isEmpty
                  ? Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.assignment_rounded, size: 52, color: Colors.black26),
                        const SizedBox(height: 10),
                        Text('No forms yet', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        const Text('Make one, share its link, and people fill it after signing in with Google.'),
                        const SizedBox(height: 14),
                        ElevatedButton.icon(onPressed: () => _edit(), icon: const Icon(Icons.add_rounded), label: const Text('Make an enrolment form')),
                      ]),
                    )
                  : Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 900),
                        child: ListView(padding: const EdgeInsets.all(16), children: [for (final f in _forms) _card(f)]),
                      ),
                    ),
    );
  }

  Widget _card(Map<String, dynamic> f) {
    final open = f['is_open'] == true;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.black.withValues(alpha: 0.08))),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('${f['title']}', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15))),
            Text(open ? 'Open' : 'Closed', style: GoogleFonts.inter(color: open ? AppColors.success : AppColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 12)),
            Switch(value: open, onChanged: (v) => _toggleOpen(f, v)),
          ]),
          SelectableText(_link(f), style: GoogleFonts.robotoMono(fontSize: 12, color: AppColors.primary)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            ElevatedButton.icon(onPressed: () => _copy(f), icon: const Icon(Icons.link_rounded, size: 18), label: const Text('Copy link')),
            OutlinedButton.icon(onPressed: () => html.window.open(_link(f), '_blank'), icon: const Icon(Icons.open_in_new_rounded, size: 18), label: const Text('Open')),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _ResponsesScreen(form: f))),
              icon: const Icon(Icons.groups_rounded, size: 18),
              label: Text('Responses (${f['submissions']})'),
            ),
            OutlinedButton.icon(onPressed: () => _edit(f), icon: const Icon(Icons.edit_rounded, size: 18), label: const Text('Edit')),
            TextButton.icon(onPressed: () => _delete(f), icon: const Icon(Icons.delete_outline_rounded, size: 18), label: const Text('Delete')),
          ]),
        ]),
      ),
    );
  }
}

/// Create or edit a form: its words and its questions. Name, Google email and WhatsApp number are always asked.
class _FormEditor extends StatefulWidget {
  final int instituteId;
  final Map<String, dynamic>? form;
  const _FormEditor({required this.instituteId, this.form});

  @override
  State<_FormEditor> createState() => _FormEditorState();
}

class _QuestionRow {
  String? id;
  final label = TextEditingController();
  final options = TextEditingController();
  String type = 'text';
  bool required = false;
}

class _FormEditorState extends State<_FormEditor> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _thanks = TextEditingController();
  final List<_QuestionRow> _rows = [];
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final f = widget.form;
    if (f == null) {
      _title.text = 'Altrobyte enrolment';
      _desc.text = 'Fill this form to enrol. Sign in with Google first.';
      for (final (label, req) in [('City', true), ('College / company', false)]) {
        _rows.add(_QuestionRow()
          ..label.text = label
          ..required = req);
      }
    } else {
      _title.text = '${f['title']}';
      _desc.text = '${f['description'] ?? ''}';
      _thanks.text = '${f['success_message'] ?? ''}';
      for (final q in (f['fields'] as List? ?? const [])) {
        _rows.add(_QuestionRow()
          ..id = q['id'] as String?
          ..label.text = '${q['label']}'
          ..type = '${q['type']}'
          ..required = q['required'] == true
          ..options.text = ((q['options'] as List?) ?? const []).join(', '));
      }
    }
  }

  Future<void> _save() async {
    final body = {
      'title': _title.text.trim(),
      'description': _desc.text.trim(),
      'success_message': _thanks.text.trim(),
      'is_open': widget.form?['is_open'] ?? true,
      'fields': [
        for (final r in _rows)
          if (r.label.text.trim().isNotEmpty)
            {
              if (r.id != null) 'id': r.id,
              'label': r.label.text.trim(),
              'type': r.type,
              'required': r.required,
              'options': r.type == 'choice' ? r.options.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList() : [],
            }
      ],
    };
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (widget.form == null) {
        await ApiService.createEnrolmentForm(widget.instituteId, body);
      } else {
        await ApiService.updateEnrolmentForm(widget.form!['id'] as int, body);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _busy = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.form == null ? 'New enrolment form' : 'Edit form'),
      content: SizedBox(
        width: 640,
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextField(controller: _title, decoration: const InputDecoration(labelText: 'Form title')),
            const SizedBox(height: 10),
            TextField(controller: _desc, maxLines: 3, decoration: const InputDecoration(labelText: 'Short description (shown above the form)')),
            const SizedBox(height: 10),
            TextField(controller: _thanks, maxLines: 2, decoration: const InputDecoration(labelText: 'Message after submitting (optional)')),
            const SizedBox(height: 16),
            Text('Always asked: name and email (from Google) and WhatsApp number.', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Text('Your questions', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            for (var i = 0; i < _rows.length; i++) _row(i),
            TextButton.icon(onPressed: () => setState(() => _rows.add(_QuestionRow())), icon: const Icon(Icons.add_rounded), label: const Text('Add a question')),
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: const TextStyle(color: AppColors.error))),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context, false), child: const Text('Cancel')),
        ElevatedButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'Saving…' : 'Save')),
      ],
    );
  }

  Widget _row(int i) {
    final r = _rows[i];
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(children: [
        Row(children: [
          Expanded(flex: 3, child: TextField(controller: r.label, decoration: const InputDecoration(labelText: 'Question', isDense: true))),
          const SizedBox(width: 8),
          DropdownButton<String>(
            value: r.type,
            items: const [
              DropdownMenuItem(value: 'text', child: Text('Short answer')),
              DropdownMenuItem(value: 'long', child: Text('Long answer')),
              DropdownMenuItem(value: 'choice', child: Text('Choose one')),
            ],
            onChanged: (v) => setState(() => r.type = v ?? 'text'),
          ),
          const SizedBox(width: 6),
          Checkbox(value: r.required, onChanged: (v) => setState(() => r.required = v == true)),
          const Text('Required'),
          IconButton(tooltip: 'Remove', icon: const Icon(Icons.close_rounded), onPressed: () => setState(() => _rows.removeAt(i))),
        ]),
        if (r.type == 'choice')
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: TextField(controller: r.options, decoration: const InputDecoration(labelText: 'Choices, separated by commas', isDense: true)),
          ),
      ]),
    );
  }
}

/// Who filled the form, with a CSV download.
class _ResponsesScreen extends StatefulWidget {
  final Map<String, dynamic> form;
  const _ResponsesScreen({required this.form});

  @override
  State<_ResponsesScreen> createState() => _ResponsesScreenState();
}

class _ResponsesScreenState extends State<_ResponsesScreen> {
  List<Map<String, dynamic>> _rows = [];
  List<Map<String, dynamic>> _fields = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    () async {
      try {
        final r = await ApiService.enrolmentSubmissions(widget.form['id'] as int);
        _rows = [for (final s in (r['submissions'] as List? ?? const [])) Map<String, dynamic>.from(s as Map)];
        _fields = [for (final f in ((r['form'] as Map)['fields'] as List? ?? const [])) Map<String, dynamic>.from(f as Map)];
      } catch (e) {
        _error = e.toString().replaceFirst('Exception: ', '');
      }
      if (mounted) setState(() => _loading = false);
    }();
  }

  Future<void> _download() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final res = await http.get(Uri.parse('${ApiConstants.baseUrl}/enrolment-forms/${widget.form['id']}/submissions/export'),
        headers: {if (token != null) 'Authorization': 'Bearer $token'});
    if (res.statusCode != 200) return;
    final blob = html.Blob([utf8.encode(res.body)], 'text/csv');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', 'enrolments_${widget.form['id']}.csv')
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
        title: Text('${widget.form['title']}: responses', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
        actions: [TextButton.icon(onPressed: _rows.isEmpty ? null : _download, icon: const Icon(Icons.download_rounded, color: Colors.white), label: const Text('CSV', style: TextStyle(color: Colors.white)))],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _rows.isEmpty
                  ? const Center(child: Text('Nobody has filled this form yet.'))
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: DataTable(
                          columns: [
                            const DataColumn(label: Text('Name')),
                            const DataColumn(label: Text('Google email')),
                            const DataColumn(label: Text('WhatsApp')),
                            for (final f in _fields) DataColumn(label: Text('${f['label']}')),
                            const DataColumn(label: Text('Submitted')),
                          ],
                          rows: [
                            for (final r in _rows)
                              DataRow(cells: [
                                DataCell(SelectableText('${r['name']}')),
                                DataCell(SelectableText('${r['email']}')),
                                DataCell(SelectableText('${r['phone']}')),
                                for (final f in _fields) DataCell(SizedBox(width: 220, child: Text('${(r['answers'] as Map)[f['id']] ?? ''}', overflow: TextOverflow.ellipsis))),
                                DataCell(Text('${r['submitted_at'] ?? ''}'.split('.').first.replaceFirst('T', ' '))),
                              ]),
                          ],
                        ),
                      ),
                    ),
    );
  }
}
