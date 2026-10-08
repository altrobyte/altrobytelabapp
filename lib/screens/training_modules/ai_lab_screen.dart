import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../services/api_service.dart';
import '../../widgets/html_frame.dart';

/// Where an educator switches the AI Lab on for a module: the assistant reads the module's notes and drafts a lab
/// (milestones checked by real checks, a wiring picture, a starter file, visuals); the educator reads it, edits it if
/// needed and publishes. Learners see the button only after that.
class AiLabScreen extends StatefulWidget {
  final int moduleId;
  final String title;
  const AiLabScreen({super.key, required this.moduleId, required this.title});

  @override
  State<AiLabScreen> createState() => _AiLabScreenState();
}

class _AiLabScreenState extends State<AiLabScreen> {
  Map<String, dynamic>? _lab;
  List<Map<String, dynamic>> _learners = [];
  String? _error;
  bool _busy = false;
  String _busyWhat = '';

  @override
  void initState() {
    super.initState();
    _run('Loading', () => ApiService.aiLabStatus(widget.moduleId));
    _loadProgress();
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

  Future<void> _run(String what, Future<Map<String, dynamic>> Function() call) async {
    setState(() {
      _busy = true;
      _busyWhat = what;
      _error = null;
    });
    try {
      final r = await call();
      if (!mounted) return;
      setState(() => _lab = r);
      final problems = (r['problems'] as List?) ?? const [];
      if (problems.isNotEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Check: ${problems.take(3).join('; ')}')));
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _editDraft() async {
    final draft = _lab?['draft'];
    if (draft == null) return;
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
      await _run('Saving', () => ApiService.aiLabSaveDraft(widget.moduleId, pkg));
    } on FormatException {
      if (mounted) setState(() => _error = 'That is not valid JSON.');
    }
  }

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

  Widget _preview(Map<String, dynamic> p) {
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
            Icon(m['how'] == 'learner confirms' ? Icons.person_rounded : Icons.verified_rounded, size: 16, color: AppColors.primary),
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
                if ('${l['phone']}'.isNotEmpty) Text('${l['phone']}', style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.textSecondary)),
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
              child: Text(
                  '${l['updated_at'] ?? ''}'.split('.').first.replaceFirst('T', ' ').split(' ').first,
                  textAlign: TextAlign.end,
                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
            ),
          ]),
        ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final lab = _lab;
    final enabled = lab?['enabled'] == true;
    final preview = lab?['draft_preview'] as Map?;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text('AI Lab: ${widget.title}', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: ListView(padding: const EdgeInsets.all(16), children: [
            _card(
              'Experiment with the AI Lab assistant',
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                    'The assistant reads this module\'s notes and drafts a hands-on lab from them. You read it, change what you want, and publish. '
                    'Learners then see "Start experimenting with Altrobyte AI Lab assistant" inside this module. The module itself is not changed.',
                    style: GoogleFonts.inter(height: 1.5, color: AppColors.textSecondary)),
                const SizedBox(height: 12),
                Row(children: [
                  ElevatedButton.icon(
                    onPressed: _busy ? null : () => _run('Reading the notes and drafting the lab (about a minute)', () => ApiService.aiLabGenerate(widget.moduleId)),
                    icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                    label: Text(lab?['draft'] == null ? 'Draft the lab from the notes' : 'Draft it again'),
                  ),
                  const SizedBox(width: 10),
                  if (lab?['draft'] != null) OutlinedButton(onPressed: _busy ? null : _editDraft, child: const Text('Edit draft')),
                ]),
                if (_busy) Padding(padding: const EdgeInsets.only(top: 12), child: Row(children: [const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)), const SizedBox(width: 10), Flexible(child: Text('$_busyWhat…'))])),
                if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: const TextStyle(color: AppColors.error))),
              ]),
            ),
            if (lab != null)
              _card(
                'For learners',
                Row(children: [
                  Expanded(
                    child: Text(
                        enabled ? 'On: learners can start the experiment from this module.' : (lab['has_live'] == true ? 'Off. The last published lab is kept.' : 'Off. Publish a draft to turn it on.'),
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: enabled ? AppColors.success : AppColors.textSecondary)),
                  ),
                  if (enabled)
                    OutlinedButton(onPressed: _busy ? null : () => _run('Turning off', () => ApiService.aiLabDisable(widget.moduleId)), child: const Text('Turn off'))
                  else
                    ElevatedButton(
                      onPressed: _busy || lab['draft'] == null ? null : () => _run('Publishing', () => ApiService.aiLabPublish(widget.moduleId)),
                      child: Text(lab['has_live'] == true ? 'Publish this draft and turn on' : 'Publish and turn on'),
                    ),
                ]),
              ),
            if (_learners.isNotEmpty) _card('Learners (${_learners.length})', _progressList()),
            if (preview != null) _card('Draft preview', _preview(Map<String, dynamic>.from(preview))),
          ]),
        ),
      ),
    );
  }
}
