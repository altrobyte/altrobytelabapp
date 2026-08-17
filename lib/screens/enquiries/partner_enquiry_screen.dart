import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../constants/app_colors.dart';
import '../../services/api_service.dart';

/// Public "Partner With Us" lead-capture form for prospective
/// institutions. AltrobyteLab is single-tenant — this does not create
/// an account, it just queues a lead for manual follow-up.
class PartnerEnquiryScreen extends StatefulWidget {
  const PartnerEnquiryScreen({super.key});

  @override
  State<PartnerEnquiryScreen> createState() => _PartnerEnquiryScreenState();
}

class _PartnerEnquiryScreenState extends State<PartnerEnquiryScreen> {
  /// From settings, not written in here — the enquiry number lives in one
  /// place so changing it does not mean hunting through screens.
  String _waNumber = '';

  final _nameCtrl = TextEditingController();
  final _orgCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _countCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  bool _submitting = false;
  bool _submitted = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _orgCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _countCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadNumber();
  }

  Future<void> _loadNumber() async {
    try {
      final r = await ApiService.getRoadmap('product-engineering');
      final n = r['whatsapp_number'] as String? ?? '';
      if (mounted) setState(() => _waNumber = n);
    } catch (_) {}
  }

  /// Whatever the form already has goes into the message, so someone who
  /// typed their college name and then chose WhatsApp does not type it again.
  Future<void> _whatsapp() async {
    if (_waNumber.isEmpty) return;
    final org = _orgCtrl.text.trim();
    final name = _nameCtrl.text.trim();
    final count = _countCtrl.text.trim();
    final lines = [
      'Hi! I would like to bring Altrobyte Lab to my institution.',
      if (name.isNotEmpty) 'Name: $name',
      if (org.isNotEmpty) 'Institution: $org',
      if (count.isNotEmpty) 'Approx. students: $count',
    ];
    final body = Uri.encodeComponent(lines.join('\n'));
    final uri = Uri.parse('https://wa.me/$_waNumber?text=$body');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open WhatsApp')));
    }
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter your name'), backgroundColor: AppColors.error));
      return;
    }
    if (_emailCtrl.text.trim().isEmpty && _phoneCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Enter an email or phone so we can follow up'), backgroundColor: AppColors.error));
      return;
    }
    setState(() => _submitting = true);
    try {
      await ApiService.submitEnquiry({
        'contact_name': _nameCtrl.text.trim(),
        'organization_name': _orgCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'student_count': _countCtrl.text.trim(),
        'message': _messageCtrl.text.trim(),
      });
      if (!mounted) return;
      setState(() { _submitted = true; _submitting = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text('Partner With Us',
            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: _submitted
                ? Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 64),
                    const SizedBox(height: 16),
                    Text('Thanks! We\'ll be in touch soon.',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 17)),
                  ])
                : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Bring AltrobyteLab to your college',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 20)),
                    const SizedBox(height: 6),
                    Text('Tell us a bit about your institution and we\'ll reach out.',
                        style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 13)),
                    const SizedBox(height: 20),
                    TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Your name *')),
                    const SizedBox(height: 12),
                    TextField(controller: _orgCtrl, decoration: const InputDecoration(labelText: 'Institution / Organization name')),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: TextField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'Email'))),
                      const SizedBox(width: 12),
                      Expanded(child: TextField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: 'Phone'))),
                    ]),
                    const SizedBox(height: 12),
                    TextField(controller: _countCtrl, decoration: const InputDecoration(labelText: 'Approx. number of students')),
                    const SizedBox(height: 12),
                    TextField(controller: _messageCtrl, maxLines: 4,
                        decoration: const InputDecoration(labelText: 'Anything else you\'d like us to know?')),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _submitting ? null : _submit,
                        style: FilledButton.styleFrom(backgroundColor: AppColors.accent, padding: const EdgeInsets.symmetric(vertical: 14)),
                        child: _submitting
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text('Submit', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                      ),
                    ),
                    if (_waNumber.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Row(children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text('or talk to us now',
                              style: GoogleFonts.inter(
                                  fontSize: 12, color: AppColors.textSecondary)),
                        ),
                        const Expanded(child: Divider()),
                      ]),
                      const SizedBox(height: 14),
                      // A form is a promise to reply later. Some people would
                      // rather ask now, and the ones who would were leaving
                      // without a way to.
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _whatsapp,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF128C7E),
                            side: const BorderSide(color: Color(0xFF25D366)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          icon: const Icon(Icons.chat_rounded, size: 19),
                          label: Text('Chat on WhatsApp',
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ]),
          ),
        ),
      ),
    );
  }
}
