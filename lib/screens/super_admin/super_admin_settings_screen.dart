import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants/api_constants.dart';

class SuperAdminSettingsScreen extends StatefulWidget {
  const SuperAdminSettingsScreen({super.key});
  @override
  State<SuperAdminSettingsScreen> createState() => _SuperAdminSettingsScreenState();
}

class _SuperAdminSettingsScreenState extends State<SuperAdminSettingsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _settings = [];
  String? _superToken;

  // Human-readable labels for each setting key
  static const _labels = {
    'student_free_monthly_limit':    'Free Plan: AI tests / month',
    'student_premium_monthly_limit': 'Premium Plan: AI tests / month',
    'student_premium_price':         'Premium Price (₹ / month)',
    'free_daily_attempts':           'Free Plan: Quiz attempts / day',
    'student_premium_duration_days': 'Premium Duration (days)',
    'institute_starter_monthly_limit': 'Institute Starter: AI tests / month',
    'institute_growth_monthly_limit':  'Institute Growth: AI tests / month',
    'institute_pro_monthly_limit':     'Institute Pro: AI tests / month',
    'onboarding_welcome_message':      'Welcome Message (new students)',
    'onboarding_instagram_url':        'Instagram Link',
    'onboarding_youtube_url':          'YouTube Link',
    'onboarding_telegram_url':         'Telegram Link',
    'onboarding_group_url':            'Community Group Join Link',
  };

  static const _icons = {
    'student_free_monthly_limit':    Icons.person_outline_rounded,
    'student_premium_monthly_limit': Icons.workspace_premium_rounded,
    'student_premium_price':         Icons.currency_rupee_rounded,
    'free_daily_attempts':           Icons.today_rounded,
    'student_premium_duration_days': Icons.calendar_month_rounded,
    'institute_starter_monthly_limit': Icons.apartment_rounded,
    'institute_growth_monthly_limit':  Icons.trending_up_rounded,
    'institute_pro_monthly_limit':     Icons.auto_awesome_rounded,
    'onboarding_welcome_message':      Icons.celebration_rounded,
    'onboarding_instagram_url':        Icons.camera_alt_rounded,
    'onboarding_youtube_url':          Icons.play_circle_fill_rounded,
    'onboarding_telegram_url':         Icons.send_rounded,
    'onboarding_group_url':            Icons.groups_rounded,
  };

  static const _textKeys = {
    'onboarding_welcome_message', 'onboarding_instagram_url', 'onboarding_youtube_url',
    'onboarding_telegram_url', 'onboarding_group_url',
  };

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _superToken = prefs.getString('super_token');
    await _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await http.get(
        Uri.parse(ApiConstants.superSettings()),
        headers: {'Authorization': 'Bearer ${_superToken ?? ''}'},
      );
      final body = jsonDecode(res.body);
      if (res.statusCode >= 400) throw body['detail'] ?? 'Failed';
      setState(() {
        _settings = List<Map<String, dynamic>>.from(body['settings'] ?? []);
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _editSetting(Map<String, dynamic> setting) async {
    final ctrl = TextEditingController(text: setting['value']);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_labels[setting['key']] ?? setting['key'],
            style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (setting['description'] != null && setting['description'].isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(setting['description'],
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600])),
              ),
            TextField(
              controller: ctrl,
              keyboardType: _textKeys.contains(setting['key'])
                  ? TextInputType.text
                  : TextInputType.number,
              maxLines: setting['key'] == 'onboarding_welcome_message' ? 3 : 1,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Value',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final res = await http.put(
        Uri.parse(ApiConstants.superSettingUpdate(setting['key'])),
        headers: {
          'Authorization': 'Bearer ${_superToken ?? ''}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'value': ctrl.text.trim()}),
      );
      if (res.statusCode >= 400) {
        final b = jsonDecode(res.body);
        throw b['detail'] ?? 'Update failed';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Setting updated'), backgroundColor: Color(0xFF00897B)));
        await _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1565C0),
        title: Text('Platform Settings',
            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 12),
                  ElevatedButton(onPressed: _load, child: const Text('Retry')),
                ]))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const _SectionHeader('Student Plans'),
                    ..._settings
                        .where((s) => s['key'].toString().startsWith('student_'))
                        .map((s) => _SettingTile(
                              setting: s,
                              label: _labels[s['key']] ?? s['key'],
                              icon: _icons[s['key']] ?? Icons.settings_rounded,
                              onEdit: () => _editSetting(s),
                            )),
                    const SizedBox(height: 16),
                    const _SectionHeader('Institute Plans'),
                    ..._settings
                        .where((s) => s['key'].toString().startsWith('institute_'))
                        .map((s) => _SettingTile(
                              setting: s,
                              label: _labels[s['key']] ?? s['key'],
                              icon: _icons[s['key']] ?? Icons.settings_rounded,
                              onEdit: () => _editSetting(s),
                            )),
                    const SizedBox(height: 16),
                    const _SectionHeader('Onboarding & Social Links'),
                    ..._settings
                        .where((s) => s['key'].toString().startsWith('onboarding_'))
                        .map((s) => _SettingTile(
                              setting: s,
                              label: _labels[s['key']] ?? s['key'],
                              icon: _icons[s['key']] ?? Icons.settings_rounded,
                              onEdit: () => _editSetting(s),
                            )),
                    const SizedBox(height: 16),
                    const _SectionHeader('Other Settings'),
                    ..._settings
                        .where((s) =>
                            !s['key'].toString().startsWith('student_') &&
                            !s['key'].toString().startsWith('institute_') &&
                            !s['key'].toString().startsWith('onboarding_'))
                        .map((s) => _SettingTile(
                              setting: s,
                              label: _labels[s['key']] ?? s['key'],
                              icon: _icons[s['key']] ?? Icons.settings_rounded,
                              onEdit: () => _editSetting(s),
                            )),
                    const SizedBox(height: 32),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Row(children: [
                        Icon(Icons.info_outline_rounded, color: Colors.amber.shade700, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Changes apply immediately to new sign-ups and next billing cycle.',
                            style: GoogleFonts.inter(fontSize: 12, color: Colors.amber.shade800),
                          ),
                        ),
                      ]),
                    ),
                  ],
                ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title,
          style: GoogleFonts.poppins(
              fontSize: 13, fontWeight: FontWeight.w700, color: Colors.grey[600])),
    );
  }
}

class _SettingTile extends StatelessWidget {
  final Map<String, dynamic> setting;
  final String label;
  final IconData icon;
  final VoidCallback onEdit;

  const _SettingTile({
    required this.setting, required this.label,
    required this.icon, required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF1565C0).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: const Color(0xFF1565C0)),
        ),
        title: Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
        subtitle: Text(setting['description'] ?? '',
            style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[500]),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1565C0).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                  (setting['value'] ?? '').toString().isEmpty
                      ? 'Not set'
                      : setting['value'],
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                      fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF1565C0))),
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.edit_rounded, size: 16, color: Colors.grey),
        ]),
        onTap: onEdit,
      ),
    );
  }
}
