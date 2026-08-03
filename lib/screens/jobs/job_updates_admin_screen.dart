import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants/api_constants.dart';
import '../../constants/app_colors.dart';
import '../../services/api_service.dart';

/// Super-admin CRUD for the three Job Updates feeds.
class JobUpdatesAdminScreen extends StatefulWidget {
  const JobUpdatesAdminScreen({super.key});

  @override
  State<JobUpdatesAdminScreen> createState() => _JobUpdatesAdminScreenState();
}

class _JobUpdatesAdminScreenState extends State<JobUpdatesAdminScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  static const _categories = ['job', 'scheme', 'freelance'];
  static const _labels = ['Jobs', 'Schemes', 'Freelance'];

  Map<String, List<dynamic>> _listings = {'job': [], 'scheme': [], 'freelance': []};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    for (final c in _categories) {
      try {
        _listings[c] = await ApiService.getJobsAdmin(category: c);
      } catch (_) {}
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _openForm({String? category, Map<String, dynamic>? existing}) async {
    final formKey = GlobalKey<FormState>();
    final titleCtrl = TextEditingController(text: existing?['title'] ?? '');
    final companyCtrl = TextEditingController(text: existing?['company_name'] ?? '');
    final domainCtrl = TextEditingController(text: existing?['domain'] ?? '');
    final locationCtrl = TextEditingController(text: existing?['location'] ?? '');
    final experienceCtrl = TextEditingController(text: existing?['experience_level'] ?? '');
    final descCtrl = TextEditingController(text: existing?['description'] ?? '');
    final linkCtrl = TextEditingController(text: existing?['link_url'] ?? '');
    final cat = category ?? existing?['category'] ?? _categories[_tabs.index];
    String? saveError;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: 20 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(existing == null ? 'New Listing' : 'Edit Listing',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16)),
                const SizedBox(height: 4),
                Text('Fields marked * are required',
                    style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.textSecondary)),
                const SizedBox(height: 14),
                TextFormField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Title *'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Title is required' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: companyCtrl,
                  decoration: const InputDecoration(labelText: 'Company / Org *'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Company / Org is required' : null,
                ),
                const SizedBox(height: 10),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: TextFormField(controller: domainCtrl, decoration: const InputDecoration(labelText: 'Domain'))),
                  const SizedBox(width: 10),
                  Expanded(child: TextFormField(controller: locationCtrl, decoration: const InputDecoration(labelText: 'Location'))),
                ]),
                const SizedBox(height: 10),
                TextFormField(controller: experienceCtrl,
                    decoration: const InputDecoration(labelText: 'Experience level (e.g. fresher, 0-2, 2-5, 5+)')),
                const SizedBox(height: 10),
                TextFormField(controller: descCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Description')),
                const SizedBox(height: 10),
                TextFormField(
                  controller: linkCtrl,
                  decoration: const InputDecoration(
                    labelText: 'External link (optional)',
                    helperText: 'Only needed if this should also link out — students can apply in-app either way.',
                    helperMaxLines: 2,
                  ),
                  validator: (v) {
                    final t = (v ?? '').trim();
                    if (t.isEmpty) return null;
                    final uri = Uri.tryParse(t);
                    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
                      return 'Enter a valid http(s) URL';
                    }
                    return null;
                  },
                ),
                if (saveError != null) ...[
                  const SizedBox(height: 10),
                  Text(saveError!, style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.error)),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      if (!(formKey.currentState?.validate() ?? false)) return;
                      final body = {
                        'category': cat,
                        'title': titleCtrl.text.trim(),
                        'company_name': companyCtrl.text.trim(),
                        'domain': domainCtrl.text.trim(),
                        'location': locationCtrl.text.trim(),
                        'experience_level': experienceCtrl.text.trim(),
                        'description': descCtrl.text.trim(),
                        'link_url': linkCtrl.text.trim(),
                      };
                      try {
                        if (existing == null) {
                          await ApiService.createJob(body);
                        } else {
                          await ApiService.updateJob(existing['id'] as int, body);
                        }
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      } catch (e) {
                        setSheetState(() => saveError = e.toString());
                      }
                    },
                    child: const Text('Save'),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
    if (saved == true) _loadAll();
  }

  Future<void> _showApplications(Map<String, dynamic> item) async {
    var applications = await ApiService.getJobApplications(item['id'] as int);
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => DraggableScrollableSheet(
          initialChildSize: 0.7,
          expand: false,
          builder: (ctx, scrollCtrl) => Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text('Applicants — ${item['title']} (${applications.length})',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
                ),
                TextButton.icon(
                  onPressed: () => _exportCsv(item['id'] as int),
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: const Text('Export CSV'),
                ),
              ]),
              const Divider(),
              Expanded(
                child: applications.isEmpty
                    ? Center(child: Text('No applications yet', style: GoogleFonts.inter(color: AppColors.textSecondary)))
                    : ListView.builder(
                        controller: scrollCtrl,
                        itemCount: applications.length,
                        itemBuilder: (context, i) {
                          final a = applications[i] as Map<String, dynamic>;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              dense: true,
                              leading: const Icon(Icons.person_outline_rounded),
                              title: Text(a['name'] ?? ''),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${a['phone'] ?? ''}  ${a['email'] ?? ''}'),
                                  if ((a['resume_url'] ?? '').isNotEmpty)
                                    Text('Resume: ${a['resume_url']}', style: const TextStyle(fontSize: 11)),
                                  if ((a['cover_note'] ?? '').isNotEmpty)
                                    Text(a['cover_note'], style: const TextStyle(fontSize: 11)),
                                ],
                              ),
                              trailing: DropdownButton<String>(
                                value: a['status'] ?? 'applied',
                                underline: const SizedBox.shrink(),
                                items: const ['applied', 'reviewed', 'shortlisted', 'rejected']
                                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                                    .toList(),
                                onChanged: (v) async {
                                  if (v == null) return;
                                  await ApiService.updateJobApplicationStatus(a['id'] as int, v);
                                  applications = await ApiService.getJobApplications(item['id'] as int);
                                  setSheetState(() {});
                                },
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Future<void> _exportCsv(int jobId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final res = await http.get(
      Uri.parse(ApiConstants.jobApplicationsExport(jobId)),
      headers: {if (token != null) 'Authorization': 'Bearer $token'},
    );
    if (res.statusCode != 200) return;
    final blob = html.Blob([utf8.encode(res.body)], 'text/csv');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', 'job_${jobId}_applications.csv')
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete listing?'),
        content: Text('Delete "${item['title']}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ApiService.deleteJob(item['id'] as int);
    _loadAll();
  }

  Future<void> _togglePublish(Map<String, dynamic> item) async {
    await ApiService.updateJob(item['id'] as int, {'is_published': !(item['is_published'] == true)});
    _loadAll();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text('Job Updates — Admin',
            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
        bottom: TabBar(
          controller: _tabs,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: AppColors.accent,
          tabs: _labels.map((l) => Tab(text: l)).toList(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: Colors.white),
            tooltip: 'New listing',
            onPressed: () => _openForm(category: _categories[_tabs.index]),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabs,
              children: _categories.map((c) {
                final items = _listings[c] ?? [];
                if (items.isEmpty) {
                  return Center(child: Text('No listings yet', style: GoogleFonts.inter(color: AppColors.textSecondary)));
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final item = items[i] as Map<String, dynamic>;
                    final published = item['is_published'] == true;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        title: Text(item['title'] ?? '', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                        subtitle: Text('${item['company_name'] ?? ''} · ${item['location'] ?? ''}',
                            style: GoogleFonts.inter(fontSize: 12)),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(
                            icon: const Icon(Icons.people_outline_rounded, size: 20),
                            tooltip: 'Applicants',
                            onPressed: () => _showApplications(item),
                          ),
                          IconButton(
                            icon: Icon(published ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                                color: published ? AppColors.success : Colors.grey, size: 20),
                            onPressed: () => _togglePublish(item),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 20),
                            onPressed: () => _openForm(existing: item),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                            onPressed: () => _delete(item),
                          ),
                        ]),
                      ),
                    );
                  },
                );
              }).toList(),
            ),
    );
  }
}
