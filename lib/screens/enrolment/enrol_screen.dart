import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../services/api_service.dart';

/// The page behind an enrolment form's link (/enroll/<slug>). Public: anyone with the link can open it, and fills it
/// after signing in with Google. The server checks the Google sign-in itself; this page never decides who someone is.
class EnrolScreen extends StatefulWidget {
  final String slug;
  const EnrolScreen({super.key, required this.slug});

  @override
  State<EnrolScreen> createState() => _EnrolScreenState();
}

class _EnrolScreenState extends State<EnrolScreen> {
  Map<String, dynamic>? _form;
  String? _loadError;
  User? _user;
  final _phone = TextEditingController();
  final Map<String, TextEditingController> _text = {};
  final Map<String, String?> _choice = {};
  final Map<String, Set<String>> _multi = {};
  bool _busy = false;
  String? _error;
  Map<String, dynamic>? _done;

  @override
  void initState() {
    super.initState();
    _user = FirebaseAuth.instance.currentUser;
    () async {
      try {
        final f = await ApiService.publicEnrolmentForm(widget.slug);
        for (final q in (f['fields'] as List)) {
          if (q['type'] == 'choice') {
            _choice['${q['id']}'] = null;
          } else if (q['type'] == 'multi') {
            _multi['${q['id']}'] = <String>{};
          } else {
            _text['${q['id']}'] = TextEditingController();
          }
        }
        _form = f;
      } catch (e) {
        _loadError = e.toString().replaceFirst('Exception: ', '');
      }
      if (mounted) setState(() {});
    }();
  }

  Future<void> _signIn() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await FirebaseAuth.instance.signOut(); // always let them choose which Google account
      final cred = await FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider());
      _user = cred.user;
    } on FirebaseAuthException catch (e) {
      _error = switch (e.code) {
        'popup-blocked' => 'Your browser blocked the Google window. Allow popups for this page and try again.',
        'popup-closed-by-user' || 'cancelled-popup-request' => 'Google sign-in was cancelled.',
        'network-request-failed' => 'Network problem. Check your connection and try again.',
        _ => 'Google sign-in did not complete (${e.code}).',
      };
    } catch (_) {
      _error = 'Google sign-in did not complete. Please try again.';
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _submit() async {
    final user = _user;
    if (user == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final token = await user.getIdToken(true);
      final answers = <String, dynamic>{
        for (final e in _text.entries) e.key: e.value.text.trim(),
        for (final e in _choice.entries) e.key: e.value ?? '',
        for (final e in _multi.entries) e.key: e.value.toList(),
      };
      _done = await ApiService.submitEnrolment(widget.slug, token ?? '', _phone.text.trim(), answers);
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  void dispose() {
    _phone.dispose();
    for (final c in _text.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.black.withValues(alpha: 0.08))),
              child: Padding(padding: const EdgeInsets.all(24), child: _body()),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_loadError != null) {
      return Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.error_outline_rounded, size: 40, color: Colors.black38),
        const SizedBox(height: 10),
        Text(_loadError!, textAlign: TextAlign.center),
      ]);
    }
    final form = _form;
    if (form == null) return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()));
    final done = _done;
    if (done != null) {
      return Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.check_circle_rounded, size: 52, color: AppColors.success),
        const SizedBox(height: 12),
        Text(done['updated'] == true ? 'Your response is updated' : 'You are enrolled', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 20)),
        const SizedBox(height: 8),
        Text('${done['message']}', textAlign: TextAlign.center, style: GoogleFonts.inter(height: 1.5)),
        const SizedBox(height: 6),
        Text('${done['email']}', style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () => context.go('/download'),
          icon: const Icon(Icons.download_rounded),
          label: const Text('Next: get the Altrobyte app'),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14)),
        ),
        const SizedBox(height: 8),
        TextButton(onPressed: () => setState(() => _done = null), child: const Text('Change my answers')),
      ]);
    }
    final fields = (form['fields'] as List).cast<Map>();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Image.asset('assets/images/logo.png', height: 28, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
        const SizedBox(width: 8),
        Text('Altrobyte Lab', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: AppColors.primary)),
      ]),
      const SizedBox(height: 16),
      Text('${form['title']}', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 22)),
      if ('${form['description']}'.isNotEmpty) ...[
        const SizedBox(height: 8),
        Text('${form['description']}', style: GoogleFonts.inter(height: 1.5, color: AppColors.textSecondary)),
      ],
      const SizedBox(height: 20),
      if (form['is_open'] != true)
        Text('This form is not accepting responses right now.', style: GoogleFonts.inter(color: AppColors.error, fontWeight: FontWeight.w600))
      else if (_user == null) ...[
        Text('Sign in with Google to fill this form.', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: _busy ? null : _signIn,
            icon: const Icon(Icons.login_rounded),
            label: Text(_busy ? 'Opening Google…' : 'Sign in with Google'),
          ),
        ),
      ] else ...[
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFFF1F5FF), borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            const Icon(Icons.verified_user_rounded, color: AppColors.primary, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_user!.displayName ?? '', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                Text(_user!.email ?? '', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
              ]),
            ),
            TextButton(onPressed: _busy ? null : _signIn, child: const Text('Switch')),
          ]),
        ),
        const SizedBox(height: 14),
        TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: _dec('Mobile / WhatsApp number *', hint: 'e.g. 9876543210')),
        for (var i = 0; i < fields.length; i++) ...[
          if ('${fields[i]['section'] ?? ''}'.isNotEmpty && (i == 0 || '${fields[i - 1]['section'] ?? ''}' != '${fields[i]['section']}')) ...[
            const SizedBox(height: 22),
            Text('${fields[i]['section']}', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.primary)),
            const Divider(height: 14),
          ],
          const SizedBox(height: 12),
          _question(fields[i]),
        ],
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: GoogleFonts.inter(color: AppColors.error, fontSize: 13))),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _busy ? null : _submit,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            child: Text(_busy ? 'Submitting…' : 'Submit'),
          ),
        ),
      ],
      if (_user == null && _error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: GoogleFonts.inter(color: AppColors.error, fontSize: 13))),
    ]);
  }

  Widget _question(Map q) {
    final id = '${q['id']}';
    final label = '${q['label']}${q['required'] == true ? ' *' : ''}';
    switch (q['type']) {
      case 'choice':
        return DropdownButtonFormField<String>(
          initialValue: _choice[id],
          isExpanded: true,
          decoration: _dec(label),
          items: [for (final o in (q['options'] as List)) DropdownMenuItem(value: '$o', child: Text('$o'))],
          onChanged: (v) => setState(() => _choice[id] = v),
        );
      case 'multi':
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13.5)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final o in (q['options'] as List))
              FilterChip(
                label: Text('$o'),
                selected: _multi[id]?.contains('$o') == true,
                onSelected: (on) => setState(() => on ? _multi[id]!.add('$o') : _multi[id]!.remove('$o')),
              ),
          ]),
        ]);
      default:
        return TextField(controller: _text[id], maxLines: q['type'] == 'long' ? 4 : 1, decoration: _dec(label));
    }
  }

  InputDecoration _dec(String label, {String? hint}) =>
      InputDecoration(labelText: label, hintText: hint, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)));
}
