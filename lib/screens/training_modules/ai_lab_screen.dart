import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../services/api_service.dart';
import '../../widgets/html_frame.dart';

/// Where an educator makes the hands-on experiments of a module. A module can have several (the Industrial IoT module has
/// Wi-Fi, BLE, OTA, AWS...), so each experiment is made from the note(s) the educator picks: the assistant reads only those,
/// drafts a lab (milestones checked by real checks, a wiring picture, a starter file, visuals), the educator reads it,
/// changes what they want, and turns it on. Learners then see it inside the module.
class AiLabScreen extends StatefulWidget {
  final int moduleId;
  final String title;
  const AiLabScreen({super.key, required this.moduleId, required this.title});

  @override
  State<AiLabScreen> createState() => _AiLabScreenState();
}

class _AiLabScreenState extends State<AiLabScreen> {
  List<Map<String, dynamic>> _notes = [];
  List<Map<String, dynamic>> _labs = [];
  final Set<int> _picked = {};
  Map<String, dynamic>? _open; // one lab in full, fetched only when asked for
  List<Map<String, dynamic>> _learners = [];
  String? _error;
  bool _busy = false;
  String _busyWhat = '';

  @override
  void initState() {
    super.initState();
    _load(first: true);
    _loadProgress();
  }

  Future<void> _load({bool first = false}) async {
    await _run('Loading', () async {
      final r = await ApiService.aiLabStatus(widget.moduleId);
      _notes = [for (final n in (r['notes'] as List? ?? const [])) Map<String, dynamic>.from(n as Map)];
      _labs = [for (final l in (r['labs'] as List? ?? const [])) Map<String, dynamic>.from(l as Map)];
      if (first && _picked.isEmpty) {
        final s = _notes.where((n) => n['suggested'] == true);
        if (s.isNotEmpty) _picked.add((s.first['id'] as num).toInt());
      }
    });
  }

  Future<void> _loadProgress() async {
    try {
      final r = await ApiService.aiLabProgress(widget.moduleId);
      _learners = [for (final l in (r['learners'] as List? ?? const [])) Map<String, dynamic>.from(l as Map)];
    } catch (_) {
      _learners = [];
    }
    if (mounted) setState(() {});
  }

  Future<void> _run(String what, Future<void> Function() call) async {
    setState(() {
      _busy = true;
      _busyWhat = what;
      _error = null;
    });
    try {
      await call();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    }
    if (mounted) setState(() => _busy = false);
  }

  void _warn(Map<String, dynamic> r) {
    final problems = (r['problems'] as List?) ?? const [];
    if (problems.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Check: ${problems.take(3).join('; ')}')));
    }
  }

  Future<void> _generate() => _run('Reading the notes and drafting the lab (about a minute)', () async {
        final r = await ApiService.aiLabGenerate(widget.moduleId, _picked.toList());
        _warn(r);
        _open = r;
        final status = await ApiService.aiLabStatus(widget.moduleId);
        _labs = [for (final l in (status['labs'] as List? ?? const [])) Map<String, dynamic>.from(l as Map)];
      });

  Future<void> _openLab(int labId) => _run('Opening', () async {
        _open = await ApiService.aiLabDetail(widget.moduleId, labId);
      });

  Future<void> _act(String what, Future<Map<String, dynamic>> Function() call) => _run(what, () async {
        final r = await call();
        if (_open != null && _open!['id'] == r['id']) _open = r;
        final status = await ApiService.aiLabStatus(widget.moduleId);
        _labs = [for (final l in (status['labs'] as List? ?? const [])) Map<String, dynamic>.from(l as Map)];
      });

