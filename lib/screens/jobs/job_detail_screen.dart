import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../constants/app_colors.dart';
import '../../services/api_service.dart';

class JobDetailScreen extends StatefulWidget {
  final int jobId;
  const JobDetailScreen({super.key, required this.jobId});

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  Map<String, dynamic>? _job;
  bool _loading = true;
  bool _applied = false;
  bool _applying = false;
  String? _error;
  String? _applyError;

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _resumeCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _resumeCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final job = await ApiService.getJob(widget.jobId);
      bool applied = false;
      try {
        applied = await ApiService.hasAppliedToJob(widget.jobId);
      } catch (_) {}
      if (!mounted) return;
      setState(() { _job = job; _applied = applied; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _apply() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() { _applying = true; _applyError = null; });
    try {
      await ApiService.applyToJob(widget.jobId,
          name: _nameCtrl.text.trim(), phone: _phoneCtrl.text.trim(), email: _emailCtrl.text.trim(),
          resumeUrl: _resumeCtrl.text.trim(), coverNote: _noteCtrl.text.trim());
      if (!mounted) return;
      setState(() { _applied = true; _applying = false; });
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Application submitted!'), backgroundColor: AppColors.success));
    } catch (e) {
      if (!mounted) return;
      setState(() { _applying = false; _applyError = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null || _job == null) {
      return Scaffold(
        appBar: AppBar(leading: const BackButton()),
        body: Center(child: Text(_error ?? 'Listing not found')),
      );
    }
    final job = _job!;
    final hasLink = (job['link_url'] as String? ?? '').isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(job['title'] ?? '',
            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
            maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(job['title'] ?? '', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 19)),
            if ((job['company_name'] ?? '').isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(job['company_name'], style: GoogleFonts.inter(fontSize: 13.5, color: AppColors.textSecondary)),
            ],
            const SizedBox(height: 10),
            Wrap(spacing: 6, runSpacing: 6, children: [
              if ((job['domain'] ?? '').isNotEmpty) _tag(Icons.category_outlined, job['domain']),
              if ((job['location'] ?? '').isNotEmpty) _tag(Icons.location_on_outlined, job['location']),
              if ((job['experience_level'] ?? '').isNotEmpty) _tag(Icons.badge_outlined, job['experience_level']),
            ]),
            if ((job['description'] ?? '').isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(job['description'], style: GoogleFonts.inter(fontSize: 13.5, height: 1.5)),
            ],
            if (hasLink) ...[
              const SizedBox(height: 16),
              InkWell(
                onTap: () async {
                  final uri = Uri.parse(job['link_url']);
                  if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
                },
                child: Row(children: [
                  const Icon(Icons.open_in_new_rounded, size: 15, color: AppColors.accent),
                  const SizedBox(width: 6),
                  Text('View external listing', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.accent)),
                ]),
              ),
            ],
            const SizedBox(height: 20),
            _applyCard(),
          ]),
        ),
      ),
    );
  }

  Widget _tag(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(text, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
      ]),
    );
  }

  Widget _applyCard() {
    if (_applied) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          const Icon(Icons.check_circle_rounded, color: AppColors.success),
          const SizedBox(width: 10),
          Expanded(
            child: Text('Your application has been submitted',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppColors.success)),
          ),
        ]),
      );
    }
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Apply', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
            const SizedBox(height: 4),
            Text('Fields marked * are required',
                style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Name *', isDense: true),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _phoneCtrl,
              decoration: const InputDecoration(labelText: 'Phone *', isDense: true),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Phone is required' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _emailCtrl,
              decoration: const InputDecoration(labelText: 'Email', isDense: true),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _resumeCtrl,
              decoration: const InputDecoration(labelText: 'Resume link (Drive/Docs URL)', isDense: true),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _noteCtrl,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Cover note (optional)', alignLabelWithHint: true),
            ),
            if (_applyError != null) ...[
              const SizedBox(height: 10),
              Text(_applyError!, style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.error)),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _applying ? null : _apply,
                style: FilledButton.styleFrom(backgroundColor: AppColors.accent, padding: const EdgeInsets.symmetric(vertical: 13)),
                child: _applying
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text('Submit Application', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
