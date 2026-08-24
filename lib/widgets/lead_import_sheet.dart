import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/api_constants.dart';
import '../services/api_service.dart';

/// Bringing a spreadsheet of leads into the contact list.
///
/// Two steps on purpose. A file is checked and reported on before anything is
/// written, because an import is the one operation where finding out
/// afterwards is too late — nobody un-merges four hundred contacts by hand.
class LeadImportSheet extends StatefulWidget {
  final VoidCallback onImported;
  const LeadImportSheet({super.key, required this.onImported});

  static Future<void> show(BuildContext context, VoidCallback onImported) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => LeadImportSheet(onImported: onImported),
      );

  @override
  State<LeadImportSheet> createState() => _LeadImportSheetState();
}

class _LeadImportSheetState extends State<LeadImportSheet> {
  PlatformFile? _file;
  Map<String, dynamic>? _preview;
  Map<String, dynamic>? _result;
  bool _busy = false;
  String _error = '';

  final _sheetUrl = TextEditingController();
  Map<String, dynamic>? _sheet;
  bool _sheetBusy = false;
  String _sheetError = '';
  String _sheetNote = '';

  @override
  void initState() {
    super.initState();
    _loadSheet();
  }

  @override
  void dispose() {
    _sheetUrl.dispose();
    super.dispose();
  }

  Future<void> _loadSheet() async {
    try {
      final r = await ApiService.getSheetStatus();
      if (!mounted) return;
      setState(() {
        _sheet = r;
        if ((r['sheet_url'] as String? ?? '').isNotEmpty) {
          _sheetUrl.text = r['sheet_url'] as String;
        }
      });
    } catch (_) {
      // The file upload above works with or without this; a failure here
      // should not take the whole sheet down with it.
    }
  }

  Future<void> _sheetAction(Future<Map<String, dynamic>> Function() run) async {
    setState(() {
      _sheetBusy = true;
      _sheetError = '';
      _sheetNote = '';
    });
    try {
      final r = await run();
      if (!mounted) return;
      final created = (r['created'] as int?) ?? (r['ready'] as int?) ?? 0;
      final updated = (r['updated'] as int?) ?? 0;
      final skipped = (r['unusable'] as int?) ?? 0;
      setState(() {
        _sheetNote = '$created new'
            '${updated > 0 ? ', $updated updated' : ''}'
            '${skipped > 0 ? ', $skipped skipped' : ''}';
      });
      await _loadSheet();
      widget.onImported();
    } catch (e) {
      if (mounted) {
        setState(() => _sheetError = e is ApiException ? e.message : '$e');
      }
    } finally {
      if (mounted) setState(() => _sheetBusy = false);
    }
  }

