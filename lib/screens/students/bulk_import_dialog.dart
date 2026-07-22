import 'dart:async';
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:csv/csv.dart';
import 'package:provider/provider.dart';
import 'package:spreadsheet_decoder/spreadsheet_decoder.dart';
import '../../constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/institute_provider.dart';
import '../../services/api_service.dart';

class BulkImportDialog extends StatefulWidget {
  final VoidCallback? onImported;

  const BulkImportDialog({super.key, this.onImported});

  @override
  State<BulkImportDialog> createState() => _BulkImportDialogState();
}

enum _ImportStep { upload, preview, result }

class _BulkImportDialogState extends State<BulkImportDialog> {
  _ImportStep _step = _ImportStep.upload;
  List<Map<String, dynamic>> _parsedStudents = [];
  bool _importing = false;
  String? _error;
  String? _fileName;

  int _inserted = 0;
  int _skipped = 0;
  List<String> _errors = [];

  // Column headers user can use (shown in hint)
  static const _columns = 'name, phone, email, batch, parent_phone, address, fee_amount, fee_due_date';

  void _downloadSample() {
    const sampleCsv =
        'name,phone,email,batch,parent_phone,address,fee_amount,fee_due_date\n'
        'Rahul Sharma,9876543210,rahul@gmail.com,Batch A,9876543200,Indore MP,1500,2025-07-01\n'
        'Priya Patel,9876543211,priya@gmail.com,Batch A,9876543201,Bhopal MP,1500,2025-07-01\n'
        'Amit Yadav,9876543212,,Batch B,9876543202,Kalapipal,,\n';

    final bytes = utf8.encode(sampleCsv);
    final blob = html.Blob([bytes], 'text/csv');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', 'students_sample.csv')
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  Future<void> _pickFile() async {
    try {
      final input = html.FileUploadInputElement()
        ..accept = '.csv,.xlsx,.xls'
        ..multiple = false;
      input.click();

      await input.onChange.first;
      final file = input.files?.first;
      if (file == null) return;

      _fileName = file.name;
      final ext = _fileName!.split('.').last.toLowerCase();

      final reader = html.FileReader();
      if (ext == 'csv') {
        reader.readAsText(file);
      } else {
        reader.readAsArrayBuffer(file);
      }

      await reader.onLoad.first;

      if (ext == 'csv') {
        final content = reader.result as String;
        _parseCsv(content);
      } else if (ext == 'xlsx' || ext == 'xls') {
        final buffer = reader.result as ByteBuffer;
        _parseExcel(buffer.asUint8List());
      } else {
        setState(() => _error = 'Unsupported file type: .$ext');
      }
    } catch (e) {
      setState(() => _error = 'Error reading file: $e');
    }
  }

  Map<String, dynamic> _rowFromValues({
    required List headers,
    required List row,
  }) {
    String get(String key) {
      final idx = headers.indexOf(key);
      if (idx < 0 || idx >= row.length) return '';
      return (row[idx] ?? '').toString().trim();
    }

    // Accept both "batch" and old "batch_id" header
    final batchIdx = headers.indexOf('batch');
    final batchIdIdx = headers.indexOf('batch_id');
    final batchVal = batchIdx >= 0 && batchIdx < row.length
        ? (row[batchIdx] ?? '').toString().trim()
        : batchIdIdx >= 0 && batchIdIdx < row.length
            ? (row[batchIdIdx] ?? '').toString().trim()
            : '';

    return {
      'name': get('name'),
      'phone': get('phone'),
      'email': get('email'),
      'batch': batchVal,
      'parent_phone': get('parent_phone'),
      'address': get('address'),
      'fee_amount': get('fee_amount'),
      'fee_due_date': get('fee_due_date'),
    };
  }

  void _parseExcel(Uint8List bytes) {
    try {
      final decoder = SpreadsheetDecoder.decodeBytes(bytes);
      if (decoder.tables.isEmpty) {
        setState(() => _error = 'Excel file has no sheets');
        return;
      }
      final sheet = decoder.tables.values.first;
      if (sheet.rows.length < 2) {
        setState(() => _error = 'Excel must have at least a header row and one data row');
        return;
      }
      final headers = sheet.rows.first
          .map((h) => (h ?? '').toString().trim().toLowerCase())
          .toList();

      if (!headers.contains('name')) {
        setState(() => _error = 'File must have a "name" column in the first row');
        return;
      }

      final students = <Map<String, dynamic>>[];
      for (int i = 1; i < sheet.rows.length; i++) {
        final row = sheet.rows[i];
        final s = _rowFromValues(headers: headers, row: row);
        if ((s['name'] as String).isEmpty) continue;
        students.add(s);
      }

      if (students.isEmpty) {
        setState(() => _error = 'No valid student rows found in Excel');
        return;
      }
      setState(() { _parsedStudents = students; _step = _ImportStep.preview; _error = null; });
    } catch (e) {
      setState(() => _error = 'Could not parse Excel file: $e');
    }
  }

  void _parseCsv(String content) {
    try {
      final rows = const CsvToListConverter(eol: '\n').convert(content);
      if (rows.length < 2) {
        setState(() => _error = 'File must have at least a header row and one data row');
        return;
      }
      final headers = rows.first.map((h) => h.toString().trim().toLowerCase()).toList();
      if (!headers.contains('name')) {
        setState(() => _error = 'CSV must have a "name" column');
        return;
      }
      final students = <Map<String, dynamic>>[];
      for (int i = 1; i < rows.length; i++) {
        final s = _rowFromValues(headers: headers, row: rows[i]);
        if ((s['name'] as String).isEmpty) continue;
        students.add(s);
      }
      if (students.isEmpty) {
        setState(() => _error = 'No valid student rows found');
        return;
      }
      setState(() { _parsedStudents = students; _step = _ImportStep.preview; _error = null; });
    } catch (e) {
      setState(() => _error = 'Could not parse CSV: $e');
    }
  }

  Future<void> _import() async {
    final auth = context.read<AuthProvider>();
    if (auth.instituteId == null) return;
    setState(() => _importing = true);
    try {
      final result = await ApiService.bulkImportStudents(auth.instituteId!, _parsedStudents);
      // Invalidate students + fees cache so screens refresh
      if (mounted) {
        context.read<InstituteProvider>().ensureStudents(auth.instituteId!, force: true);
      }
      final errs = List<String>.from(result['errors'] ?? []);
      // If everything skipped and no explicit errors, show raw response as debug
      final ins = result['inserted'] ?? 0;
      final skp = result['skipped'] ?? 0;
      if (ins == 0 && skp > 0 && errs.isEmpty) {
        errs.add('All rows skipped — check batch name matches exactly and file format is correct.');
      }
      setState(() {
        _inserted = ins;
        _skipped = skp;
        _errors = errs;
        _step = _ImportStep.result;
      });
      widget.onImported?.call();
    } catch (e) {
      setState(() => _error = e.toString());
    }
    setState(() => _importing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 620),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.upload_file_rounded, color: AppColors.accent, size: 24),
                const SizedBox(width: 10),
                Text('Import Students',
                    style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ]),
              const SizedBox(height: 16),
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(children: [
                    const Icon(Icons.error_outline, color: AppColors.error, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!,
                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.error))),
                  ]),
                ),
                const SizedBox(height: 12),
              ],
              Flexible(child: _buildStep()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case _ImportStep.upload:   return _buildUploadStep();
      case _ImportStep.preview:  return _buildPreviewStep();
      case _ImportStep.result:   return _buildResultStep();
    }
  }

  Widget _buildUploadStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Columns (first row = header):',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(_columns,
                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              RichText(text: TextSpan(
                style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary),
                children: const [
                  TextSpan(text: '• ', style: TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(text: 'name'),
                  TextSpan(text: ' required. All others optional.\n'),
                  TextSpan(text: '• ', style: TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(text: 'batch'),
                  TextSpan(text: ' = batch name (e.g. "Batch A") — must match exactly.\n'),
                  TextSpan(text: '• ', style: TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(text: 'fee_amount'),
                  TextSpan(text: ' = creates a pending fee (e.g. 1500).\n'),
                  TextSpan(text: '• ', style: TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(text: 'fee_due_date'),
                  TextSpan(text: ' = YYYY-MM-DD format.'),
                ],
              )),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _downloadSample,
            icon: const Icon(Icons.download_rounded, size: 18),
            label: const Text('Download Sample CSV'),
          ),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: _pickFile,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 36),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.accent.withValues(alpha: 0.4), width: 2),
              borderRadius: BorderRadius.circular(12),
              color: AppColors.accent.withValues(alpha: 0.03),
            ),
            child: Column(children: [
              Icon(Icons.cloud_upload_rounded, size: 40,
                  color: AppColors.accent.withValues(alpha: 0.7)),
              const SizedBox(height: 10),
              Text(_fileName ?? 'Tap to upload CSV or Excel file',
                  style: GoogleFonts.inter(
                      fontSize: 14, color: AppColors.accent, fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Text('Supports .csv, .xlsx, .xls',
                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 18),
          const SizedBox(width: 8),
          Text('${_parsedStudents.length} students found',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          const Spacer(),
          TextButton(
            onPressed: () => setState(() { _step = _ImportStep.upload; _parsedStudents = []; }),
            child: const Text('Change file'),
          ),
        ]),
        const SizedBox(height: 8),
        Flexible(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade200),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _parsedStudents.length.clamp(0, 20),
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final s = _parsedStudents[i];
                final batch = (s['batch'] as String? ?? '').isNotEmpty ? s['batch'] as String : null;
                final fee = (s['fee_amount'] as String? ?? '').isNotEmpty ? '₹${s['fee_amount']}' : null;
                return ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    child: Text('${i + 1}',
                        style: const TextStyle(fontSize: 11, color: AppColors.primary)),
                  ),
                  title: Text(s['name'] ?? '',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500)),
                  subtitle: Text(
                    [
                      if ((s['phone'] as String? ?? '').isNotEmpty) s['phone'],
                      if (batch != null) '📋 $batch',
                      if (fee != null) '💰 $fee',
                    ].join('  •  '),
                    style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary),
                  ),
                );
              },
            ),
          ),
        ),
        if (_parsedStudents.length > 20)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('...and ${_parsedStudents.length - 20} more',
                style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
          ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.success,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: _importing ? null : _import,
            icon: _importing
                ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.upload_rounded, size: 18),
            label: Text('Import ${_parsedStudents.length} Students'),
          ),
        ),
      ],
    );
  }

  Widget _buildResultStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          _inserted > 0 ? Icons.check_circle_rounded : Icons.info_outline_rounded,
          size: 48,
          color: _inserted > 0 ? AppColors.success : AppColors.accent,
        ),
        const SizedBox(height: 12),
        Text('Import Complete',
            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _ResultChip('$_inserted Added', AppColors.success),
          const SizedBox(width: 10),
          if (_skipped > 0) _ResultChip('$_skipped Skipped', AppColors.warning),
        ]),
        if (_errors.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _errors.take(5).map((e) => Text(e,
                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.warning))).toList(),
            ),
          ),
        ],
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ),
      ],
    );
  }
}

class _ResultChip extends StatelessWidget {
  final String label;
  final Color color;
  const _ResultChip(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
    );
  }
}
