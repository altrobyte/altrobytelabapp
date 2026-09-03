import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../constants/app_colors.dart';
import '../../services/api_service.dart';

/// Student scans the institute's QR to mark today's attendance.
class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _handled = false;
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handled || _submitting) return;
    final raw = capture.barcodes.isNotEmpty ? capture.barcodes.first.rawValue : null;
    if (raw == null || raw.isEmpty) return;

    Map<String, dynamic>? data;
    try {
      data = Map<String, dynamic>.from(jsonDecode(raw));
    } catch (_) {
      return; // not our QR; keep scanning
    }
    if (!data.containsKey('institute_id') || !data.containsKey('token')) return;

    setState(() {
      _handled = true;
      _submitting = true;
    });
    await _controller.stop();

    try {
      final res = await ApiService.qrCheckIn({
        'institute_id': data['institute_id'],
        'batch_id': data['batch_id'],
        'date': data['date'],
        'token': data['token'],
      });
      if (!mounted) return;
      final status = (res['status'] ?? '').toString();
      _showResult(
        success: true,
        message: (res['message'] ?? 'Attendance marked').toString(),
        already: status == 'already_marked',
      );
    } catch (e) {
      if (!mounted) return;
      _showResult(success: false, message: e.toString());
    }
  }

  void _showResult({required bool success, required String message, bool already = false}) {
    final color = !success
        ? AppColors.error
        : already
            ? Colors.orange
            : AppColors.success;
    final icon = !success
        ? Icons.error_outline_rounded
        : already
            ? Icons.info_outline_rounded
            : Icons.check_circle_rounded;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 56),
            const SizedBox(height: 16),
            Text(message,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500)),
          ],
        ),
        actions: [
          if (!success)
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                setState(() {
                  _handled = false;
                  _submitting = false;
                });
                _controller.start();
              },
              child: const Text('Try Again'),
            ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext); // dialog
              Navigator.pop(dialogContext); // scan screen
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('Scan to Check In',
            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          // Viewfinder
          Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 3),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          Positioned(
            bottom: 60,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _submitting ? 'Marking attendance...' : 'Point at your class QR code',
                style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
