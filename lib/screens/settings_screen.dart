import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_colors.dart';
import '../l10n/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../services/api_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  List<dynamic> _waSettings = [];
  bool _waLoading = true;

  Map<String, dynamic>? _wa(String key) {
    for (final x in _waSettings) {
      if ((x as Map)['key'] == key) return x.cast<String, dynamic>();
    }
    return null;
  }

  Future<void> _loadWaSettings() async {
    try {
      _waSettings = await ApiService.getAdminSettings();
    } catch (_) {
      _waSettings = [];
    }
    if (mounted) setState(() => _waLoading = false);
  }

  Future<void> _saveWaSetting(String key, String value) async {
    try {
      await ApiService.setAdminSetting(key, value);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Saved')));
      }
      await _loadWaSettings();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e is ApiException ? e.message : 'Could not save'),
            backgroundColor: AppColors.error));
      }
    }
  }

  static const _supportEmail = 'support@altrobytelab.com';
  static const _supportWa = '917691971623'; // Altrobyte sales/support WhatsApp
  static const _privacyUrl = 'https://coachingclub-bba5c.web.app/privacy.html';
  static const _deleteAccountUrl =
      'https://coachingclub-bba5c.web.app/delete-account.html';

  Map<String, dynamic> _profile = {};
  Map<String, dynamic>? _sub;
  final _waCtrl = TextEditingController();
  final _noticeTitleCtrl = TextEditingController();
  final _noticeBodyCtrl = TextEditingController();
  bool _loadingSettings = true;
  bool _savingWa = false;
  bool _savingProfile = false;
  bool _sendingNotice = false;

  // Branding state
  final _slugCtrl = TextEditingController();
  final _taglineCtrl = TextEditingController();
  final _brandColorCtrl = TextEditingController();
  bool _savingBrand = false;

  // Test config state
  List<Map<String, dynamic>> _configSubjects = [];
  List<Map<String, dynamic>> _configPatterns = [];
  bool _loadingConfig = true;
  bool _savingConfig = false;

  @override
  void initState() {
    super.initState();
    _loadWaSettings();
    _loadSettings();
  }

  @override
  void dispose() {
    _waCtrl.dispose();
    _noticeTitleCtrl.dispose();
    _noticeBodyCtrl.dispose();
    _slugCtrl.dispose();
    _taglineCtrl.dispose();
    _brandColorCtrl.dispose();
    super.dispose();
  }

  String? get _code => _profile['institute_code'] as String?;

  Future<void> _loadSettings() async {
    final auth = context.read<AuthProvider>();
    if (auth.instituteId == null) {
      setState(() => _loadingSettings = false);
      return;
    }
    try {
      final data = await ApiService.getInstituteProfile(auth.instituteId!);
      if (!mounted) return;
      setState(() {
        _profile = data;
        _waCtrl.text = (data['wa_ai_number'] ?? '').toString();
        // Load branding fields from profile
        _slugCtrl.text = (data['slug'] ?? '').toString();
        _brandColorCtrl.text = (data['brand_color'] ?? 'E94560').toString();
        _taglineCtrl.text = (data['tagline'] ?? '').toString();
      });
    } catch (_) {}
    try {
      final sub = await ApiService.getSubscription(auth.instituteId!);
      if (mounted) setState(() => _sub = sub);
    } catch (_) {}
    try {
      final config = await ApiService.getTestConfig(auth.instituteId!);
      if (mounted) {
        setState(() {
          _configSubjects = List<Map<String, dynamic>>.from(config['subjects'] ?? []);
          _configPatterns = List<Map<String, dynamic>>.from(config['exam_patterns'] ?? []);
          _loadingConfig = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingConfig = false);
    }
    if (!mounted) return;
    setState(() => _loadingSettings = false);
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  /// WhatsApp settings, editable here rather than only under super admin.
  /// The backend exposes a named allowlist — plan prices and AI quotas stay
  /// where they were, because saving one login is not worth handing those out.
  Widget _buildWhatsAppCard() {
    return _SectionCard(
      icon: Icons.chat_rounded,
      iconColor: const Color(0xFF25D366),
      title: 'WhatsApp',
      subtitle: 'The number, the dashboard link, and template switches',
      child: _waLoading
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()))
          : Column(children: [
              // The two anyone actually sets.
              for (final key in const [
                'program_whatsapp_number',
                'wa_dashboard_url',
                // Read by the roadmap's sticky bar. Blank and it drops the
                // line — an empty scarcity claim is worse than none.
                'program_start_label',
                'program_seats_left',
              ])
                if (_wa(key) != null)
                  _WaSettingRow(
                    setting: _wa(key)!,
                    onSave: (v) => _saveWaSetting(key, v),
                  ),

              // The template switches are gone. Whether Meta has approved a
              // template is something Meta knows and we can ask, so the
              // backend asks — a switch here could only be flipped late, or
              // flipped early and hard-error on an unapproved name.
              for (final t in const [
                ('wa_daily_enabled', 'Send one nudge a day'),
              ])
                if (_wa(t.$1) != null)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    value: (_wa(t.$1)!['value'] as String? ?? '') == '1',
                    onChanged: (v) => _saveWaSetting(t.$1, v ? '1' : ''),
                    title: Text(t.$2,
                        style: GoogleFonts.inter(
                            fontSize: 13, fontWeight: FontWeight.w500)),
                    subtitle: Text(
                        'Opted-in students only, one line a day',
                        style: GoogleFonts.inter(fontSize: 11, color: Colors.grey)),
                  ),

            ]),
    );
  }

  Widget _buildSubscriptionCard() {
    final sub = _sub;
    final status = (sub?['status'] ?? 'active').toString();
    final planLabel = (sub?['plan_label'] ?? 'Basic').toString();
    final daysLeft = sub?['days_left'];

    Color color;
    String statusText;
    String headline;
    String ctaLabel;
    bool urgent = false;
    switch (status) {
      case 'trial':
        color = AppColors.primary;
        statusText = 'Free Trial';
        headline = daysLeft != null ? '$daysLeft days remaining' : 'Trial active';
        ctaLabel = 'Choose Plan';
        break;
      case 'grace':
        color = AppColors.warning;
        statusText = 'Trial Ended';
        headline = '3 days to renew before suspension';
        ctaLabel = 'Upgrade Now';
        urgent = true;
        break;
      case 'expired':
        color = AppColors.error;
        statusText = 'Account Suspended';
        headline = 'Pay to restore access';
        ctaLabel = 'Restore Now';
        urgent = true;
        break;
      default:
        color = AppColors.success;
        statusText = '$planLabel Plan — Active';
        headline = daysLeft != null ? 'Renews in $daysLeft days' : 'Active';
        ctaLabel = 'Renew / Upgrade';
    }

    final studentsUsed = sub?['students_used'] ?? 0;
    final maxStudents = sub?['max_students'] ?? 50;
    final price = sub?['price'] ?? 999;
    final unlimited = (maxStudents as int) >= 100000;

    // Usage meter + quick audits link (enterprise feature)
    final usageText = unlimited ? '$studentsUsed students (unlimited)' : '$studentsUsed / $maxStudents students';

    return _SectionCard(
      icon: Icons.workspace_premium_rounded,
      iconColor: color,
      title: 'Subscription & Billing',
      subtitle: 'Your plan, usage, and billing details.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Usage meter (prominent for recurring revenue awareness)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Usage: $usageText',
                    style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    final auth = context.read<AuthProvider>();
                    if (auth.instituteId != null) {
                      context.push('/audits/${auth.instituteId}');
                    }
                  },
                  child: const Text('View Activity Logs', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(
                    status == 'trial' ? Icons.hourglass_top_rounded
                        : status == 'grace' ? Icons.warning_amber_rounded
                        : status == 'expired' ? Icons.lock_rounded
                        : Icons.verified_rounded,
                    color: color, size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(statusText,
                      style: GoogleFonts.poppins(
                          fontSize: 14, fontWeight: FontWeight.w700, color: color)),
                ]),
                const SizedBox(height: 4),
                Text(headline,
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                if (status == 'trial' && daysLeft != null) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: ((30 - (daysLeft as int)) / 30).clamp(0.0, 1.0),
                      backgroundColor: color.withValues(alpha: 0.15),
                      valueColor: AlwaysStoppedAnimation(color),
                      minHeight: 5,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Usage bar
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.people_rounded, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    unlimited
                        ? '$studentsUsed students enrolled'
                        : '$studentsUsed / $maxStudents students',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                  const Spacer(),
                  Text('₹$price/mo',
                      style: GoogleFonts.inter(
                          fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
                ]),
                if (!unlimited) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: maxStudents > 0 ? (studentsUsed / maxStudents).clamp(0.0, 1.0) : 0,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation(
                        studentsUsed >= maxStudents ? AppColors.error : AppColors.primary,
                      ),
                      minHeight: 6,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: urgent ? color : AppColors.accent),
              onPressed: _showUpgradeSheet,
              icon: const Icon(Icons.bolt_rounded, size: 18),
              label: Text(ctaLabel),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandingCard() {
    final slug = _slugCtrl.text.trim();
    final previewUrl = slug.isNotEmpty
        ? 'https://altrobytelab.com/$slug'
        : null;

    return _SectionCard(
      icon: Icons.storefront_rounded,
      iconColor: AppColors.primary,
      title: 'Student App',
      subtitle: 'Customize what students see on your branded page.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (previewUrl != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                const Icon(Icons.link_rounded, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(previewUrl,
                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.primary),
                      overflow: TextOverflow.ellipsis),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: previewUrl));
                    _toast('Link copied!');
                  },
                ),
              ]),
            ),
            const SizedBox(height: 14),
          ],
          TextField(
            controller: _taglineCtrl,
            decoration: const InputDecoration(
              labelText: 'Tagline / Motto',
              hintText: 'Your institute motto or tagline',
              prefixIcon: Icon(Icons.short_text_rounded),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: _savingBrand ? null : _saveBranding,
              icon: _savingBrand
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_rounded, size: 16),
              label: const Text('Save'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestConfigCard() {
    return _SectionCard(
      icon: Icons.tune_rounded,
      iconColor: AppColors.accent,
      title: 'Test Configuration',
      subtitle: 'Customize subjects & exam patterns for your institute.',
      child: _loadingConfig
          ? const Center(child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator()))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ConfigChipSection(
                  title: 'Subjects',
                  items: _configSubjects,
                  onAdd: () => _addConfigItem('subject'),
                  onRemove: (i) => setState(() => _configSubjects.removeAt(i)),
                ),
                const SizedBox(height: 16),
                _ConfigChipSection(
                  title: 'Exam Patterns',
                  items: _configPatterns,
                  onAdd: () => _addConfigItem('exam_pattern'),
                  onRemove: (i) => setState(() => _configPatterns.removeAt(i)),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
                    onPressed: _savingConfig ? null : _saveTestConfig,
                    icon: _savingConfig
                        ? const SizedBox(width: 14, height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save_rounded, size: 16),
                    label: const Text('Save Configuration'),
                  ),
                ),
              ],
            ),
    );
  }

  void _addConfigItem(String type) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(type == 'subject' ? 'Add Subject' : 'Add Exam Pattern',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            labelText: type == 'subject' ? 'Subject name' : 'Pattern name',
            hintText: type == 'subject' ? 'e.g. Data Structures' : 'e.g. GATE CS',
          ),
          onSubmitted: (v) {
            if (v.trim().isNotEmpty) Navigator.pop(dialogContext, v.trim());
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final v = ctrl.text.trim();
              if (v.isNotEmpty) Navigator.pop(dialogContext, v);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    ).then((value) {
      if (value == null || value.toString().isEmpty) return;
      setState(() {
        if (type == 'subject') {
          _configSubjects.add({'label': value, 'value': value, 'icon': ''});
        } else {
          _configPatterns.add({'label': value, 'value': value, 'icon': ''});
        }
      });
    });
  }

  Future<void> _saveTestConfig() async {
    final auth = context.read<AuthProvider>();
    if (auth.instituteId == null) return;
    setState(() => _savingConfig = true);
    try {
      await ApiService.saveTestConfigSubjects(auth.instituteId!, _configSubjects);
      // Save patterns
      await ApiService.saveTestConfigPatterns(auth.instituteId!, _configPatterns);
      _toast('Configuration saved!');
    } catch (e) {
      _toast(e.toString());
    }
    if (mounted) setState(() => _savingConfig = false);
  }

  Future<void> _saveBranding() async {
    final auth = context.read<AuthProvider>();
    if (auth.instituteId == null) return;
    setState(() => _savingBrand = true);
    try {
      final slug = _slugCtrl.text.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      await ApiService.updateBrand(
        auth.instituteId!,
        slug: slug.isNotEmpty ? slug : null,
        brandColor: _brandColorCtrl.text.trim().isNotEmpty ? _brandColorCtrl.text.trim() : null,
        tagline: _taglineCtrl.text.trim().isNotEmpty ? _taglineCtrl.text.trim() : null,
      );
      _slugCtrl.text = slug;
      _toast('Branding saved!');
    } catch (e) {
      _toast(e.toString());
    }
    if (!mounted) return;
    setState(() => _savingBrand = false);
  }

  void _contactAddon(String service) {
    final text = Uri.encodeComponent(
        'Hi Altrobyte, I am interested in: $service. Please share details.');
    _launch('https://wa.me/$_supportWa?text=$text');
  }

  void _showUpgradeSheet() {
    context.push('/plans');
  }

  Future<void> _saveWaNumber() async {
    final auth = context.read<AuthProvider>();
    final l10n = AppLocalizations.of(context)!;
    setState(() => _savingWa = true);
    try {
      await ApiService.updateWaNumber(auth.instituteId!, _waCtrl.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.settingsWaSaved)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
    if (!mounted) return;
    setState(() => _savingWa = false);
  }

  Future<void> _saveProfile(Map<String, dynamic> updates) async {
    final auth = context.read<AuthProvider>();
    final l10n = AppLocalizations.of(context)!;
    setState(() => _savingProfile = true);
    try {
      final data =
          await ApiService.updateInstituteProfile(auth.instituteId!, updates);
      if (!mounted) return;
      setState(() => _profile = data);
      final newName = (data['name'] ?? '').toString();
      if (newName.isNotEmpty) await auth.updateInstituteName(newName);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.settingsProfileSaved)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
    if (!mounted) return;
    setState(() => _savingProfile = false);
  }

  Future<void> _editName() async {
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => _EditNameDialog(
        initial: (_profile['name'] ?? '').toString(),
      ),
    );
    if (newName != null && newName.trim().isNotEmpty) {
      await _saveProfile({'name': newName.trim()});
    }
  }

  Future<void> _postNotice() async {
    final auth = context.read<AuthProvider>();
    final l10n = AppLocalizations.of(context)!;
    final title = _noticeTitleCtrl.text.trim();
    if (title.isEmpty) return;
    setState(() => _sendingNotice = true);
    try {
      await ApiService.postNotice(
          auth.instituteId!, title, content: _noticeBodyCtrl.text.trim());
      if (!mounted) return;
      _noticeTitleCtrl.clear();
      _noticeBodyCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n.settingsNoticeSent),
          backgroundColor: AppColors.success));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
    if (!mounted) return;
    setState(() => _sendingNotice = false);
  }

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final l10n = AppLocalizations.of(context)!;
    final lang = context.watch<LanguageProvider>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.settingsTitle,
                style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 24),

            // ── Institute Profile (editable) ──
            _SectionCard(
              icon: Icons.business_rounded,
              iconColor: AppColors.primary,
              title: l10n.settingsProfile,
              trailing: TextButton.icon(
                onPressed: _loadingSettings ? null : _editName,
                icon: _savingProfile
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.edit_rounded, size: 16),
                label: Text(l10n.commonEdit),
              ),
              child: _loadingSettings
                  ? const Padding(
                      padding: EdgeInsets.all(8),
                      child: Center(child: CircularProgressIndicator()))
                  : Column(
                      children: [
                        _infoRow(l10n.settingsInstituteName,
                            auth.instituteName ?? l10n.settingsNotSet),
                        _infoRow(l10n.settingsOwnerName,
                            _profileVal('owner_name', l10n)),
                        _infoRow(l10n.settingsOwnerPhone,
                            _profileVal('owner_phone', l10n)),
                        _infoRow(
                            l10n.settingsEmail, _profileVal('email', l10n)),
                        _infoRow(l10n.settingsCity, _profileVal('city', l10n)),
                      ],
                    ),
            ),
            const SizedBox(height: 16),

            // ── WhatsApp ──
            _buildWhatsAppCard(),
            const SizedBox(height: 16),

            // ── Subscription / Billing ──
            _buildSubscriptionCard(),
            const SizedBox(height: 16),

            // ── PWA Branding ──
            _buildBrandingCard(),
            const SizedBox(height: 16),

            // ── Test Configuration ──
            _buildTestConfigCard(),
            const SizedBox(height: 16),

            // ── Enrollment Code ──
            _SectionCard(
              icon: Icons.vpn_key_rounded,
              iconColor: AppColors.teal,
              title: l10n.settingsEnrollmentCode,
              subtitle: l10n.settingsEnrollmentCodeSubtitle,
              child: _loadingSettings
                  ? const Center(child: CircularProgressIndicator())
                  : Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 14, horizontal: 20),
                            decoration: BoxDecoration(
                              color: AppColors.teal
                                  .withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: AppColors.teal
                                      .withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              _code ?? '---',
                              style: GoogleFonts.poppins(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.tealDark,
                                  letterSpacing: 6),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        IconButton.filled(
                          style: IconButton.styleFrom(
                              backgroundColor: AppColors.teal),
                          icon: const Icon(Icons.copy_rounded,
                              color: Colors.white),
                          onPressed: _code == null
                              ? null
                              : () {
                                  Clipboard.setData(
                                      ClipboardData(text: _code!));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content:
                                              Text(l10n.settingsCodeCopied)));
                                },
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 16),

            // ── AI Tutor WhatsApp Number ──
            _SectionCard(
              icon: Icons.smart_toy_rounded,
              iconColor: AppColors.whatsapp,
              title: l10n.settingsAiTutorNumber,
              subtitle: l10n.settingsAiTutorSubtitle,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _waCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: l10n.settingsPhoneWithCode,
                        prefixIcon: const Icon(Icons.phone_rounded),
                        hintText: '919876543210',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: AppColors.whatsapp),
                    onPressed: _savingWa ? null : _saveWaNumber,
                    child: _savingWa
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text(l10n.settingsSave),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Post a Notice ──
            _SectionCard(
              icon: Icons.campaign_rounded,
              iconColor: AppColors.accent,
              title: l10n.settingsNoticeTitle,
              subtitle: l10n.settingsNoticeSubtitle,
              child: Column(
                children: [
                  TextField(
                    controller: _noticeTitleCtrl,
                    decoration: InputDecoration(
                      labelText: l10n.settingsNoticeHeading,
                      prefixIcon: const Icon(Icons.title_rounded),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _noticeBodyCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: l10n.settingsNoticeBody,
                      prefixIcon: const Icon(Icons.notes_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                          backgroundColor: AppColors.accent),
                      onPressed: _sendingNotice ? null : _postNotice,
                      icon: _sendingNotice
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.send_rounded, size: 16),
                      label: Text(l10n.settingsNoticeSend),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Language ──
            _SectionCard(
              icon: Icons.language_rounded,
              iconColor: AppColors.primary,
              title: l10n.settingsLanguage,
              child: Row(
                children: [
                  _LangButton(
                    label: l10n.settingsLangEnglish,
                    active: !lang.isHindi,
                    onTap: () => lang.setLocale(const Locale('en')),
                  ),
                  const SizedBox(width: 12),
                  _LangButton(
                    label: l10n.settingsLangHindi,
                    active: lang.isHindi,
                    onTap: () => lang.setLocale(const Locale('hi')),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── WhatsApp Automation ──
            _SectionCard(
              icon: Icons.chat_rounded,
              iconColor: AppColors.whatsapp,
              title: 'WhatsApp Automation',
              subtitle:
                  'Send bulk messages, fee reminders & results to students/parents on WhatsApp.',
              child: Column(children: [
                _LinkTile(
                  icon: Icons.campaign_rounded,
                  label: 'Bulk Messaging / Broadcast',
                  onTap: () => context.go('/broadcast'),
                ),
                _LinkTile(
                  icon: Icons.smart_toy_rounded,
                  label: 'Set up AI auto-replies',
                  onTap: () => _contactAddon('WhatsApp AI Automation'),
                ),
              ]),
            ),
            const SizedBox(height: 16),

            // ── Add-on Services (upsell) ──
            _SectionCard(
              icon: Icons.rocket_launch_rounded,
              iconColor: AppColors.accent,
              title: 'Grow Your Institute',
              subtitle: 'Premium services by Altrobyte — tap to enquire.',
              child: Column(children: [
                _LinkTile(
                  icon: Icons.language_rounded,
                  label: 'Website Development',
                  onTap: () => _contactAddon('Website Development'),
                ),
                _LinkTile(
                  icon: Icons.camera_alt_rounded,
                  label: 'Instagram Automation',
                  onTap: () => _contactAddon('Instagram Automation'),
                ),
                _LinkTile(
                  icon: Icons.trending_up_rounded,
                  label: 'Sales Booster',
                  onTap: () => _contactAddon('Sales Booster'),
                ),
                _LinkTile(
                  icon: Icons.ads_click_rounded,
                  label: 'Digital Marketing',
                  onTap: () => _contactAddon('Digital Marketing'),
                ),
              ]),
            ),
            const SizedBox(height: 16),

            // ── Help & About ──
            _SectionCard(
              icon: Icons.help_outline_rounded,
              iconColor: AppColors.textSecondary,
              title: l10n.settingsHelp,
              child: Column(
                children: [
                  _LinkTile(
                    icon: Icons.support_agent_rounded,
                    label: l10n.settingsContactSupport,
                    trailing: _supportEmail,
                    onTap: () => _launch(
                        'mailto:$_supportEmail?subject=AltrobyteLab Support'),
                  ),
                  _LinkTile(
                    icon: Icons.privacy_tip_rounded,
                    label: l10n.settingsPrivacyPolicy,
                    onTap: () => _launch(_privacyUrl),
                  ),
                  _LinkTile(
                    icon: Icons.delete_outline_rounded,
                    label: l10n.settingsDeleteAccount,
                    color: AppColors.error,
                    onTap: () => _launch(_deleteAccountUrl),
                  ),
                  _LinkTile(
                    icon: Icons.info_outline_rounded,
                    label: l10n.settingsAppVersion,
                    trailing: 'v1.0.0',
                    onTap: null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Logout ──
            Card(
              child: ListTile(
                leading:
                    const Icon(Icons.logout_rounded, color: AppColors.error),
                title: Text(l10n.settingsLogout,
                    style: const TextStyle(color: AppColors.error)),
                onTap: auth.logout,
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                '${auth.instituteName ?? 'AltrobyteLab'} • ${l10n.settingsVersion}',
                style: GoogleFonts.inter(
                    color: AppColors.textSecondary, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _profileVal(String key, AppLocalizations l10n) {
    final v = (_profile[key] ?? '').toString().trim();
    return v.isEmpty ? l10n.settingsNotSet : v;
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: GoogleFonts.inter(
                    fontSize: 13, color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(value,
                style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }
}

class _EditNameDialog extends StatefulWidget {
  final String initial;
  const _EditNameDialog({required this.initial});

  @override
  State<_EditNameDialog> createState() => _EditNameDialogState();
}

class _EditNameDialogState extends State<_EditNameDialog> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.settingsEditProfile,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        textInputAction: TextInputAction.done,
        onSubmitted: (v) => Navigator.pop(context, v),
        decoration: InputDecoration(
          labelText: l10n.settingsInstituteName,
          prefixIcon: const Icon(Icons.business_rounded, size: 20),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.commonCancel)),
        FilledButton(
            onPressed: () => Navigator.pop(context, _ctrl.text),
            child: Text(l10n.commonSave)),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;

  const _SectionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title,
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!,
                  style: GoogleFonts.inter(
                      fontSize: 12, color: AppColors.textSecondary)),
            ],
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? trailing;
  final Color? color;
  final VoidCallback? onTap;

  const _LinkTile({
    required this.icon,
    required this.label,
    this.trailing,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color ?? AppColors.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      color: color ?? AppColors.textPrimary)),
            ),
            if (trailing != null)
              Text(trailing!,
                  style: GoogleFonts.inter(
                      fontSize: 12, color: AppColors.textSecondary)),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: AppColors.textSecondary),
            ],
          ],
        ),
      ),
    );
  }
}

class _LangButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _LangButton(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? AppColors.primary : AppColors.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: active ? AppColors.primary : Colors.grey.shade300),
          ),
          child: Center(
            child: Text(label,
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: active ? Colors.white : AppColors.textPrimary)),
          ),
        ),
      ),
    );
  }
}

