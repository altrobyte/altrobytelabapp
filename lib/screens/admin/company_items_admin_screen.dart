import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../constants/app_colors.dart';
import '../../services/api_service.dart';

/// Clients, colleges, projects, services, products and placed profiles.
///
/// Every one of these already had a public page and a backend that could
/// create them. What was missing was any way to put something in — so
/// /clients, /services and /products had been shipped and were permanently
/// empty, which is worse than not linking to them at all.
///
/// One screen for six lists because they are the same three fields: a name, a
/// logo and a line. Six screens would have been five copies of this one,
/// drifting apart.
class CompanyItemsAdminScreen extends StatefulWidget {
  const CompanyItemsAdminScreen({super.key});

  @override
  State<CompanyItemsAdminScreen> createState() =>
      _CompanyItemsAdminScreenState();
}

class _CompanyItemsAdminScreenState extends State<CompanyItemsAdminScreen>
    with SingleTickerProviderStateMixin {
  /// The category key is what the public page filters on, so these strings
  /// have to match the routes exactly — 'placed', not 'placement'.
  static const _cats = <(String, String, String)>[
    ('client', 'Clients', 'The companies you have built for. A name a reader '
        'recognises does more than a paragraph about us.'),
    ('college', 'Colleges', 'The colleges you have actually taught at. A '
        'student reads this list looking for their own.'),
    ('project', 'Projects', 'What was built, with a photo. This is the page an '
        'employer opens.'),
    ('service', 'Services', 'What a company can hire you to do.'),
    ('product', 'Products', 'What you have made and can show.'),
    ('placed', 'Placed', 'Students who got the job, and where. Real ones only '
        '— an invented placement is the one thing that would cost you every '
        'real student who checks.'),
  ];

  late final TabController _tabs =
      TabController(length: _cats.length, vsync: this);
  final Map<String, List> _byCat = {for (final c in _cats) c.$1: []};
  bool _loading = true;
  String _error = '';

  String get _cat => _cats[_tabs.index].$1;

  @override
  void initState() {
    super.initState();
    _tabs.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      for (final c in _cats) {
        _byCat[c.$1] = await ApiService.getCompanyItemsAdmin(category: c.$1);
      }
      _error = '';
    } catch (e) {
      _error = e is ApiException ? e.message : '$e';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _edit([Map<String, dynamic>? existing]) async {
    final cat = _cat;
    final title = TextEditingController(text: '${existing?['title'] ?? ''}');
    final subtitle =
        TextEditingController(text: '${existing?['subtitle'] ?? ''}');
    final description =
        TextEditingController(text: '${existing?['description'] ?? ''}');
    final image = TextEditingController(text: '${existing?['image_url'] ?? ''}');
    final link = TextEditingController(text: '${existing?['link_url'] ?? ''}');
    var published = existing?['is_published'] != false;

    final labels = switch (cat) {
      'client' => ('Company name', 'What you built for them', 'Logo image URL'),
      'college' => ('College name', 'What you taught there', 'Logo image URL'),
      'project' => ('Project name', 'One line about it', 'Photo URL'),
      'placed' => ('Student name', 'Company and role', 'Photo URL'),
      _ => ('Name', 'One line', 'Image URL'),
    };

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.only(
              left: 18,
              right: 18,
              top: 18,
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 18),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(existing == null ? 'Add' : 'Edit',
                  style: GoogleFonts.poppins(
                      fontSize: 16.5, fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              TextField(
                  controller: title,
                  decoration: InputDecoration(labelText: '${labels.$1} *')),
              const SizedBox(height: 10),
              TextField(
                  controller: subtitle,
                  decoration: InputDecoration(labelText: labels.$2)),
              const SizedBox(height: 10),
              TextField(
                controller: description,
                maxLines: 4,
                decoration: const InputDecoration(
                    labelText: 'Description',
                    alignLabelWithHint: true),
              ),
              const SizedBox(height: 10),
              TextField(
                  controller: image,
                  decoration: InputDecoration(
                      labelText: labels.$3,
                      helperText: 'Paste a URL. Square logos look best.')),
              const SizedBox(height: 10),
              TextField(
                  controller: link,
                  decoration: const InputDecoration(
                      labelText: 'Link (optional)',
                      hintText: 'https://')),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Published'),
                value: published,
                activeThumbColor: AppColors.accent,
                onChanged: (v) => setSheetState(() => published = v),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: () {
                    if (title.text.trim().isEmpty) {
                      ScaffoldMessenger.of(sheetContext).showSnackBar(
                          SnackBar(content: Text('${labels.$1} is required')));
                      return;
                    }
                    Navigator.pop(sheetContext, true);
                  },
                  child: const Text('Save'),
                ),
              ),
            ]),
          ),
        ),
      ),
    );

    if (saved != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final body = {
      'category': cat,
      'title': title.text.trim(),
      'subtitle': subtitle.text.trim(),
      'description': description.text.trim(),
      'image_url': image.text.trim(),
      'link_url': link.text.trim(),
      'is_published': published,
      'order_index': (existing?['order_index'] as num?)?.toInt() ?? 0,
    };
    try {
      if (existing == null) {
        await ApiService.createCompanyItem(body);
      } else {
        await ApiService.updateCompanyItem(existing['id'] as int, body);
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(
          backgroundColor: AppColors.error,
          content: Text(e is ApiException ? e.message : '$e')));
      return;
    }
    _load();
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete?'),
        content: Text('Remove "${item['title']}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ApiService.deleteCompanyItem(item['id'] as int);
    } catch (e) {
      messenger.showSnackBar(SnackBar(
          backgroundColor: AppColors.error,
          content: Text(e is ApiException ? e.message : '$e')));
      return;
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final items = _byCat[_cat] ?? const [];
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Text('Clients, Colleges & Projects',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        actions: [
          IconButton(onPressed: () => _edit(), icon: const Icon(Icons.add)),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          indicatorColor: AppColors.accent,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [for (final c in _cats) Tab(text: c.$2)],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(child: Text(_error))
              : items.isEmpty
                  ? _empty()
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) =>
                          _row(Map<String, dynamic>.from(items[i])),
                    ),
    );
  }

  Widget _empty() {
    final blurb = _cats[_tabs.index].$3;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.inbox_rounded,
              size: 38, color: AppColors.textSecondary),
          const SizedBox(height: 12),
          Text('Nothing here yet',
              style: GoogleFonts.poppins(
                  fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(blurb,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 12.5, height: 1.5, color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
            onPressed: () => _edit(),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add the first one'),
          ),
        ]),
      ),
    );
  }

  Widget _row(Map<String, dynamic> item) {
    final img = '${item['image_url'] ?? ''}'.trim();
    final live = item['is_published'] != false;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Row(children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(9),
          ),
          clipBehavior: Clip.antiAlias,
          child: img.isEmpty
              ? const Icon(Icons.image_outlined,
                  size: 19, color: AppColors.textSecondary)
              : Image.network(img,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                      Icons.broken_image_outlined,
                      size: 19,
                      color: AppColors.textSecondary)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${item['title']}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                if ('${item['subtitle'] ?? ''}'.trim().isNotEmpty)
                  Text('${item['subtitle']}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                          fontSize: 11.5, color: AppColors.textSecondary)),
              ]),
        ),
        if (!live)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: AppColors.textSecondary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20)),
            child: Text('DRAFT',
                style: GoogleFonts.inter(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary)),
          ),
        IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () => _edit(item),
            icon: const Icon(Icons.edit_rounded,
                size: 18, color: AppColors.primary)),
        IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () => _delete(item),
            icon: const Icon(Icons.delete_outline_rounded,
                size: 18, color: AppColors.error)),
      ]),
    );
  }
}