  Future<void> _delete(Map<String, dynamic> l) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete this experiment?'),
        content: Text('"${l['title']}" will be removed for learners and its draft is lost.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white), onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    await _run('Deleting', () async {
      await ApiService.aiLabDelete(widget.moduleId, (l['id'] as num).toInt());
      if (_open != null && _open!['id'] == l['id']) _open = null;
      final status = await ApiService.aiLabStatus(widget.moduleId);
      _labs = [for (final x in (status['labs'] as List? ?? const [])) Map<String, dynamic>.from(x as Map)];
    });
  }

  Future<void> _editDraft() async {
    final lab = _open;
    final draft = lab?['draft'];
    if (lab == null || draft == null) return;
    final ctl = TextEditingController(text: const JsonEncoder.withIndent('  ').convert(draft));
    final saved = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Edit the draft (advanced)'),
        content: SizedBox(
          width: 760,
          child: TextField(controller: ctl, maxLines: 24, style: GoogleFonts.robotoMono(fontSize: 12), decoration: const InputDecoration(border: OutlineInputBorder())),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text('Save draft')),
        ],
      ),
    );
    if (saved != true) return;
    try {
      final pkg = jsonDecode(ctl.text) as Map<String, dynamic>;
      await _act('Saving', () async {
        final r = await ApiService.aiLabSaveDraft(widget.moduleId, (lab['id'] as num).toInt(), pkg);
        _warn(r);
        return r;
      });
    } on FormatException {
      if (mounted) setState(() => _error = 'That is not valid JSON.');
    }
  }

  // ── widgets ────────────────────────────────────────────────────────────────

  Widget _card(String title, Widget child) => Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.black.withValues(alpha: 0.08))),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
            const SizedBox(height: 10),
            child,
          ]),
        ),
      );

  Widget _chip(String text, Color color) => Container(
        margin: const EdgeInsets.only(left: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
      );

  Widget _notesPicker() {
    if (_notes.isEmpty) return Text('This module has no notes yet. Add the notes first.', style: GoogleFonts.inter(color: AppColors.textSecondary));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(
          'Pick the note this experiment is about (up to 3 that belong together). The assistant reads only these, so a module with many '
          'notes gets a separate experiment for each hands-on one.',
          style: GoogleFonts.inter(height: 1.5, color: AppColors.textSecondary, fontSize: 12.5)),
      const SizedBox(height: 6),
      for (final n in _notes)
        CheckboxListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: _picked.contains((n['id'] as num).toInt()),
          onChanged: _busy
              ? null
              : (v) => setState(() {
                    final id = (n['id'] as num).toInt();
                    v == true ? _picked.add(id) : _picked.remove(id);
                  }),
          title: Row(children: [
            Flexible(child: Text('${n['title']}', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600))),
            if ((n['hands_on'] as num) > 0) _chip(n['suggested'] == true ? 'HANDS-ON · SUGGESTED' : 'HANDS-ON', AppColors.success),
          ]),
          subtitle: Text('${n['topic']} · ${((n['chars'] as num) / 1000).toStringAsFixed(1)}k characters', style: GoogleFonts.inter(fontSize: 11.5)),
        ),
      const SizedBox(height: 10),
      ElevatedButton.icon(
        onPressed: _busy || _picked.isEmpty || _picked.length > 3 ? null : _generate,
        icon: const Icon(Icons.auto_awesome_rounded, size: 18),
        label: Text(_picked.length > 3 ? 'Pick at most 3 notes' : 'Draft a lab from the selected note${_picked.length == 1 ? '' : 's'}'),
      ),
    ]);
  }

  Widget _labList() {
    return Column(children: [
      for (final l in _labs)
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _open != null && _open!['id'] == l['id'] ? const Color(0xFFF1F5FF) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
          ),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(child: Text('${l['title']}', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13.5))),
                  if (l['enabled'] == true) _chip('ON FOR LEARNERS', AppColors.success) else if (l['has_live'] == true) _chip('OFF', AppColors.textSecondary) else _chip('DRAFT', AppColors.warning),
                ]),
                if ((l['source_notes'] as List? ?? const []).isNotEmpty)
                  Text('From: ${(l['source_notes'] as List).join(', ')}', style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.textSecondary)),
              ]),
            ),
            TextButton(onPressed: _busy ? null : () => _openLab((l['id'] as num).toInt()), child: const Text('Open')),
            if (l['enabled'] == true)
              TextButton(onPressed: _busy ? null : () => _act('Turning off', () => ApiService.aiLabDisable(widget.moduleId, (l['id'] as num).toInt())), child: const Text('Turn off'))
            else if (l['has_live'] == true)
              TextButton(onPressed: _busy ? null : () => _act('Turning on', () => ApiService.aiLabPublish(widget.moduleId, (l['id'] as num).toInt())), child: const Text('Turn on')),
            IconButton(tooltip: 'Delete', onPressed: _busy ? null : () => _delete(l), icon: const Icon(Icons.delete_outline_rounded, size: 20)),
          ]),
        ),
    ]);
  }

  Widget _preview(Map<String, dynamic> lab) {
    final p = Map<String, dynamic>.from((lab['draft_preview'] as Map?) ?? const {});
    if (p.isEmpty) return Text('No draft yet.', style: GoogleFonts.inter(color: AppColors.textSecondary));
    final milestones = (p['milestones'] as List? ?? const []).cast<Map>();
    final visuals = (p['visuals'] as List? ?? const []).cast<Map>();
    final starter = p['starter'] as Map?;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('${p['title'] ?? ''}', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      Text('${p['goal'] ?? ''}', style: GoogleFonts.inter(color: AppColors.textSecondary)),
      const SizedBox(height: 12),
      Text('What the assistant will check', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13)),
      for (final m in milestones)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(children: [
            Icon(
                m['how'] == 'learner confirms'
                    ? Icons.person_rounded
                    : (m['how'] == 'quiz question' ? Icons.quiz_rounded : Icons.verified_rounded),
                size: 16,
                color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(child: Text('${m['title']}', style: GoogleFonts.inter(fontSize: 13))),
            Text('${m['how']}', style: GoogleFonts.robotoMono(fontSize: 11, color: AppColors.textSecondary)),
          ]),
        ),
      if (p['wiring_svg'] != null) ...[
        const SizedBox(height: 14),
        Text('Wiring picture', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13)),
        const SizedBox(height: 6),
        HtmlFrame(body: '${p['wiring_svg']}', height: 360),
      ],
      if (starter != null) ...[
        const SizedBox(height: 14),
        Text('Starter file: ${starter['path']}', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13)),
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 6),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(8)),
          child: SelectableText('${starter['code']}', style: GoogleFonts.robotoMono(fontSize: 12, color: const Color(0xFFD4D4D4))),
        ),
      ],
      if (visuals.isNotEmpty) ...[
        const SizedBox(height: 14),
        Text('Visuals (${visuals.length})', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13)),
        for (final v in visuals) ...[
          const SizedBox(height: 8),
          Text('${v['title']}', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600)),
          HtmlFrame(body: '${v['html']}', height: 280),
        ],
      ],
      const SizedBox(height: 14),
      Row(children: [
        OutlinedButton(onPressed: _busy ? null : _editDraft, child: const Text('Edit draft')),
        const SizedBox(width: 10),
        ElevatedButton(
          onPressed: _busy ? null : () => _act('Publishing', () => ApiService.aiLabPublish(widget.moduleId, (lab['id'] as num).toInt())),
          child: Text(lab['enabled'] == true ? 'Publish this draft (replaces the live one)' : 'Publish and turn on'),
        ),
      ]),
    ]);
  }

  Widget _progressList() {
    return Column(children: [
      for (final l in _learners)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            Expanded(
              flex: 3,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${l['learner']}', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                Text([if ('${l['lab'] ?? ''}'.isNotEmpty) '${l['lab']}', if ('${l['phone']}'.isNotEmpty) '${l['phone']}'].join(' · '),
                    style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.textSecondary)),
              ]),
            ),
            Expanded(
              flex: 3,
              child: LinearProgressIndicator(
                value: (l['total'] as num) > 0 ? (l['done'] as num) / (l['total'] as num) : 0,
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
                color: l['finished'] == true ? AppColors.success : AppColors.primary,
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(width: 56, child: Text('${l['done']}/${l['total']}', textAlign: TextAlign.end, style: GoogleFonts.robotoMono(fontSize: 12))),
            SizedBox(
              width: 92,
              child: Text('${l['updated_at'] ?? ''}'.split('T').first, textAlign: TextAlign.end, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
            ),
          ]),
        ),
    ]);
  }

  /// Asks the server whether each AI model answers right now, and shows the real reason when one does not.
  Future<void> _checkAi() async {
    showDialog(context: context, barrierDismissible: false, builder: (_) => const AlertDialog(content: Row(children: [CircularProgressIndicator(), SizedBox(width: 16), Text('Asking each model…')])));
    String text;
    try {
      final r = await ApiService.trainerDiagnose();
      String line(String name) {
        final m = (r[name] as Map?) ?? const {};
        String one(String k) {
          final x = (m[k] as Map?) ?? const {};
          return x['ok'] == true ? 'OK' : 'FAILED: ${x['error'] ?? 'no answer'}';
        }

        return '$name\n  plain question: ${one('plain')}\n  with the trainer\'s tools: ${one('with_tools')}';
      }

      // The tutor's natural voice (made in the cloud once per sentence, then reused).
      String speech() {
        final sp = (r['speech'] as Map?) ?? const {};
        if (sp['error'] != null) return 'natural voice\n  FAILED: ${sp['error']}';
        String one(String lang, String label) {
          final x = (sp[lang] as Map?) ?? const {};
          return x['ok'] == true ? '$label: OK (voice ${x['voice']}, model ${x['model']})' : '$label: FAILED: ${x['error'] ?? 'no answer'}';
        }

        return 'natural voice\n  ${one('en', 'Indian English')}\n  ${one('hi', 'Hindi')}';
      }

      text = 'Trainer uses: ${r['provider']} (backup: ${r['fallback']})\n'
          'Groq key: ${r['groq_key'] == true ? 'set' : 'MISSING'}   Gemini key: ${r['gemini_key'] == true ? 'set' : 'MISSING'}\n'
          'Gemini model: ${r['gemini_model']}   Groq model: ${r['trainer_model']}\n\n${line('groq')}\n\n${line('gemini')}\n\n${speech()}';
    } catch (e) {
      text = 'Could not run the check: $e';
    }
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    showDialog(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('AI models right now'),
        content: SizedBox(width: 560, child: SingleChildScrollView(child: SelectableText(text, style: GoogleFonts.robotoMono(fontSize: 12.5, height: 1.5)))),
        actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('Close'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final open = _open;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('AI Lab: ${widget.title}', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16)),
        actions: [TextButton.icon(onPressed: _checkAi, icon: const Icon(Icons.monitor_heart_outlined, size: 18), label: const Text('Check AI'))],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: ListView(padding: const EdgeInsets.all(16), children: [
            if (_busy)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(children: [const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)), const SizedBox(width: 10), Flexible(child: Text('$_busyWhat…'))]),
              ),
            if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(_error!, style: const TextStyle(color: AppColors.error))),
            _card('Make an experiment from a note', _notesPicker()),
            if (_labs.isNotEmpty) _card('Experiments in this module (${_labs.length})', _labList()),
            if (open != null) _card('Draft: ${open['title']}', _preview(open)),
            if (_learners.isNotEmpty) _card('Learners (${_learners.length})', _progressList()),
          ]),
        ),
      ),
    );
  }
}
