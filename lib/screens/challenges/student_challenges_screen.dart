import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../services/api_service.dart';

/// Student-facing Challenges — the actual justification for a paid plan.
/// Free challenges are open to everyone; paid ones show locked with an
/// upgrade prompt until the student has an active subscription.
class StudentChallengesScreen extends StatefulWidget {
  const StudentChallengesScreen({super.key});

  @override
  State<StudentChallengesScreen> createState() => _StudentChallengesScreenState();
}

class _StudentChallengesScreenState extends State<StudentChallengesScreen> {
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
      final data = await ApiService.getChallenges();
      if (!mounted) return;
      setState(() { _challenges = data; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text('Challenges', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
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
                        Text('No challenges live yet — check back soon',
                            style: GoogleFonts.inter(color: AppColors.textSecondary)),
                      ]),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: LayoutBuilder(
                        builder: (context, constraints) => GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 340,
                            mainAxisSpacing: 14,
                            crossAxisSpacing: 14,
                            mainAxisExtent: 220,
                          ),
                          itemCount: _challenges.length,
                          itemBuilder: (context, i) => _ChallengeCard(
                            challenge: _challenges[i] as Map<String, dynamic>,
                            onTap: () async {
                              final changed = await Navigator.push<bool>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChallengeDetailScreen(challengeId: _challenges[i]['id'] as int),
                                ),
                              );
                              if (changed == true) _load();
                            },
                          ),
                        ),
                      ),
                    ),
    );
  }
}

class _ChallengeCard extends StatelessWidget {
  final Map<String, dynamic> challenge;
  final VoidCallback onTap;
  const _ChallengeCard({required this.challenge, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final locked = challenge['locked'] == true;
    final stipend = (challenge['stipend_amount'] as num?) ?? 0;
    final submission = challenge['my_submission'] as Map<String, dynamic>?;
    final color = locked ? Colors.grey : AppColors.accent;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            height: 100,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, Color.lerp(color, Colors.black, 0.3)!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(clipBehavior: Clip.none, children: [
              Positioned(
                right: -16, bottom: -16,
                child: Icon(Icons.emoji_events_rounded, size: 90, color: Colors.white.withValues(alpha: 0.15)),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
                  Icon(locked ? Icons.lock_rounded : Icons.emoji_events_rounded, color: Colors.white, size: 22),
                  const SizedBox(height: 6),
                  Text(challenge['title'] ?? '',
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13.5)),
                ]),
              ),
            ]),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Wrap(spacing: 6, runSpacing: 4, children: [
                  _chip(locked ? 'PAID' : 'FREE', locked ? AppColors.accent : AppColors.success),
                  if (stipend > 0) _chip('₹${stipend.toStringAsFixed(0)}', AppColors.warning),
                ]),
                const Spacer(),
                if (submission != null)
                  Text(_statusLabel(submission['status']),
                      style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: _statusColor(submission['status'])))
                else
                  Text(locked ? 'Upgrade to unlock' : 'Tap to view',
                      style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.textSecondary)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  String _statusLabel(String? status) => switch (status) {
        'approved' => '✓ Approved',
        'rejected' => 'Not approved',
        _ => 'Submitted — under review',
      };

  Color _statusColor(String? status) => switch (status) {
        'approved' => AppColors.success,
        'rejected' => AppColors.error,
        _ => AppColors.warning,
      };

  Widget _chip(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
        child: Text(text, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
      );
}

class ChallengeDetailScreen extends StatefulWidget {
  final int challengeId;
  const ChallengeDetailScreen({super.key, required this.challengeId});

  @override
  State<ChallengeDetailScreen> createState() => _ChallengeDetailScreenState();
}

class _ChallengeDetailScreenState extends State<ChallengeDetailScreen> {
  Map<String, dynamic>? _challenge;
  bool _loading = true;
  String? _error;
  bool _submitting = false;
  bool _changed = false;

