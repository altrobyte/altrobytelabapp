import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../constants/app_colors.dart';
import '../../services/api_service.dart';

/// Admin management for Challenges — create/edit/publish challenges, review
/// submissions, and mark stipend/certificate status. Payout itself stays
/// manual (off-platform) — this only tracks whether it's been done.
class ChallengesAdminScreen extends StatefulWidget {
  const ChallengesAdminScreen({super.key});

  @override
  State<ChallengesAdminScreen> createState() => _ChallengesAdminScreenState();
}

class _ChallengesAdminScreenState extends State<ChallengesAdminScreen> {
  List<dynamic> _challenges = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiService.getChallengesAdmin();
      if (!mounted) return;
      setState(() { _challenges = data; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _openForm({Map<String, dynamic>? existing}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (_) => _ChallengeFormSheet(existing: existing),
    );
    if (saved == true) _load();
  }

  Future<void> _togglePublish(Map<String, dynamic> c) async {
    try {
      await ApiService.updateChallenge(c['id'] as int, {'is_published': !(c['is_published'] == true)});
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _delete(Map<String, dynamic> c) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete challenge?'),
        content: Text('This removes "${c['title']}" and all its submissions permanently.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ApiService.deleteChallenge(c['id'] as int);
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  void _openSubmissions(Map<String, dynamic> c) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        expand: false,
        builder: (ctx, scrollCtrl) => _SubmissionsSheet(challenge: c, scrollController: scrollCtrl),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text('Challenges', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
        actions: [IconButton(icon: const Icon(Icons.refresh_rounded, color: Colors.white), onPressed: _load)],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        backgroundColor: AppColors.accent,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('New Challenge', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: GoogleFonts.inter(color: AppColors.textSecondary)))
              : _challenges.isEmpty
                  ? Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.emoji_events_outlined, size: 48, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text('No challenges yet', style: GoogleFonts.inter(color: AppColors.textSecondary)),
                      ]),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                        itemCount: _challenges.length,
                        itemBuilder: (context, i) {
                          final c = _challenges[i] as Map<String, dynamic>;
                          final isPaid = c['is_paid'] == true;
                          final isPublished = c['is_published'] == true;
                          final stipend = (c['stipend_amount'] as num?) ?? 0;
                          final submissionCount = c['submission_count'] ?? 0;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(children: [
                                  Expanded(
                                    child: Text(c['title'] ?? '',
                                        style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15)),
                                  ),
                                  Switch(
                                    value: isPublished,
                                    onChanged: (_) => _togglePublish(c),
                                    activeThumbColor: AppColors.success,
                                  ),
                                ]),
                                const SizedBox(height: 4),
                                Wrap(spacing: 6, runSpacing: 6, children: [
                                  _badge(isPaid ? 'PAID' : 'FREE', isPaid ? AppColors.accent : AppColors.success),
                                  if (c['category'] != null && (c['category'] as String).isNotEmpty)
                                    _badge(c['category'], AppColors.primary),
                                  _badge(c['difficulty'] ?? 'Medium', Colors.grey.shade600),
                                  if (stipend > 0) _badge('₹${stipend.toStringAsFixed(0)} stipend', AppColors.warning),
                                  if (c['offers_certificate'] == true) _badge('Certificate', Colors.teal),
                                ]),
                                const SizedBox(height: 10),
                                Row(children: [
                                  TextButton.icon(
                                    onPressed: () => _openSubmissions(c),
                                    icon: const Icon(Icons.assignment_rounded, size: 16),
                                    label: Text('$submissionCount submission${submissionCount == 1 ? '' : 's'}'),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 20),
                                    onPressed: () => _openForm(existing: c),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.error),
                                    onPressed: () => _delete(c),
                                  ),
                                ]),
                              ]),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }

  Widget _badge(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
        child: Text(text.toString().toUpperCase(),
            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
      );
}

class _ChallengeFormSheet extends StatefulWidget {
  final Map<String, dynamic>? existing;
  const _ChallengeFormSheet({this.existing});

  @override
  State<_ChallengeFormSheet> createState() => _ChallengeFormSheetState();
}

