import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../constants/app_colors.dart';

/// Shows a celebratory "registered!" dialog with a shareable card the
/// student can download as a PNG and post on social media.
Future<void> showRegistrationSuccessDialog(
  BuildContext context, {
  required String typeLabel, // e.g. "WORKSHOP", "PROGRAM", "EVENT"
  required String title,
  String? studentName,
  String? extraLine, // e.g. host name / company
}) {
  return showDialog(
    context: context,
    builder: (_) => _SuccessDialog(
      typeLabel: typeLabel,
      title: title,
      studentName: studentName,
      extraLine: extraLine,
    ),
  );
}

class _SuccessDialog extends StatefulWidget {
  final String typeLabel;
  final String title;
  final String? studentName;
  final String? extraLine;
  const _SuccessDialog({required this.typeLabel, required this.title, this.studentName, this.extraLine});

  @override
  State<_SuccessDialog> createState() => _SuccessDialogState();
}

class _SuccessDialogState extends State<_SuccessDialog> {
  final _cardKey = GlobalKey();
  bool _saving = false;

  Future<void> _download() async {
    setState(() => _saving = true);
    try {
      final boundary = _cardKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();
      _triggerDownload(bytes);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _triggerDownload(Uint8List bytes) {
    final blob = html.Blob([bytes], 'image/png');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final safeName = widget.title.replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_').toLowerCase();
    html.AnchorElement(href: url)
      ..setAttribute('download', 'altrobytelab_${safeName}_registration.png')
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          RepaintBoundary(
            key: _cardKey,
            child: _ShareCard(typeLabel: widget.typeLabel, title: widget.title,
                studentName: widget.studentName, extraLine: widget.extraLine),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white54),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent, padding: const EdgeInsets.symmetric(vertical: 13)),
                onPressed: _saving ? null : _download,
                icon: _saving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.download_rounded, size: 18),
                label: const Text('Download & Share'),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _ShareCard extends StatelessWidget {
  final String typeLabel;
  final String title;
  final String? studentName;
  final String? extraLine;
  const _ShareCard({required this.typeLabel, required this.title, this.studentName, this.extraLine});

  @override
  Widget build(BuildContext context) {
    final today = DateFormat('d MMMM yyyy').format(DateTime.now());
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.fromLTRB(28, 36, 28, 28),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary, AppColors.primaryLight, AppColors.accent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded, color: Colors.white, size: 36),
          ),
          const SizedBox(height: 16),
          Text('🎉 Congratulations!',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text("You've successfully registered for",
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
            child: Text(typeLabel,
                style: GoogleFonts.inter(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
          ),
          const SizedBox(height: 10),
          Text(title,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700, height: 1.3)),
          if ((extraLine ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(extraLine!,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: Colors.white70, fontSize: 13)),
          ],
          const SizedBox(height: 22),
          Container(height: 1, color: Colors.white24),
          const SizedBox(height: 16),
          if ((studentName ?? '').isNotEmpty) ...[
            Text(studentName!,
                style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
          ],
          Text(today, style: GoogleFonts.inter(color: Colors.white60, fontSize: 11.5)),
          const SizedBox(height: 18),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: Image.asset('assets/images/logo.png', width: 24, height: 24, fit: BoxFit.cover),
            ),
            const SizedBox(width: 8),
            Text('AltrobyteLab', style: GoogleFonts.poppins(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 2),
          Text('Started their learning journey',
              style: GoogleFonts.inter(color: Colors.white54, fontSize: 10.5, fontStyle: FontStyle.italic)),
        ]),
      ),
    );
  }
}