class _ConfigChipSection extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> items;
  final VoidCallback onAdd;
  final void Function(int) onRemove;

  const _ConfigChipSection({
    required this.title,
    required this.items,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text(title,
              style: GoogleFonts.inter(
                  fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const Spacer(),
          TextButton.icon(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('Add', style: TextStyle(fontSize: 12)),
            onPressed: onAdd,
          ),
        ]),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: items.asMap().entries.map((entry) {
            final i = entry.key;
            final item = entry.value;
            final label = '${item['icon'] ?? ''} ${item['label'] ?? ''}'.trim();
            return Chip(
              label: Text(label, style: GoogleFonts.inter(fontSize: 12)),
              deleteIcon: const Icon(Icons.close_rounded, size: 14),
              onDeleted: () => onRemove(i),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            );
          }).toList(),
        ),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('Using defaults — tap Add to customize',
                style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
          ),
      ],
    );
  }
}


/// One editable setting. Saves on demand rather than on every keystroke — a
/// half-typed phone number written to the live config would break the CTA it
/// powers.
class _WaSettingRow extends StatefulWidget {
  final Map<String, dynamic> setting;
  final Future<void> Function(String value) onSave;
  const _WaSettingRow({required this.setting, required this.onSave});

  @override
  State<_WaSettingRow> createState() => _WaSettingRowState();
}

class _WaSettingRowState extends State<_WaSettingRow> {
  late final _ctrl =
      TextEditingController(text: widget.setting['value'] as String? ?? '');
  bool _dirty = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  static const _labels = {
    'program_whatsapp_number': 'Enquiry number',
    'wa_dashboard_url': 'WhatsApp dashboard link',
  };

  String get _label =>
      _labels[widget.setting['key']] ??
      (widget.setting['key'] as String).replaceAll('_', ' ');

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_label,
            style: GoogleFonts.inter(
                fontSize: 12.5, fontWeight: FontWeight.w600)),
        Text(widget.setting['description'] as String? ?? '',
            style: GoogleFonts.inter(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _ctrl,
              onChanged: (_) => setState(() => _dirty = true),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Not set',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(9)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: _dirty
                ? () async {
                    await widget.onSave(_ctrl.text);
                    if (mounted) setState(() => _dirty = false);
                  }
                : null,
            child: const Text('Save'),
          ),
        ]),
      ]),
    );
  }
}