class _ChallengeFormSheetState extends State<_ChallengeFormSheet> {
  late final _titleCtrl = TextEditingController(text: widget.existing?['title'] ?? '');
  late final _descCtrl = TextEditingController(text: widget.existing?['description'] ?? '');
  late final _instructionsCtrl = TextEditingController(text: widget.existing?['instructions'] ?? '');
  late final _categoryCtrl = TextEditingController(text: widget.existing?['category'] ?? '');
  late final _bannerCtrl = TextEditingController(text: widget.existing?['banner_url'] ?? '');
  late final _stipendCtrl = TextEditingController(
      text: widget.existing != null ? ((widget.existing!['stipend_amount'] as num?) ?? 0).toStringAsFixed(0) : '0');
  late String _difficulty = widget.existing?['difficulty'] ?? 'Medium';
  late bool _isPaid = widget.existing?['is_paid'] == true;
  late bool _offersCertificate = widget.existing?['offers_certificate'] != false;
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _instructionsCtrl.dispose();
    _categoryCtrl.dispose();
    _bannerCtrl.dispose();
    _stipendCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Title is required')));
      return;
    }
    setState(() => _saving = true);
    final body = {
      'title': _titleCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'instructions': _instructionsCtrl.text.trim(),
      'category': _categoryCtrl.text.trim(),
      'difficulty': _difficulty,
      'banner_url': _bannerCtrl.text.trim(),
      'is_paid': _isPaid,
      'stipend_amount': double.tryParse(_stipendCtrl.text.trim()) ?? 0,
      'offers_certificate': _offersCertificate,
    };
    try {
      if (widget.existing != null) {
        await ApiService.updateChallenge(widget.existing!['id'] as int, body);
      } else {
        await ApiService.createChallenge(body);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
        expand: false,
        builder: (ctx, scrollCtrl) => ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.all(20),
          children: [
            Text(widget.existing != null ? 'Edit Challenge' : 'New Challenge',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 18)),
            const SizedBox(height: 16),
            TextField(controller: _titleCtrl, decoration: const InputDecoration(labelText: 'Title')),
            const SizedBox(height: 12),
            TextField(controller: _descCtrl, maxLines: 3,
                decoration: const InputDecoration(labelText: 'Description', alignLabelWithHint: true)),
            const SizedBox(height: 12),
            TextField(controller: _instructionsCtrl, maxLines: 4,
                decoration: const InputDecoration(
                    labelText: 'Submission instructions', alignLabelWithHint: true,
                    hintText: 'e.g. Submit a GitHub repo link + demo video')),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextField(controller: _categoryCtrl, decoration: const InputDecoration(labelText: 'Category'))),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _difficulty,
                  decoration: const InputDecoration(labelText: 'Difficulty'),
                  items: ['Easy', 'Medium', 'Hard'].map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                  onChanged: (v) => setState(() => _difficulty = v ?? 'Medium'),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            TextField(controller: _bannerCtrl, decoration: const InputDecoration(labelText: 'Banner image URL (optional)')),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Paid (requires an active subscription)'),
              value: _isPaid,
              onChanged: (v) => setState(() => _isPaid = v),
            ),
            if (_isPaid)
              TextField(
                controller: _stipendCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Stipend amount (₹, 0 for none)'),
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Offers a certificate on completion'),
              value: _offersCertificate,
              onChanged: (v) => setState(() => _offersCertificate = v),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 14)),
                child: _saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text('Save', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubmissionsSheet extends StatefulWidget {
  final Map<String, dynamic> challenge;
  final ScrollController scrollController;
  const _SubmissionsSheet({required this.challenge, required this.scrollController});

  @override
  State<_SubmissionsSheet> createState() => _SubmissionsSheetState();
}

class _SubmissionsSheetState extends State<_SubmissionsSheet> {
  List<dynamic> _submissions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await ApiService.getChallengeSubmissionsAdmin(widget.challenge['id'] as int);
      if (!mounted) return;
      setState(() { _submissions = data; _loading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Submissions — ${widget.challenge['title']}',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 12),
              Expanded(
                child: _submissions.isEmpty
                    ? Center(child: Text('No submissions yet', style: GoogleFonts.inter(color: AppColors.textSecondary)))
                    : ListView.builder(
                        controller: widget.scrollController,
                        itemCount: _submissions.length,
                        itemBuilder: (context, i) => _SubmissionTile(
                          submission: _submissions[i] as Map<String, dynamic>,
                          onChanged: _load,
                        ),
                      ),
              ),
            ]),
    );
  }
}

class _SubmissionTile extends StatefulWidget {
  final Map<String, dynamic> submission;
  final VoidCallback onChanged;
  const _SubmissionTile({required this.submission, required this.onChanged});

  @override
  State<_SubmissionTile> createState() => _SubmissionTileState();
}

class _SubmissionTileState extends State<_SubmissionTile> {
  late String _status = widget.submission['status'] ?? 'pending';
  late bool _stipendPaid = widget.submission['stipend_paid'] == true;
  late bool _certIssued = widget.submission['certificate_issued'] == true;
  late final _feedbackCtrl = TextEditingController(text: widget.submission['admin_feedback'] ?? '');
  bool _saving = false;
  bool _expanded = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ApiService.reviewChallengeSubmission(widget.submission['id'] as int, {
        'status': _status,
        'admin_feedback': _feedbackCtrl.text.trim(),
        'stipend_paid': _stipendPaid,
        'certificate_issued': _certIssued,
      });
      widget.onChanged();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Color get _statusColor => switch (_status) {
        'approved' => AppColors.success,
        'rejected' => AppColors.error,
        _ => AppColors.warning,
      };

  @override
  Widget build(BuildContext context) {
    final s = widget.submission;
    String? submittedAt;
    try {
      submittedAt = DateFormat('d MMM, h:mm a').format(DateTime.parse(s['submitted_at']));
    } catch (_) {}

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(children: [
        ListTile(
          onTap: () => setState(() => _expanded = !_expanded),
          title: Text(s['name'] ?? '', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13.5)),
          subtitle: Text('${s['phone'] ?? ''}  ·  ${s['email'] ?? ''}',
              style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.textSecondary)),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: _statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
            child: Text(_status.toUpperCase(),
                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: _statusColor)),
          ),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (submittedAt != null)
                Text('Submitted $submittedAt', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
              if ((s['submission_text'] ?? '').toString().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(s['submission_text'], style: GoogleFonts.inter(fontSize: 13)),
              ],
              if ((s['submission_url'] ?? '').toString().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(s['submission_url'], style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.primary)),
              ],
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(labelText: 'Status', isDense: true),
                items: const [
                  DropdownMenuItem(value: 'pending', child: Text('Pending')),
                  DropdownMenuItem(value: 'approved', child: Text('Approved')),
                  DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                ],
                onChanged: (v) => setState(() => _status = v ?? 'pending'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _feedbackCtrl,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Feedback (optional)', isDense: true),
              ),
              const SizedBox(height: 6),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('Stipend paid'),
                value: _stipendPaid,
                onChanged: (v) => setState(() => _stipendPaid = v ?? false),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('Certificate issued'),
                value: _certIssued,
                onChanged: (v) => setState(() => _certIssued = v ?? false),
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Save'),
                ),
              ),
            ]),
          ),
      ]),
    );
  }
}
