import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../constants/app_colors.dart';
import '../../services/api_service.dart';

/// Full-screen QR for an institute to display; students scan it to check in.
/// The token rotates daily, so a screenshot stops working tomorrow.
class QrDisplayScreen extends StatefulWidget {
  final int batchId;
  final String batchName;
  const QrDisplayScreen({super.key, required this.batchId, required this.batchName});

  @override
  State<QrDisplayScreen> createState() => _QrDisplayScreenState();
}

class _QrDisplayScreenState extends State<QrDisplayScreen> {
  final GlobalKey _qrKey = GlobalKey();
  String? _payload;
  String? _error;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ApiService.getQrToken(widget.batchId);
      if (!mounted) return;
      setState(() {
        _payload = data['payload'] as String?;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _saveQr() async {
    setState(() => _saving = true);
    try {
      final boundary =
          _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw 'QR not ready';
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw 'Could not render image';
      final file = XFile.fromData(
        bytes.buffer.asUint8List(),
        name: 'attendance-qr-${widget.batchName}.png',
        mimeType: 'image/png',
      );
      await Share.shareXFiles([file],
          text: 'Attendance QR — ${widget.batchName}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Save failed: $e')));
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text('Attendance QR',
            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loading ? null : _load,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Center(
        child: _loading
            ? const CircularProgressIndicator(color: Colors.white)
            : _error != null
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70)),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(widget.batchName,
                          style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('Students: scan this to mark attendance',
                          style: GoogleFonts.inter(color: Colors.white70, fontSize: 13)),
                      const SizedBox(height: 28),
                      RepaintBoundary(
                        key: _qrKey,
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              QrImageView(
                                data: _payload ?? '',
                                version: QrVersions.auto,
                                size: 260,
                                gapless: false,
                              ),
                              const SizedBox(height: 8),
                              Text(widget.batchName,
                                  style: GoogleFonts.poppins(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text('Permanent code — save it & put up in class',
                          style: GoogleFonts.inter(
                              color: Colors.white70, fontSize: 12)),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.primary),
                        onPressed: _saving ? null : _saveQr,
                        icon: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.download_rounded),
                        label: const Text('Save / Share QR'),
                      ),
                    ],
                  ),
      ),
    );
  }
}
