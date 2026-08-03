import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../services/api_service.dart';

/// Public, no-login Job Updates — three admin-curated feeds (Jobs,
/// Government/Startup Schemes, Freelance Contracts), filterable, link-out.
class JobUpdatesScreen extends StatefulWidget {
  const JobUpdatesScreen({super.key});

  @override
  State<JobUpdatesScreen> createState() => _JobUpdatesScreenState();
}

class _JobUpdatesScreenState extends State<JobUpdatesScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  static const _categories = ['job', 'scheme', 'freelance'];
  static const _labels = ['Jobs', 'Schemes', 'Freelance'];

  final _domainCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  String _experience = '';

  Map<String, List<dynamic>> _listings = {'job': [], 'scheme': [], 'freelance': []};
  Map<String, bool> _loading = {'job': true, 'scheme': true, 'freelance': true};

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    for (final c in _categories) {
      _load(c);
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    _domainCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  Future<void> _load(String category) async {
    setState(() => _loading[category] = true);
    try {
      final listings = await ApiService.getJobs(
        category: category,
        domain: _domainCtrl.text.trim(),
        location: _locationCtrl.text.trim(),
        experienceLevel: _experience,
      );
      if (!mounted) return;
      setState(() { _listings[category] = listings; _loading[category] = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading[category] = false);
    }
  }

  void _reloadAll() {
    for (final c in _categories) {
      _load(c);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text('Job Updates',
            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
        bottom: TabBar(
          controller: _tabs,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: AppColors.accent,
          tabs: _labels.map((l) => Tab(text: l)).toList(),
        ),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _domainCtrl,
                decoration: InputDecoration(
                  hintText: 'Domain (e.g. Embedded)', isDense: true,
                  prefixIcon: const Icon(Icons.category_outlined, size: 18),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onSubmitted: (_) => _reloadAll(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _locationCtrl,
                decoration: InputDecoration(
                  hintText: 'Location', isDense: true,
                  prefixIcon: const Icon(Icons.location_on_outlined, size: 18),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onSubmitted: (_) => _reloadAll(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _reloadAll,
              icon: const Icon(Icons.search_rounded),
              style: IconButton.styleFrom(backgroundColor: AppColors.primary),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _expChip('', 'All levels'),
                _expChip('fresher', 'Fresher'),
                _expChip('0-2', '0-2 yrs'),
                _expChip('2-5', '2-5 yrs'),
                _expChip('5+', '5+ yrs'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: _categories.map((c) => _buildList(c)).toList(),
          ),
        ),
      ]),
    );
  }

  Widget _expChip(String value, String label) {
    final selected = _experience == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label, style: GoogleFonts.inter(fontSize: 12)),
        selected: selected,
        onSelected: (_) {
          setState(() => _experience = value);
          _reloadAll();
        },
        selectedColor: AppColors.accent.withValues(alpha: 0.2),
      ),
    );
  }

  Widget _buildList(String category) {
    if (_loading[category] == true) return const Center(child: CircularProgressIndicator());
    final items = _listings[category] ?? [];
    if (items.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.work_outline_rounded, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text('No listings match your filters',
              style: GoogleFonts.inter(color: AppColors.textSecondary)),
        ]),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _load(category),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        itemCount: items.length,
        itemBuilder: (context, i) => _JobCard(item: items[i]),
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  final Map<String, dynamic> item;
  const _JobCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/jobs/${item['id']}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item['title'] ?? '', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14.5)),
            if ((item['company_name'] ?? '').isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(item['company_name'], style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textSecondary)),
            ],
            if ((item['description'] ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(item['description'], style: GoogleFonts.inter(fontSize: 12.5, height: 1.4),
                  maxLines: 3, overflow: TextOverflow.ellipsis),
            ],
            const SizedBox(height: 10),
            Wrap(spacing: 6, runSpacing: 6, children: [
              if ((item['domain'] ?? '').isNotEmpty) _tag(Icons.category_outlined, item['domain']),
              if ((item['location'] ?? '').isNotEmpty) _tag(Icons.location_on_outlined, item['location']),
              if ((item['experience_level'] ?? '').isNotEmpty) _tag(Icons.badge_outlined, item['experience_level']),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Text('View details & apply', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.accent)),
              const SizedBox(width: 4),
              Icon(Icons.arrow_forward_rounded, size: 13, color: AppColors.accent),
            ]),
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
}
