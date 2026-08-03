import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';

/// Full-screen code snippet viewer for students — plain monospace text
/// with a one-tap copy button. Deliberately not HTML (unlike notes), so
/// there's no markup/XSS surface to worry about; it's just displayed and
/// copied as-is into the student's own IDE/Arduino sketch.
class CodeViewerScreen extends StatelessWidget {
  final String title;
  final String code;
  final String moduleColor;

  const CodeViewerScreen({
    super.key,
    required this.title,
    required this.code,
    this.moduleColor = '#7C4DFF',
  });

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _parseColor(moduleColor);

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: AppBar(
        backgroundColor: color,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(title,
            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_rounded, color: Colors.white),
            tooltip: 'Copy code',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Code copied to clipboard')),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: SelectableText(
          code,
          style: GoogleFonts.robotoMono(color: const Color(0xFFD4D4D4), fontSize: 13, height: 1.6),
        ),
      ),
    );
  }
}
