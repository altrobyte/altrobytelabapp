// Lab kits shop, product management (9 Nov 2026, founder: "make it editable in the admin; I will correct the
// descriptions and kit components later"). What is saved here is what altrobytelab.com/kits shows: each lab kit
// (name, price, who it is for, what you build, tag, photo, components with quantities) and each part (name, category,
// emoji, what it is for, price with GST, photo). Edits stay on this screen until Save; the server checks the whole
// catalogue before it replaces the live one, and keeps the version before.

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../services/api_service.dart';

String _rs(num n) {
  final s = n.round().toString();
  if (s.length <= 3) return '₹$s';
  final last3 = s.substring(s.length - 3);
  var rest = s.substring(0, s.length - 3);
  final groups = <String>[];
  while (rest.length > 2) {
    groups.insert(0, rest.substring(rest.length - 2));
    rest = rest.substring(0, rest.length - 2);
  }
  if (rest.isNotEmpty) groups.insert(0, rest);
  return '₹${groups.join(',')},$last3';
}

String _slug(String name, Iterable<String> taken) {
  var base = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
  if (base.isEmpty) base = 'item';
  if (base.length > 20) base = base.substring(0, 20);
  var id = base;
  var n = 2;
  while (taken.contains(id)) {
    id = '$base-${n++}';
  }
  return id;
}

Future<String?> _uploadPhoto(BuildContext context) async {
  final result = await FilePicker.pickFiles(type: FileType.image, withData: true);
  if (result == null || result.files.isEmpty) return null;
  final file = result.files.single;
  final bytes = file.bytes;
  if (bytes == null) return null;
  final ext = (file.extension ?? 'jpg').toLowerCase();
  final type = switch (ext) { 'png' => 'image/png', 'webp' => 'image/webp', 'gif' => 'image/gif', _ => 'image/jpeg' };
  return ApiService.uploadImage(bytes, file.name, type);
}

class KitsAdminScreen extends StatefulWidget {
  const KitsAdminScreen({super.key});

  @override
  State<KitsAdminScreen> createState() => _KitsAdminScreenState();
}

