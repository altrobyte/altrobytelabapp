import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../constants/app_colors.dart';
import '../../constants/api_constants.dart';
import '../../widgets/link_coaching_sheet.dart';

/// Shown once, right after a brand-new student registers. Lets them
/// optionally link a coaching institute, join the community group, and
/// follow social links — all skippable, straight to the dashboard.
class StudentOnboardingScreen extends StatefulWidget {
  const StudentOnboardingScreen({super.key});

  @override
  State<StudentOnboardingScreen> createState() => _StudentOnboardingScreenState();
}

class _StudentOnboardingScreenState extends State<StudentOnboardingScreen> {
  String _name = '';
  String _phone = '';
  bool _linked = false;

  String _welcomeMessage = 'Welcome to AltrobyteLab!';
  String _instagramUrl = '';
  String _youtubeUrl = '';
  String _telegramUrl = '';
  String _groupUrl = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _name = prefs.getString('student_name') ?? '';
    _phone = prefs.getString('student_phone') ?? '';
    _linked = !(prefs.getBool('student_is_standalone') ?? true);
    if (mounted) setState(() {});

    try {
      final res = await http.get(Uri.parse(ApiConstants.onboardingConfig()));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _welcomeMessage = (data['welcome_message'] ?? '').toString().isNotEmpty
                ? data['welcome_message']
                : _welcomeMessage;
            _instagramUrl = data['instagram_url'] ?? '';
            _youtubeUrl = data['youtube_url'] ?? '';
            _telegramUrl = data['telegram_url'] ?? '';
            _groupUrl = data['group_url'] ?? '';
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _openLink(String url) async {
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _continue() => context.go('/student/home');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(children: [
              const SizedBox(height: 12),
              Container(
                width: 76, height: 76,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [Color(0xFF7C4DFF), Color(0xFF00BFA5)]),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.celebration_rounded, color: Colors.white, size: 40),
              ),
              const SizedBox(height: 16),
              Text(_name.isNotEmpty ? 'Welcome, $_name! 🎉' : 'Welcome! 🎉',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(_welcomeMessage,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary, height: 1.4)),
              const SizedBox(height: 28),

              // Link to coaching
              _PerkCard(
                icon: Icons.link_rounded,
                iconColor: AppColors.primary,
                title: _linked ? 'Coaching Linked ✓' : 'Link to a Coaching Institute',
                subtitle: _linked
                    ? 'Aapka account coaching se connect ho chuka hai'
                    : 'Agar aap kisi coaching me enrolled hain to link kar lo',
                actionLabel: _linked ? null : 'Link Now',
                onAction: _linked
                    ? null
                    : () => showLinkCoachingSheet(
                          context,
                          phone: _phone,
                          onLinked: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool('student_is_standalone', false);
                            if (!mounted) return;
                            setState(() => _linked = true);
                            messenger.showSnackBar(const SnackBar(
                                content: Text('Coaching linked!'), backgroundColor: AppColors.success));
                          },
                        ),
                done: _linked,
              ),
              const SizedBox(height: 12),

              // Join community group
              _PerkCard(
                icon: Icons.groups_rounded,
                iconColor: const Color(0xFF25D366),
                title: 'Join our Community Group',
                subtitle: _groupUrl.isEmpty
                    ? 'Coming soon'
                    : 'Doubts, updates & study tips — sab ek jagah',
                actionLabel: _groupUrl.isEmpty ? null : 'Join',
                onAction: _groupUrl.isEmpty ? null : () => _openLink(_groupUrl),
              ),
              const SizedBox(height: 12),

              // Follow social
              _PerkCard(
                icon: Icons.favorite_rounded,
                iconColor: const Color(0xFFE53935),
                title: 'Follow Us',
                subtitle: 'Study tips, motivation & exam updates',
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  _SocialIconButton(
                    icon: Icons.camera_alt_rounded,
                    enabled: _instagramUrl.isNotEmpty,
                    onTap: () => _openLink(_instagramUrl),
                  ),
                  const SizedBox(width: 8),
                  _SocialIconButton(
                    icon: Icons.play_circle_fill_rounded,
                    enabled: _youtubeUrl.isNotEmpty,
                    onTap: () => _openLink(_youtubeUrl),
                  ),
                  const SizedBox(width: 8),
                  _SocialIconButton(
                    icon: Icons.send_rounded,
                    enabled: _telegramUrl.isNotEmpty,
                    onTap: () => _openLink(_telegramUrl),
                  ),
                ]),
              ),

              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _continue,
                  child: Text('Continue to Dashboard',
                      style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _continue,
                child: Text('Skip for now',
                    style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 13)),
              ),
              const SizedBox(height: 16),
            ]),
          ),
        ),
      ),
    );
  }
}

class _PerkCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool done;
  final Widget? trailing;

  const _PerkCard({
    required this.icon, required this.iconColor,
    required this.title, required this.subtitle,
    this.actionLabel, this.onAction, this.done = false, this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(subtitle,
                style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.textSecondary),
                maxLines: 2, overflow: TextOverflow.ellipsis),
          ]),
        ),
        if (trailing != null) trailing!,
        if (done)
          const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 22)
        else if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            child: Text(actionLabel!,
                style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w600)),
          ),
      ]),
    );
  }
}

class _SocialIconButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  const _SocialIconButton({required this.icon, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
          color: enabled ? AppColors.primary.withValues(alpha: 0.1) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: enabled ? AppColors.primary : Colors.grey.shade400),
      ),
    );
  }
}
