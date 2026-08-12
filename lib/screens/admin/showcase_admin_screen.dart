// Admin for Top Stories and Lab Setups.
//
// One screen, two tabs, because the two are the same model — a title, a short
// description, a body, media, and optionally a price and a CTA. Writing this
// twice would mean fixing every upload bug twice.
//
// Media is the point of the whole feature, so adding it is the primary action:
// upload a photo, or paste a YouTube link (Shorts included) and the server
// pulls the id out for a thumbnail.

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../services/api_service.dart';

class ShowcaseAdminScreen extends StatefulWidget {
  const ShowcaseAdminScreen({super.key});

  @override
  State<ShowcaseAdminScreen> createState() => _ShowcaseAdminScreenState();
}

class _ShowcaseAdminScreenState extends State<ShowcaseAdminScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  final _byKind = <String, List<dynamic>>{'story': [], 'lab_setup': []};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs.addListener(() => setState(() {}));
    _loadAll();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  String get _kind => _tabs.index == 0 ? 'story' : 'lab_setup';

  Future<void> _loadAll() async {
    for (final k in ['story', 'lab_setup']) {
      try {
        _byKind[k] = await ApiService.adminGetShowcase(k);
      } catch (_) {}
    }
    if (mounted) setState(() => _loading = false);
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: error ? AppColors.error : AppColors.success));
  }

  Future<void> _edit({Map<String, dynamic>? item}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditorSheet(kind: _kind, item: item),
    );
    if (saved == true) {
      setState(() => _loading = true);
      await _loadAll();
    }
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this?'),
        content: Text('"${item['title']}" and all its photos and videos will be removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiService.adminDeleteShowcase(item['id'] as int);
      _snack('Deleted');
      setState(() => _loading = true);
      await _loadAll();
    } catch (e) {
      _snack(e is ApiException ? e.message : 'Could not delete', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _byKind[_kind] ?? [];
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text('Stories & Lab Setups',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 17)),
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: const [Tab(text: 'Top Stories'), Tab(text: 'Lab Setups')],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add),
        label: Text(_kind == 'story' ? 'New story' : 'New lab setup'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.collections_outlined,
                          size: 46, color: AppColors.textSecondary.withValues(alpha: 0.5)),
                      const SizedBox(height: 12),
                      Text(
                        _kind == 'story'
                            ? 'No stories yet. Add photos of what students are building — '
                                'that is the proof the homepage is missing.'
                            : 'No lab setups yet. Add each setup as a product with photos '
                                'and a price.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                            color: AppColors.textSecondary, fontSize: 13, height: 1.5),
                      ),
                    ]),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadAll,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 90),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final item = items[i] as Map<String, dynamic>;
                      return _AdminRow(
                        item: item,
                        onEdit: () => _edit(item: item),
                        onDelete: () => _delete(item),
                      );
                    },
                  ),
                ),
    );
  }
}

class _AdminRow extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _AdminRow({required this.item, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final media = (item['media'] as List?) ?? [];
    final cover = (item['cover_url'] as String? ?? '').isNotEmpty
        ? item['cover_url'] as String
        : media.isEmpty
            ? ''
            : (media.first as Map)['thumbnail_url'] as String? ?? '';
    final published = item['is_published'] == true;

    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Colors.black.withValues(alpha: 0.07)),
      ),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: SizedBox(
            width: 58,
            height: 58,
            child: cover.isEmpty
                ? Container(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    child: Icon(Icons.image_outlined,
                        color: AppColors.primary.withValues(alpha: 0.5), size: 22))
                : Image.network(cover, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        child: const Icon(Icons.broken_image_outlined, size: 20))),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item['title'] as String? ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.w600)),
            const SizedBox(height: 3),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: (published ? AppColors.success : AppColors.textSecondary)
                      .withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(published ? 'Live' : 'Hidden',
                    style: GoogleFonts.inter(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: published ? AppColors.success : AppColors.textSecondary)),
              ),
              const SizedBox(width: 8),
              Text('${media.length} media',
                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
              if ((item['price_label'] as String? ?? '').isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(item['price_label'] as String,
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary)),
              ],
            ]),
          ]),
        ),
        IconButton(onPressed: onEdit, icon: const Icon(Icons.edit_outlined, size: 20)),
        IconButton(
            onPressed: onDelete,
            icon: Icon(Icons.delete_outline, size: 20, color: AppColors.error)),
      ]),
    );
  }
}