class _KitsAdminScreenState extends State<KitsAdminScreen> {
  List<Map<String, dynamic>> _parts = [];
  List<Map<String, dynamic>> _kits = [];
  List<dynamic> _projects = [];
  bool _loading = true, _saving = false, _dirty = false;
  String? _err;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      final c = await ApiService.kitsCatalog();
      setState(() {
        _parts = [for (final p in (c['parts'] as List? ?? [])) Map<String, dynamic>.from(p as Map)];
        _kits = [
          for (final k in (c['kits'] as List? ?? []))
            {...Map<String, dynamic>.from(k as Map), 'parts': Map<String, dynamic>.from((k['parts'] as Map?) ?? {})}
        ];
        _projects = (c['projects'] as List?) ?? [];
        _dirty = false;
      });
    } catch (_) {
      setState(() => _err = 'Could not load the kits. Check the internet and try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, dynamic>? _part(String id) {
    for (final p in _parts) {
      if (p['id'] == id) return p;
    }
    return null;
  }

  num _worth(Map<String, dynamic> k) {
    num t = 0;
    (k['parts'] as Map).forEach((id, q) => t += ((_part(id as String)?['price'] as num?) ?? 0) * (q as num));
    return t;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ApiService.kitsCatalogSave({'parts': _parts, 'kits': _kits, 'projects': _projects});
      setState(() => _dirty = false);
      _snack('Saved. altrobytelab.com/kits shows it within a minute.');
    } on ApiException catch (e) {
      _snack(e.message, error: true);
    } catch (_) {
      _snack('Could not save. Check the internet and try again.', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String m, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: error ? Colors.red.shade700 : null));
  }

  Future<void> _editKit([Map<String, dynamic>? k]) async {
    final out = await showDialog<Map<String, dynamic>>(
        context: context, builder: (_) => _KitDialog(kit: k, parts: _parts, takenIds: _kits.map((x) => x['id'] as String)));
    if (out == null) return;
    setState(() {
      if (out['_delete'] == true) {
        _kits.remove(k);
      } else if (k == null) {
        _kits.add(out);
      } else {
        _kits[_kits.indexOf(k)] = out;
      }
      _dirty = true;
    });
  }

  Future<void> _editPart([Map<String, dynamic>? p]) async {
    final cats = <String>{for (final x in _parts) x['cat'] as String};
    final out = await showDialog<Map<String, dynamic>>(
        context: context, builder: (_) => _PartDialog(part: p, categories: cats.toList(), takenIds: _parts.map((x) => x['id'] as String)));
    if (out == null) return;
    setState(() {
      if (out['_delete'] == true) {
        final id = p!['id'];
        _parts.remove(p);
        for (final k in _kits) {
          (k['parts'] as Map).remove(id);
        }
        for (final pr in _projects) {
          ((pr as Map)['parts'] as Map?)?.remove(id);
        }
      } else if (p == null) {
        _parts.add(out);
      } else {
        _parts[_parts.indexOf(p)] = out;
      }
      _dirty = true;
    });
  }

  Widget _kitTile(Map<String, dynamic> k) {
    final w = _worth(k), price = (k['price'] as num?) ?? 0;
    final n = (k['parts'] as Map).values.fold<num>(0, (t, q) => t + (q as num));
    return Card(
      child: ListTile(
        leading: (k['img'] as String? ?? '').isNotEmpty
            ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(k['img'], width: 56, height: 56, fit: BoxFit.cover))
            : CircleAvatar(child: Text(k['ic'] as String? ?? '📦')),
        title: Text('${k['name']}  ·  ${_rs(price)}', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        subtitle: Text(
            '${k['for'] ?? ''}\n$n components · parts worth ${_rs(w)}'
            '${w > price ? ' · saves ${_rs(w - price)}' : ' · costs MORE than its parts'}',
            style: TextStyle(color: w > price ? null : Colors.red.shade700)),
        isThreeLine: true,
        trailing: const Icon(Icons.edit_outlined),
        onTap: () => _editKit(k),
      ),
    );
  }

  Widget _partTile(Map<String, dynamic> p) => Card(
        child: ListTile(
          dense: true,
          leading: (p['img'] as String? ?? '').isNotEmpty
              ? ClipRRect(borderRadius: BorderRadius.circular(6), child: Image.network(p['img'], width: 40, height: 40, fit: BoxFit.cover))
              : Text(p['ic'] as String? ?? '📦', style: const TextStyle(fontSize: 22)),
          title: Text(p['name'] as String),
          subtitle: Text('${p['cat']} · ${p['use'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: Text(_rs((p['price'] as num?) ?? 0), style: const TextStyle(fontWeight: FontWeight.w700)),
          onTap: () => _editPart(p),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Lab kits shop', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          bottom: const TabBar(labelColor: AppColors.primary, tabs: [Tab(text: 'Lab kits'), Tab(text: 'Parts')]),
          actions: [
            if (_dirty) const Center(child: Text('Not saved  ', style: TextStyle(color: Colors.orange))),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton.icon(
                onPressed: _dirty && !_saving ? _save : null,
                icon: _saving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save_outlined),
                label: const Text('Save'),
              ),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _err != null
                ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(_err!), TextButton(onPressed: _load, child: const Text('Try again'))]))
                : TabBarView(children: [
                    ListView(padding: const EdgeInsets.all(12), children: [
                      const Text('What altrobytelab.com/kits shows. Tap a kit to change its price, words, photo or components.',
                          style: TextStyle(color: Colors.black54)),
                      const SizedBox(height: 8),
                      for (final k in _kits) _kitTile(k),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(onPressed: () => _editKit(), icon: const Icon(Icons.add), label: const Text('New lab kit')),
                    ]),
                    ListView(padding: const EdgeInsets.all(12), children: [
                      const Text('Every part, with its price including GST. A kit\'s "parts worth" is worked out from these.',
                          style: TextStyle(color: Colors.black54)),
                      const SizedBox(height: 8),
                      for (final p in _parts) _partTile(p),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(onPressed: () => _editPart(), icon: const Icon(Icons.add), label: const Text('New part')),
                    ]),
                  ]),
      ),
    );
  }
}

class _KitDialog extends StatefulWidget {
  final Map<String, dynamic>? kit;
  final List<Map<String, dynamic>> parts;
  final Iterable<String> takenIds;
  const _KitDialog({this.kit, required this.parts, required this.takenIds});

  @override
  State<_KitDialog> createState() => _KitDialogState();
}

class _KitDialogState extends State<_KitDialog> {
  late final _name = TextEditingController(text: widget.kit?['name'] as String? ?? '');
  late final _price = TextEditingController(text: '${widget.kit?['price'] ?? ''}');
  late final _for = TextEditingController(text: widget.kit?['for'] as String? ?? '');
  late final _learn = TextEditingController(text: widget.kit?['learn'] as String? ?? '');
  late final _tag = TextEditingController(text: widget.kit?['tag'] as String? ?? '');
  late final _ic = TextEditingController(text: widget.kit?['ic'] as String? ?? '📦');
  late String _img = widget.kit?['img'] as String? ?? '';
  late final Map<String, int> _qty = {
    for (final e in ((widget.kit?['parts'] as Map?) ?? {}).entries) e.key as String: (e.value as num).toInt()
  };
  bool _uploading = false;
  String? _err;