  final _nameCtrl = TextEditingController();
  final _textCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _textCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiService.getChallenge(widget.challengeId);
      if (!mounted) return;
      setState(() { _challenge = data; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _submit() async {
    if (_textCtrl.text.trim().isEmpty && _urlCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add a submission link or description')));
      return;
    }
    setState(() => _submitting = true);
    try {
      await ApiService.submitChallenge(
        widget.challengeId,
        name: _nameCtrl.text.trim(),
        submissionText: _textCtrl.text.trim(),
        submissionUrl: _urlCtrl.text.trim(),
      );
      _changed = true;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Submitted! Admin will review it soon.')));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {},
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          iconTheme: const IconThemeData(color: Colors.white),
          title: Text('Challenge', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
          leading: BackButton(onPressed: () => Navigator.pop(context, _changed)),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!, style: GoogleFonts.inter(color: AppColors.textSecondary)))
                : _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    final c = _challenge!;
    final locked = c['locked'] == true;
    final submission = c['my_submission'] as Map<String, dynamic>?;
    final stipend = (c['stipend_amount'] as num?) ?? 0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(spacing: 8, runSpacing: 8, children: [
          _badge(c['is_paid'] == true ? 'PAID' : 'FREE', c['is_paid'] == true ? AppColors.accent : AppColors.success),
          if ((c['category'] ?? '').toString().isNotEmpty) _badge(c['category'], AppColors.primary),
          _badge(c['difficulty'] ?? 'Medium', Colors.grey.shade600),
          if (stipend > 0) _badge('Earn ₹${stipend.toStringAsFixed(0)}', AppColors.warning),
          if (c['offers_certificate'] == true) _badge('Certificate on completion', Colors.teal),
        ]),
        const SizedBox(height: 14),
        Text(c['title'] ?? '', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 20)),
        if ((c['description'] ?? '').toString().isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(c['description'], style: GoogleFonts.inter(fontSize: 14, height: 1.5, color: AppColors.textPrimary)),
        ],
        if ((c['instructions'] ?? '').toString().isNotEmpty) ...[
          const SizedBox(height: 18),
          Text('How to submit', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14.5)),
          const SizedBox(height: 6),
          Text(c['instructions'], style: GoogleFonts.inter(fontSize: 13.5, height: 1.5, color: AppColors.textSecondary)),
        ],
        const SizedBox(height: 20),
        if (locked)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.accent.withValues(alpha: 0.25)),
            ),
            child: Column(children: [
              const Icon(Icons.lock_rounded, color: AppColors.accent, size: 28),
              const SizedBox(height: 10),
              Text('This challenge needs an active paid plan',
                  textAlign: TextAlign.center, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13.5)),
              const SizedBox(height: 4),
              Text('Upgrade to unlock this and every other paid challenge.',
                  textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 14),
              ElevatedButton(
                onPressed: () => Navigator.pushNamed(context, '/pricing'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
                child: Text('View Plans', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ]),
          )
        else if (submission != null)
          _submissionStatusCard(submission)
        else
          _submissionForm(),
      ],
    );
  }

  Widget _submissionStatusCard(Map<String, dynamic> submission) {
    final status = submission['status'] as String? ?? 'pending';
    final color = switch (status) { 'approved' => AppColors.success, 'rejected' => AppColors.error, _ => AppColors.warning };
    final label = switch (status) { 'approved' => 'Approved ✓', 'rejected' => 'Not approved', _ => 'Under review' };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withValues(alpha: 0.25))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.check_circle_outline_rounded, color: color, size: 20),
          const SizedBox(width: 8),
          Text('Your submission: $label', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: color, fontSize: 14)),
        ]),
        if ((submission['admin_feedback'] ?? '').toString().isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('Feedback: ${submission['admin_feedback']}', style: GoogleFonts.inter(fontSize: 13)),
        ],
        if (submission['stipend_paid'] == true) ...[
          const SizedBox(height: 6),
          Text('✓ Stipend paid', style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.success, fontWeight: FontWeight.w600)),
        ],
        if (submission['certificate_issued'] == true) ...[
          const SizedBox(height: 4),
          Text('✓ Certificate issued', style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.success, fontWeight: FontWeight.w600)),
        ],
      ]),
    );
  }

  Widget _submissionForm() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Submit your work', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14.5)),
      const SizedBox(height: 12),
      TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Your name')),
      const SizedBox(height: 12),
      TextField(controller: _urlCtrl, decoration: const InputDecoration(labelText: 'Link (GitHub, video, drive, etc.)')),
      const SizedBox(height: 12),
      TextField(controller: _textCtrl, maxLines: 4,
          decoration: const InputDecoration(labelText: 'Description (optional)', alignLabelWithHint: true)),
      const SizedBox(height: 16),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _submitting ? null : _submit,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 14)),
          child: _submitting
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text('Submit', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700)),
        ),
      ),
    ]);
  }

  Widget _badge(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
        child: Text(text.toString().toUpperCase(),
            style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
      );
}