/// Create or edit one item, including its media.
class _EditorSheet extends StatefulWidget {
  final String kind;
  final Map<String, dynamic>? item;
  const _EditorSheet({required this.kind, this.item});

  @override
  State<_EditorSheet> createState() => _EditorSheetState();
}

class _EditorSheetState extends State<_EditorSheet> {
  late final _title = TextEditingController(text: widget.item?['title'] as String? ?? '');
  late final _short =
      TextEditingController(text: widget.item?['short_description'] as String? ?? '');
  late final _body = TextEditingController(text: widget.item?['body'] as String? ?? '');
  late final _price =
      TextEditingController(text: widget.item?['price_label'] as String? ?? '');
  late final _ctaLabel =
      TextEditingController(text: widget.item?['cta_label'] as String? ?? '');
  late final _ctaUrl = TextEditingController(text: widget.item?['cta_url'] as String? ?? '');
  late final _youtube = TextEditingController();

  late bool _published = widget.item?['is_published'] as bool? ?? true;
  late String _cover = widget.item?['cover_url'] as String? ?? '';
  late List<dynamic> _media = List.from((widget.item?['media'] as List?) ?? []);

  bool _saving = false;
  bool _uploading = false;
  int? _id;

  bool get _isLab => widget.kind == 'lab_setup';

  @override
  void initState() {
    super.initState();
    _id = widget.item?['id'] as int?;
  }