  Map<String, dynamic>? _part(String id) => widget.parts.where((p) => p['id'] == id).firstOrNull;

  num get _worth => _qty.entries.fold<num>(0, (t, e) => t + ((_part(e.key)?['price'] as num?) ?? 0) * e.value);

  Future<void> _photo() async {
    setState(() => _uploading = true);
    try {
      final url = await _uploadPhoto(context);
      if (url != null) setState(() => _img = url);
    } catch (_) {
      setState(() => _err = 'The photo did not upload. Try a smaller JPG or PNG.');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _addComponent() async {
    final left = widget.parts.where((p) => !_qty.containsKey(p['id'])).toList();
    final id = await showDialog<String>(
      context: context,
      builder: (_) => SimpleDialog(title: const Text('Add a component'), children: [
        for (final p in left)
          SimpleDialogOption(
              onPressed: () => Navigator.pop(context, p['id'] as String),
              child: Text('${p['ic'] ?? ''} ${p['name']}  ·  ${_rs((p['price'] as num?) ?? 0)}')),
      ]),
    );
    if (id != null) setState(() => _qty[id] = 1);
  }

  void _done() {
    final price = int.tryParse(_price.text.trim().replaceAll(',', ''));
    if (_name.text.trim().isEmpty) return setState(() => _err = 'Give the kit a name.');
    if (price == null || price < 1) return setState(() => _err = 'Write the price in rupees, for example 4999.');
    if (_qty.isEmpty) return setState(() => _err = 'Add at least one component.');
    final k = widget.kit;
    Navigator.pop(context, {
      'id': k?['id'] ?? _slug(_name.text, widget.takenIds),
      'ic': _ic.text.trim(),
      'name': _name.text.trim(),
      'price': price,
      'for': _for.text.trim(),
      'learn': _learn.text.trim(),
      'tag': _tag.text.trim().toUpperCase(),
      'art': k?['art'] ?? '',
      'img': _img,
      'parts': Map<String, dynamic>.from(_qty),
    });
  }

  @override
  Widget build(BuildContext context) {
    final price = int.tryParse(_price.text.trim().replaceAll(',', '')) ?? 0, w = _worth;
    return AlertDialog(
      title: Text(widget.kit == null ? 'New lab kit' : 'Edit ${widget.kit!['name']}'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              SizedBox(width: 70, child: TextField(controller: _ic, decoration: const InputDecoration(labelText: 'Emoji'))),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name'))),
            ]),
            Row(children: [
              Expanded(
                  child: TextField(
                      controller: _price,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(labelText: 'Price ₹ (with GST)'))),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: _tag, decoration: const InputDecoration(labelText: 'Tag (optional)', hintText: 'MOST CHOSEN'))),
            ]),
            TextField(controller: _for, decoration: const InputDecoration(labelText: 'Who it is for')),
            TextField(controller: _learn, maxLines: 3, decoration: const InputDecoration(labelText: 'Description: what you build with it')),
            const SizedBox(height: 12),
            Row(children: [
              if (_img.isNotEmpty) ...[
                ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(_img, width: 96, height: 48, fit: BoxFit.cover)),
                const SizedBox(width: 8),
              ],
              OutlinedButton.icon(
                  onPressed: _uploading ? null : _photo,
                  icon: const Icon(Icons.photo_outlined),
                  label: Text(_uploading ? 'Uploading…' : (_img.isEmpty ? 'Add photo' : 'Change photo'))),
              if (_img.isNotEmpty) TextButton(onPressed: () => setState(() => _img = ''), child: const Text('Use the drawing')),
            ]),
            const SizedBox(height: 14),
            Text('Components', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            Text('Parts worth ${_rs(w)}${price > 0 ? (w > price ? ' · customer saves ${_rs(w - price)}' : ' · the kit costs more than its parts') : ''}',
                style: TextStyle(color: price > 0 && w <= price ? Colors.red.shade700 : Colors.green.shade700, fontSize: 13)),
            for (final e in _qty.entries.toList())
              Row(children: [
                Expanded(child: Text('${_part(e.key)?['name'] ?? e.key}', style: const TextStyle(fontSize: 13.5))),
                IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () => setState(() => e.value <= 1 ? _qty.remove(e.key) : _qty[e.key] = e.value - 1)),
                Text('${e.value}', style: const TextStyle(fontWeight: FontWeight.w700)),
                IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () => setState(() => _qty[e.key] = (e.value + 1).clamp(1, 50))),
              ]),
            TextButton.icon(onPressed: _addComponent, icon: const Icon(Icons.add), label: const Text('Add a component')),
            if (_err != null) Text(_err!, style: TextStyle(color: Colors.red.shade700)),
          ]),
        ),
      ),
      actions: [
        if (widget.kit != null)
          TextButton(
              onPressed: () => Navigator.pop(context, {'_delete': true}),
              child: Text('Remove kit', style: TextStyle(color: Colors.red.shade700))),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _done, child: const Text('Done')),
      ],
    );
  }
}