  Future<void> _pick() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv', 'txt'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return;
    setState(() {
      _file = picked.files.first;
      _preview = null;
      _result = null;
      _error = '';
    });
    await _check();
  }

  /// Upload with dry_run, so the report describes this exact file rather than
  /// a guess about it.
  Future<void> _send({required bool dryRun}) async {
    final f = _file;
    if (f == null || f.bytes == null) {
      setState(() => _error = 'Pick a CSV file first');
      return;
    }
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final uri = Uri.parse(
          '${ApiConstants.baseUrl}/crm/import?dry_run=$dryRun');
      final req = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer ${prefs.getString('token') ?? ''}'
        ..files.add(http.MultipartFile.fromBytes('file', f.bytes!,
            filename: f.name));
      final res = await http.Response.fromStream(
          await req.send().timeout(const Duration(seconds: 60)));
      final body = jsonDecode(res.body);
      if (res.statusCode >= 400) {
        throw ApiException(
            '${body['detail'] ?? 'Import failed'}', statusCode: res.statusCode);
      }
      if (!mounted) return;
      setState(() {
        if (dryRun) {
          _preview = Map<String, dynamic>.from(body);
        } else {
          _result = Map<String, dynamic>.from(body);
        }
      });
      if (!dryRun) widget.onImported();
    } catch (e) {
      if (mounted) {
        setState(() => _error = e is ApiException ? e.message : '$e');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _check() => _send(dryRun: true);
  Future<void> _import() => _send(dryRun: false);

  @override
  Widget build(BuildContext context) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 22),
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: _result != null ? _done() : _form(),
            ),
          ),
        ),
      );

  Widget _grab() => Center(
        child: Container(
          width: 38,
          height: 4,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
              color: const Color(0xFFD7DEE8),
              borderRadius: BorderRadius.circular(2)),
        ),
      );

  Widget _form() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _grab(),
          Text('Import leads',
              style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0B2450))),
          const SizedBox(height: 5),
          Text(
            'A CSV with a phone column. It can be called Phone, Mobile, '
            'Contact or WhatsApp — name and email are picked up if they are '
            'there. Everyone lands in the same list as your other leads.',
            style: GoogleFonts.inter(
                fontSize: 12.5, height: 1.55, color: const Color(0xFF5A6B82)),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: _busy ? null : _pick,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 22),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F9FC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFFE1E7F0), width: 1.4),
              ),
              child: Column(children: [
                Icon(_file == null
                        ? Icons.upload_file_rounded
                        : Icons.description_rounded,
                    size: 30, color: const Color(0xFF12326B)),
                const SizedBox(height: 8),
                Text(_file?.name ?? 'Choose a CSV file',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0B2450))),
                if (_file != null) ...[
                  const SizedBox(height: 2),
                  Text('Tap to choose a different one',
                      style: GoogleFonts.inter(
                          fontSize: 11, color: const Color(0xFF9AA5B5))),
                ],
              ]),
            ),
          ),
          if (_busy) ...[
            const SizedBox(height: 16),
            const Center(child: CircularProgressIndicator()),
          ],
          if (_error.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: const Color(0xFFC62828).withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.error_outline_rounded,
                    size: 16, color: Color(0xFFC62828)),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(_error,
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          height: 1.45,
                          color: const Color(0xFFC62828))),
                ),
              ]),
            ),
          ],
          const SizedBox(height: 22),
          _sheetSection(),
          if (_preview != null && !_busy) ...[
            const SizedBox(height: 18),
            _report(_preview!, preview: true),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: ((_preview!['ready'] as int?) ?? 0) == 0
                    ? null
                    : _import,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF12326B),
                  disabledBackgroundColor: const Color(0xFFD7DEE8),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.download_done_rounded,
                    size: 18, color: Colors.white),
                label: Text('Import ${_preview!['ready']} contacts',
                    style: GoogleFonts.poppins(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white)),
              ),
            ),
          ],
        ],
      );

  Widget _done() => Column(mainAxisSize: MainAxisSize.min, children: [
        _grab(),
        const Icon(Icons.check_circle_rounded,
            size: 46, color: Color(0xFF2E7D32)),
        const SizedBox(height: 12),
        Text('Imported',
            style: GoogleFonts.poppins(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF0B2450))),
        const SizedBox(height: 14),
        _report(_result!, preview: false),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => Navigator.pop(context),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF12326B),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Done',
                style: GoogleFonts.poppins(
                    fontSize: 14, fontWeight: FontWeight.w600)),
          ),
        ),
      ]);

  Widget _report(Map<String, dynamic> r, {required bool preview}) {
    final cols = (r['columns_used'] as Map?) ?? {};
    final problems = (r['problems'] as List?) ?? [];
    final unusable = (r['unusable'] as int?) ?? 0;
    final dupes = (r['duplicates_in_file'] as int?) ?? 0;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (cols.isNotEmpty) ...[
        Text('COLUMNS FOUND',
            style: GoogleFonts.inter(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: const Color(0xFF9AA5B5))),
        const SizedBox(height: 7),
        Wrap(spacing: 7, runSpacing: 7, children: [
          for (final e in cols.entries)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF12326B).withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text('${e.key} — ${e.value}',
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF12326B))),
            ),
        ]),
        const SizedBox(height: 14),
      ],
      Row(children: [
        _stat(preview ? 'Ready' : 'New',
            '${preview ? r['ready'] ?? 0 : r['created'] ?? 0}',
            const Color(0xFF2E7D32)),
        if (!preview)
          _stat('Updated', '${r['updated'] ?? 0}', const Color(0xFF12326B)),
        if (dupes > 0)
          _stat('Duplicates', '$dupes', const Color(0xFF9AA5B5)),
        if (unusable > 0)
          _stat('Skipped', '$unusable', const Color(0xFFE65100)),
      ]),
      if (dupes > 0) ...[
        const SizedBox(height: 10),
        Text(
          '$dupes ${dupes == 1 ? 'row was' : 'rows were'} the same person '
          'listed twice — merged into one contact.',
          style: GoogleFonts.inter(
              fontSize: 11.5, height: 1.45, color: const Color(0xFF5A6B82)),
        ),
      ],
      if (problems.isNotEmpty) ...[
        const SizedBox(height: 12),
        Text('SKIPPED ROWS',
            style: GoogleFonts.inter(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: const Color(0xFFE65100))),
        const SizedBox(height: 6),
        Container(
          constraints: const BoxConstraints(maxHeight: 150),
          decoration: BoxDecoration(
            color: const Color(0xFFE65100).withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(9),
          ),
          padding: const EdgeInsets.all(10),
          child: SingleChildScrollView(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Line numbers, so a skipped row can actually be found and
                  // fixed in the sheet it came from.
                  for (final p in problems)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(
                        'Line ${(p as Map)['line']}'
                        '${'${p['value'] ?? ''}'.isEmpty ? '' : ' — "${p['value']}"'}'
                        '  ·  ${p['reason']}',
                        style: GoogleFonts.inter(
                            fontSize: 11, color: const Color(0xFF5A6B82)),
                      ),
                    ),
                ]),
          ),
        ),
      ],
    ]);
  }

  Widget _stat(String label, String value, Color colour) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value,
              style: GoogleFonts.poppins(
                  fontSize: 21, fontWeight: FontWeight.w700, color: colour)),
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 11, color: const Color(0xFF9AA5B5))),
        ]),
      );

  /// A linked Google Sheet, pulled on a schedule.
  ///
  /// The sheet has to be readable by link. That is the whole setup — no
  /// service account, no consent screen — and it is also the one thing that
  /// goes wrong, so linking says so immediately rather than at the first
  /// silent empty sync.
  Widget _sheetSection() {
    final linked = _sheet?['linked'] == true;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE1E7F0)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.table_chart_rounded, size: 17, color: Color(0xFF0F9D58)),
          const SizedBox(width: 7),
          Text('Google Sheet',
              style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0B2450))),
          const Spacer(),
          if (linked)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF2E7D32).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('Linked',
                  style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF2E7D32))),
            ),
        ]),
        const SizedBox(height: 6),
        Text(
          linked
              ? 'Pulled automatically. Anything new in the sheet turns up here.'
              : 'Paste the sheet link. Share it as "Anyone with the link — '
                  'Viewer" first, or it cannot be read.',
          style: GoogleFonts.inter(
              fontSize: 11.5, height: 1.45, color: const Color(0xFF5A6B82)),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _sheetUrl,
          style: GoogleFonts.inter(fontSize: 12),
          decoration: InputDecoration(
            hintText: 'https://docs.google.com/spreadsheets/d/...',
            hintStyle: GoogleFonts.inter(
                fontSize: 12, color: const Color(0xFF9AA5B5)),
            filled: true,
            fillColor: Colors.white,
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 11, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(9),
              borderSide: const BorderSide(color: Color(0xFFE1E7F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(9),
              borderSide: const BorderSide(color: Color(0xFFE1E7F0)),
            ),
          ),
        ),
        if (_sheetError.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(_sheetError,
              style: GoogleFonts.inter(
                  fontSize: 11.5, height: 1.4, color: const Color(0xFFC62828))),
        ],
        if (_sheetNote.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(_sheetNote,
              style: GoogleFonts.inter(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF2E7D32))),
        ],
        if (linked && '${_sheet?['last_result'] ?? ''}'.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text('Last sync: ${_sheet!['last_result']}',
              style: GoogleFonts.inter(
                  fontSize: 10.5, color: const Color(0xFF9AA5B5))),
        ],
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: _sheetBusy
                  ? null
                  : () => _sheetAction(
                      () => ApiService.linkSheet(_sheetUrl.text.trim())),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0F9D58),
                disabledBackgroundColor: const Color(0xFFD7DEE8),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              icon: _sheetBusy
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.link_rounded, size: 16, color: Colors.white),
              label: Text(linked ? 'Relink' : 'Link sheet',
                  style: GoogleFonts.poppins(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.white)),
            ),
          ),
          if (linked) ...[
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _sheetBusy
                  ? null
                  : () => _sheetAction(ApiService.syncSheetNow),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.sync_rounded, size: 16),
              label: Text('Sync now',
                  style: GoogleFonts.inter(fontSize: 12.5)),
            ),
          ],
        ]),
      ]),
    );
  }

}
