import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../../constants/app_colors.dart';

/// What the page says about the installer, from the small file published next to it. Null when no installer is published
/// yet (the page then says so, instead of offering a download that does not exist).
class DesktopRelease {
  final String version;
  final String file;
  final int size;
  const DesktopRelease(this.version, this.file, this.size);

  static DesktopRelease? parse(String body) {
    try {
      final j = jsonDecode(body);
      if (j is! Map || j['file'] is! String || j['version'] is! String) return null;
      final file = j['file'] as String;
      if (file.contains('/') || file.contains('\\') || !file.toLowerCase().endsWith('.exe')) return null; // a file next to the page, nothing else
      return DesktopRelease(j['version'] as String, file, (j['size'] as num?)?.toInt() ?? 0);
    } catch (_) {
      return null;
    }
  }

  String get megabytes => (size / 1e6).toStringAsFixed(0);
}

/// Public page: the Windows app for learners. One download, one install; the app then checks the computer and guides the
/// learner through the rest, so nothing here asks them to install anything else.
class DownloadAppScreen extends StatefulWidget {
  const DownloadAppScreen({super.key});

  @override
  State<DownloadAppScreen> createState() => _DownloadAppScreenState();
}

class _DownloadAppScreenState extends State<DownloadAppScreen> {
  DesktopRelease? _release;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    () async {
      try {
        final r = await http.get(Uri.base.resolve('/downloads/desktop.json'));
        if (r.statusCode == 200) _release = DesktopRelease.parse(r.body);
      } catch (_) {}
      if (mounted) setState(() => _loaded = true);
    }();
  }

  Future<void> _download(DesktopRelease r) async {
    final ok = await launchUrl(Uri.base.resolve('/downloads/${r.file}'), mode: LaunchMode.externalApplication).catchError((_) => false);
    if (!ok && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not start the download. Try again.')));
  }

  Widget _step(int n, String title, String body) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(radius: 14, backgroundColor: AppColors.primary, child: Text('$n', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14.5)),
              const SizedBox(height: 2),
              Text(body, style: GoogleFonts.inter(height: 1.5, color: AppColors.textSecondary)),
            ]),
          ),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final r = _release;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(backgroundColor: AppColors.primary, iconTheme: const IconThemeData(color: Colors.white), title: Text('Get the Altrobyte app', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(padding: const EdgeInsets.all(16), children: [
            Text('Learn electronics with a trainer on your own laptop', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 21)),
            const SizedBox(height: 8),
            Text('No experience needed. The app starts from the very basics, checks your computer, installs what is missing with you, and then guides you through real experiments with your board. Windows 10 or 11 (64-bit).',
                style: GoogleFonts.inter(height: 1.55, color: AppColors.textSecondary)),
            const SizedBox(height: 18),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: Colors.black.withValues(alpha: 0.08))),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: !_loaded
                    ? const Center(child: CircularProgressIndicator())
                    : r == null
                        ? Text('The app is not published yet. Ask your trainer for the link, or check back soon.', style: GoogleFonts.inter(height: 1.5))
                        : Row(children: [
                            const Icon(Icons.desktop_windows_rounded, size: 34, color: AppColors.primary),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('Altrobyte Trainer for Windows', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                                Text('Version ${r.version}${r.size > 0 ? ' · ${r.megabytes} MB' : ''}', style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textSecondary)),
                              ]),
                            ),
                            ElevatedButton.icon(
                              onPressed: () => _download(r),
                              icon: const Icon(Icons.download_rounded),
                              label: const Text('Download'),
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14)),
                            ),
                          ]),
              ),
            ),
            const SizedBox(height: 22),
            _step(1, 'Download and open it', 'Double-click the file you downloaded. If Windows shows "protected your PC", choose More info, then Run anyway. It installs for you only; no administrator password.'),
            _step(2, 'Sign in', 'Use the same email and password as the Altrobyte website.'),
            _step(3, 'Start with the first course', 'It explains everything from scratch, then helps you set up your laptop one tool at a time. You never have to figure out what to install.'),
            _step(4, 'Your modules appear by themselves', 'Each experiment downloads only when you start it, so the app stays light.'),
          ]),
        ),
      ),
    );
  }
}
