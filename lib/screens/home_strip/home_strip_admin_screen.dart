import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../services/api_service.dart';

/// Admin management for the home strip — 2-3 social/group-join link
/// buttons and short text updates shown at the top of student home.
class HomeStripAdminScreen extends StatefulWidget {
  const HomeStripAdminScreen({super.key});

  @override
  State<HomeStripAdminScreen> createState() => _HomeStripAdminScreenState();
}

class _HomeStripAdminScreenState extends State<HomeStripAdminScreen> {
  List<dynamic> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await ApiService.getHomeStripAdmin();
      if (!mounted) return;
      setState(() { _items = items; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _openForm({Map<String, dynamic>? existing}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (_) => _ItemFormSheet(existing: existing),
    );
    if (saved == true) _load();
  }

  Future<void> _toggleActive(Map<String, dynamic> item) async {
    try {
      await ApiService.updateHomeStripItem(item['id'] as int, {'is_active': !(item['is_active'] == true)});
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this item?'),
        content: Text('"${item['label']}" will be removed from the home strip.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ApiService.deleteHomeStripItem(item['id'] as int);
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final links = _items.where((i) => i['item_type'] == 'link').toList();
    final updates = _items.where((i) => i['item_type'] == 'update').toList();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text('Home Strip', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
        actions: [IconButton(icon: const Icon(Icons.refresh_rounded, color: Colors.white), onPressed: _load)],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        backgroundColor: AppColors.accent,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('Add Item', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
              children: [
                Text('Social / group links', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 4),
                Text('Shown as buttons at the top of student home', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 10),
                if (links.isEmpty) _empty('No links yet — WhatsApp group, Instagram, LinkedIn, etc.'),
                ...links.map((i) => _itemTile(i)),
                const SizedBox(height: 24),
                Text('Updates', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 4),
                Text('Short announcements that rotate at the top of home', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 10),
                if (updates.isEmpty) _empty('No updates yet'),
                ...updates.map((i) => _itemTile(i)),
              ],
            ),
    );
  }

  Widget _empty(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text, style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textSecondary, fontStyle: FontStyle.italic)),
      );

  Widget _itemTile(Map<String, dynamic> item) {
    final isActive = item['is_active'] == true;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(item['label'] ?? '', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13.5)),
        subtitle: (item['url'] ?? '').toString().isNotEmpty
            ? Text(item['url'], style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.textSecondary))
            : null,
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          Switch(value: isActive, onChanged: (_) => _toggleActive(item)),
          IconButton(icon: const Icon(Icons.edit_outlined, size: 20), onPressed: () => _openForm(existing: item)),
          IconButton(icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.error), onPressed: () => _delete(item)),
        ]),
      ),
    );
  }
}

class _ItemFormSheet extends StatefulWidget {
  final Map<String, dynamic>? existing;
  const _ItemFormSheet({this.existing});

  @override
  State<_ItemFormSheet> createState() => _ItemFormSheetState();
}

class _ItemFormSheetState extends State<_ItemFormSheet> {
  late String _type = widget.existing?['item_type'] ?? 'link';
  late final _labelCtrl = TextEditingController(text: widget.existing?['label'] ?? '');
  late final _urlCtrl = TextEditingController(text: widget.existing?['url'] ?? '');
  late String _icon = widget.existing?['icon'] ?? 'link';
  bool _saving = false;

  static const _iconOptions = {
    'link': 'Generic link', 'whatsapp': 'WhatsApp', 'instagram': 'Instagram',
    'linkedin': 'LinkedIn', 'youtube': 'YouTube', 'telegram': 'Telegram', 'discord': 'Discord',
  };

  @override
  void dispose() {
    _labelCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_labelCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Label is required')));
      return;
    }
    if (_type == 'link' && _urlCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('URL is required for a link')));
      return;
    }
    setState(() => _saving = true);
    final body = {
      'item_type': _type,
      'label': _labelCtrl.text.trim(),
      'url': _urlCtrl.text.trim(),
      'icon': _type == 'link' ? _icon : '',
    };
    try {
      if (widget.existing != null) {
        await ApiService.updateHomeStripItem(widget.existing!['id'] as int, body);
      } else {
        await ApiService.createHomeStripItem(body);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.existing != null ? 'Edit Item' : 'New Item', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 18)),
        const SizedBox(height: 16),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'link', label: Text('Link')),
            ButtonSegment(value: 'update', label: Text('Update')),
          ],
          selected: {_type},
          onSelectionChanged: (s) => setState(() => _type = s.first),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _labelCtrl,
          decoration: InputDecoration(labelText: _type == 'link' ? 'Button text' : 'Update text',
              hintText: _type == 'link' ? 'e.g. Join WhatsApp Group' : 'e.g. New workshop dropping this Sunday!'),
        ),
        if (_type == 'link') ...[
          const SizedBox(height: 12),
          TextField(controller: _urlCtrl, decoration: const InputDecoration(labelText: 'URL', hintText: 'https://...')),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _icon,
            decoration: const InputDecoration(labelText: 'Icon'),
            items: _iconOptions.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
            onChanged: (v) => setState(() => _icon = v ?? 'link'),
          ),
        ],
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 14)),
            child: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text('Save', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }
}