  void _snack(String m, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(m), backgroundColor: error ? AppColors.error : AppColors.success));
  }

  /// Media attaches to an item, so an unsaved item is saved first rather than
  /// making the admin save, reopen, and only then add photos.
  Future<int?> _ensureSaved() async {
    if (_id != null) return _id;
    if (_title.text.trim().isEmpty) {
      _snack('Add a title first', error: true);
      return null;
    }
    try {
      final res = await ApiService.adminSaveShowcase(_payload());
      _id = res['id'] as int?;
      return _id;
    } catch (e) {
      _snack(e is ApiException ? e.message : 'Could not save', error: true);
      return null;
    }
  }

  Map<String, dynamic> _payload() => {
        'kind': widget.kind,
        'title': _title.text.trim(),
        'short_description': _short.text.trim(),
        'body': _body.text.trim(),
        'cover_url': _cover,
        'price_label': _price.text.trim(),
        'cta_label': _ctaLabel.text.trim(),
        'cta_url': _ctaUrl.text.trim(),
        'is_published': _published,
        'order_index': widget.item?['order'] as int? ?? 0,
      };

  Future<void> _pickAndUpload({bool asCover = false}) async {
    // Same picker and content-type mapping as ImageUploadField — withData is
    // required on web, where there is no path to read from afterwards.
    final result = await FilePicker.pickFiles(type: FileType.image, withData: true);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      _snack('That file has no data — try another', error: true);
      return;
    }
    setState(() => _uploading = true);
    try {
      final ext = (file.extension ?? 'jpg').toLowerCase();
      final contentType = switch (ext) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        'gif' => 'image/gif',
        _ => 'image/jpeg',
      };
      final url = await ApiService.uploadImage(bytes, file.name, contentType);
      if (asCover) {
        setState(() => _cover = url);
      } else {
        final id = await _ensureSaved();
        if (id == null) return;
        final m = await ApiService.adminAddShowcaseMedia(id, 'image', url,
            orderIndex: _media.length);
        setState(() => _media = [..._media, m]);
      }
      _snack('Uploaded');
    } catch (e) {
      _snack(e is ApiException ? e.message : 'Upload failed', error: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _addYoutube() async {
    final url = _youtube.text.trim();
    if (url.isEmpty) return;
    final id = await _ensureSaved();
    if (id == null) return;
    setState(() => _uploading = true);
    try {
      final m = await ApiService.adminAddShowcaseMedia(id, 'youtube', url,
          orderIndex: _media.length);
      setState(() {
        _media = [..._media, m];
        _youtube.clear();
      });
      _snack('Video added');
    } catch (e) {
      _snack(e is ApiException ? e.message : 'Could not add that link', error: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _removeMedia(Map m) async {
    try {
      await ApiService.adminDeleteShowcaseMedia(m['id'] as int);
      setState(() => _media = _media.where((x) => (x as Map)['id'] != m['id']).toList());
    } catch (e) {
      _snack('Could not remove', error: true);
    }
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      _snack('Add a title', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await ApiService.adminSaveShowcase(_payload(), id: _id);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _snack(e is ApiException ? e.message : 'Could not save', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 40),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 12, 8),
          child: Row(children: [
            Expanded(
              child: Text(
                  _id == null
                      ? (_isLab ? 'New lab setup' : 'New story')
                      : (_isLab ? 'Edit lab setup' : 'Edit story'),
                  style: GoogleFonts.poppins(fontSize: 16.5, fontWeight: FontWeight.w600)),
            ),
            IconButton(
                onPressed: () => Navigator.pop(context, false),
                icon: const Icon(Icons.close)),
          ]),
        ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(
                18, 4, 18, MediaQuery.of(context).viewInsets.bottom + 24),
            children: [
              _field(_title, 'Title', hint: _isLab ? 'Starter Embedded Lab' : "Aman's first PCB"),
              _field(_short, 'Short description',
                  hint: _isLab
                      ? 'Everything for Month 1 — ESP32, sensors, tools'
                      : 'Third year, finished Month 1 in five weeks',
                  maxLines: 2),
              _field(_body, 'Full detail (shown on the story page)', maxLines: 6),
              if (_isLab)
                _field(_price, 'Price label',
                    hint: 'e.g. ₹4,999 or "From ₹4,999" or "On request"'),
              Row(children: [
                Expanded(child: _field(_ctaLabel, 'Button text', hint: 'Enquire on WhatsApp')),
                const SizedBox(width: 10),
                Expanded(child: _field(_ctaUrl, 'Button link', hint: 'https://wa.me/91...')),
              ]),
              const SizedBox(height: 6),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _published,
                onChanged: (v) => setState(() => _published = v),
                title: Text('Show on the site',
                    style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w500)),
                subtitle: Text('Turn off to keep it as a draft',
                    style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.textSecondary)),
              ),
              const Divider(height: 26),
              Text('Cover image',
                  style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('Optional — the first photo or video is used when this is empty.',
                  style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              Row(children: [
                if (_cover.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(_cover,
                        width: 64, height: 64, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox(width: 64, height: 64)),
                  ),
                  const SizedBox(width: 10),
                  TextButton(
                      onPressed: () => setState(() => _cover = ''),
                      child: const Text('Remove')),
                ] else
                  OutlinedButton.icon(
                    onPressed: _uploading ? null : () => _pickAndUpload(asCover: true),
                    icon: const Icon(Icons.image_outlined, size: 18),
                    label: const Text('Choose cover'),
                  ),
              ]),
              const Divider(height: 26),
              Text('Photos & videos',
                  style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(
                  'These rotate on the home page card and open as a full story. '
                  'YouTube Shorts work — just paste the link.',
                  style: GoogleFonts.inter(
                      fontSize: 11.5, height: 1.4, color: AppColors.textSecondary)),
              const SizedBox(height: 10),
              if (_media.isNotEmpty)
                SizedBox(
                  height: 84,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _media.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final m = _media[i] as Map<String, dynamic>;
                      return Stack(children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(9),
                          child: Image.network(m['thumbnail_url'] as String? ?? '',
                              width: 84, height: 84, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                  width: 84,
                                  height: 84,
                                  color: Colors.black12,
                                  child: const Icon(Icons.broken_image_outlined))),
                        ),
                        if (m['media_type'] == 'youtube')
                          const Positioned(
                              left: 4,
                              bottom: 4,
                              child: Icon(Icons.play_circle_fill_rounded,
                                  color: Colors.white, size: 20)),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: InkWell(
                            onTap: () => _removeMedia(m),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                  color: Colors.black54, shape: BoxShape.circle),
                              child: const Icon(Icons.close, size: 13, color: Colors.white),
                            ),
                          ),
                        ),
                      ]);
                    },
                  ),
                ),
              const SizedBox(height: 10),
              Row(children: [
                OutlinedButton.icon(
                  onPressed: _uploading ? null : () => _pickAndUpload(),
                  icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                  label: const Text('Add photo'),
                ),
                const SizedBox(width: 10),
                if (_uploading)
                  const SizedBox(
                      width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _youtube,
                    decoration: InputDecoration(
                      labelText: 'YouTube / Shorts link',
                      hintText: 'https://youtube.com/shorts/...',
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _uploading ? null : _addYoutube,
                  child: const Text('Add'),
                ),
              ]),
              const SizedBox(height: 26),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text('Save',
                          style: GoogleFonts.poppins(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _field(TextEditingController c, String label,
          {String hint = '', int maxLines = 1}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          maxLines: maxLines,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint.isEmpty ? null : hint,
            hintStyle: GoogleFonts.inter(fontSize: 12.5, color: Colors.black26),
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      );
}