class _PartDialog extends StatefulWidget {
  final Map<String, dynamic>? part;
  final List<String> categories;
  final Iterable<String> takenIds;
  const _PartDialog({this.part, required this.categories, required this.takenIds});

  @override
  State<_PartDialog> createState() => _PartDialogState();
}

class _PartDialogState extends State<_PartDialog> {
  late final _name = TextEditingController(text: widget.part?['name'] as String? ?? '');
  late final _cat = TextEditingController(text: widget.part?['cat'] as String? ?? (widget.categories.isNotEmpty ? widget.categories.first : ''));
  late final _use = TextEditingController(text: widget.part?['use'] as String? ?? '');
  late final _price = TextEditingController(text: '${widget.part?['price'] ?? ''}');
  late final _ic = TextEditingController(text: widget.part?['ic'] as String? ?? '📦');
  late String _img = widget.part?['img'] as String? ?? '';
  bool _uploading = false;
  String? _err;

  Future<void> _photo() async {
    setState(() => _uploading = true);
    try {
      final url = await _uploadPhoto(context);
      if (url != null) setState(() => _img = url);
    } catch (_) {
      setState(() => _err = 'The photo did not upload. Try a smaller JPG or PNG.');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _done() {
    final price = int.tryParse(_price.text.trim().replaceAll(',', ''));
    if (_name.text.trim().isEmpty) return setState(() => _err = 'Give the part a name.');
    if (_cat.text.trim().isEmpty) return setState(() => _err = 'Pick or write a category.');
    if (price == null || price < 0) return setState(() => _err = 'Write the price in rupees, for example 549.');
    Navigator.pop(context, {
      'id': widget.part?['id'] ?? _slug(_name.text, widget.takenIds),
      'cat': _cat.text.trim(),
      'ic': _ic.text.trim(),
      'name': _name.text.trim(),
      'use': _use.text.trim(),
      'price': price,
      'img': _img,
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.part == null ? 'New part' : 'Edit part'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                SizedBox(width: 70, child: TextField(controller: _ic, decoration: const InputDecoration(labelText: 'Emoji'))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name'))),
              ]),
              TextField(controller: _use, decoration: const InputDecoration(labelText: 'What you can build with it')),
              Row(children: [
                Expanded(child: TextField(controller: _price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Price ₹ (with GST)'))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: _cat, decoration: const InputDecoration(labelText: 'Category'))),
              ]),
              Wrap(spacing: 6, children: [
                for (final c in widget.categories) ActionChip(label: Text(c, style: const TextStyle(fontSize: 12)), onPressed: () => setState(() => _cat.text = c)),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                if (_img.isNotEmpty) ...[
                  ClipRRect(borderRadius: BorderRadius.circular(6), child: Image.network(_img, width: 48, height: 48, fit: BoxFit.cover)),
                  const SizedBox(width: 8),
                ],
                OutlinedButton.icon(
                    onPressed: _uploading ? null : _photo,
                    icon: const Icon(Icons.photo_outlined),
                    label: Text(_uploading ? 'Uploading…' : (_img.isEmpty ? 'Add photo' : 'Change photo'))),
                if (_img.isNotEmpty) TextButton(onPressed: () => setState(() => _img = ''), child: const Text('Remove photo')),
              ]),
              if (_err != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_err!, style: TextStyle(color: Colors.red.shade700))),
            ]),
          ),
        ),
        actions: [
          if (widget.part != null)
            TextButton(
                onPressed: () => Navigator.pop(context, {'_delete': true}),
                child: Text('Delete part', style: TextStyle(color: Colors.red.shade700))),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: _done, child: const Text('Done')),
        ],
      );
}
