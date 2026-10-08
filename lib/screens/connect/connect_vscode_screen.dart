import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../../constants/app_colors.dart';

/// Flip to true once the extension is published on the VS Code Marketplace. The page then leads with one click
/// ("Install from Marketplace") and keeps the file download as the fallback.
const marketplaceLive = false;
const extensionId = 'altrobyte.altrobyte-trainer';
const vsixName = 'altrobyte-trainer-win32-x64.vsix';

/// Public page: how a learner connects VS Code to Altrobyte, once. Shared by a link, so it needs no sign-in.
class ConnectVsCodeScreen extends StatefulWidget {
  const ConnectVsCodeScreen({super.key});

  @override
  State<ConnectVsCodeScreen> createState() => _ConnectVsCodeScreenState();
}

class _ConnectVsCodeScreenState extends State<ConnectVsCodeScreen> {
  Map<String, dynamic>? _latest;

  @override
  void initState() {
    super.initState();
    () async {
      try {
        final r = await http.get(Uri.base.resolve('/downloads/latest.json'));
        if (r.statusCode == 200) _latest = Map<String, dynamic>.from(jsonDecode(r.body) as Map);
      } catch (_) {}
      if (mounted) setState(() {});
    }();
  }

  Future<void> _open(Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication).catchError((_) => false);
    if (!ok && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open that. Copy the link and open it yourself.')));
  }

  Widget _step(int n, String title, List<Widget> children) => Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: Colors.black.withValues(alpha: 0.08))),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              CircleAvatar(radius: 14, backgroundColor: AppColors.primary, child: Text('$n', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15.5))),
            ]),
            const SizedBox(height: 12),
            ...children,
          ]),
        ),
      );

  Widget _p(String t) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(t, style: GoogleFonts.inter(height: 1.55, color: AppColors.textSecondary)));

  @override
  Widget build(BuildContext context) {
    final latest = _latest;
    final mb = latest == null ? null : ((latest['size'] as num) / 1e6).toStringAsFixed(0);
    final command = 'code --install-extension $vsixName';
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(backgroundColor: AppColors.primary, iconTheme: const IconThemeData(color: Colors.white), title: Text('Connect VS Code', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(padding: const EdgeInsets.all(16), children: [
            Text('Do your experiments with the Altrobyte AI Lab assistant', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 21)),
            const SizedBox(height: 8),
            _p('A one-time setup. After this, the "Start in VS Code" button on your module opens the assistant for you. Windows 10 or 11 (64-bit).'),
            const SizedBox(height: 8),
            _step(1, 'Install VS Code', [
              _p('Skip this if you already have it.'),
              OutlinedButton.icon(onPressed: () => _open(Uri.parse('https://code.visualstudio.com/download')), icon: const Icon(Icons.download_rounded), label: const Text('Get VS Code')),
            ]),
            _step(2, 'Add the Altrobyte extension', [
              if (marketplaceLive) ...[
                ElevatedButton.icon(
                  onPressed: () => _open(Uri.parse('vscode:extension/$extensionId')),
                  icon: const Icon(Icons.extension_rounded),
                  label: const Text('Install from VS Code Marketplace'),
                ),
                _p('Or search "Altrobyte AI Trainer" in the Extensions view (Ctrl+Shift+X).'),
                const Divider(height: 24),
                Text('No Marketplace? Use the file instead', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 8),
              ],
              ElevatedButton.icon(
                onPressed: () => _open(Uri.base.resolve('/downloads/$vsixName')),
                icon: const Icon(Icons.download_rounded),
                label: Text(mb == null ? 'Download the extension file' : 'Download the extension file ($mb MB)'),
              ),
              const SizedBox(height: 10),
              _p('Then in VS Code: open Extensions (Ctrl+Shift+X), click the "⋯" menu at the top of that panel, choose "Install from VSIX…" and pick the file you downloaded.'),
              if (!marketplaceLive) ...[
                _p('Or from a terminal, in the folder where you saved it:'),
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                  decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(8)),
                  child: Row(children: [
                    Expanded(child: SelectableText(command, style: GoogleFonts.robotoMono(color: const Color(0xFFD4D4D4), fontSize: 12.5))),
                    IconButton(
                      tooltip: 'Copy',
                      icon: const Icon(Icons.copy_rounded, size: 18, color: Colors.white70),
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: command));
                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied')));
                      },
                    ),
                  ]),
                ),
              ],
              if (latest != null) ...[
                const SizedBox(height: 10),
                Text('Version ${latest['version']}. SHA-256: ${latest['sha256']}', style: GoogleFonts.robotoMono(fontSize: 10.5, color: Colors.black45)),
              ],
            ]),
            _step(3, 'Start', [
              _p('Go to your module on altrobytelab.com and press "Start in VS Code". Or open VS Code, click the Altrobyte robot icon on the left, sign in with your WhatsApp number and press "Experiments".'),
              _p('There is nothing else to install: the extension carries its own Python. To build and upload to your board it also needs the PlatformIO extension, and it will tell you if that is missing.'),
            ]),
            _p('Your code stays on your computer. The assistant asks before it builds or uploads, and you can see everything it did.'),
          ]),
        ),
      ),
    );
  }
}
