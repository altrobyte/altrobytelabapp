import 'dart:html' as html;
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/app_colors.dart';

/// The card a student posts after registering.
///
/// This is the only piece of the product that travels on its own. Nobody
/// forwards a confirmation email, but a good card gets put on a LinkedIn feed
/// where a few hundred classmates see it — so it has to carry enough to be
/// worth posting and enough for a stranger to know what it is.
///
/// Which is why it names where they study or work. "Registered for Embedded
/// Systems" says nothing to their network; "3rd year · IIT Indore" tells the
/// rest of that college it is for them too.
Future<void> showRegistrationSuccessDialog(
  BuildContext context, {
  required String typeLabel, // "WORKSHOP", "PROGRAM", "EVENT"
  required String title,
  String? studentName,
  String? extraLine, // host name, or anything about the session itself
  /// College or company — whichever they gave.
  String? affiliation,
  /// "student" or "professional".
  String? occupation,
  /// Registered, but the fee is still owed.
  bool payLater = false,
  /// Where the card points the people who see it.
  String shareUrl = 'https://altrobytelab.com',
}) {
  return showDialog(
    context: context,
    builder: (_) => _SuccessDialog(
      typeLabel: typeLabel,
      title: title,
      studentName: studentName,
      extraLine: extraLine,
      affiliation: affiliation,
      occupation: occupation,
      payLater: payLater,
      shareUrl: shareUrl,
    ),
  );
}

class _SuccessDialog extends StatefulWidget {
  final String typeLabel;
  final String title;
  final String? studentName;
  final String? extraLine;
  final String? affiliation;
  final String? occupation;
  final bool payLater;
  final String shareUrl;

  const _SuccessDialog({
    required this.typeLabel,
    required this.title,
    this.studentName,
    this.extraLine,
    this.affiliation,
    this.occupation,
    this.payLater = false,
    required this.shareUrl,
  });

  @override
  State<_SuccessDialog> createState() => _SuccessDialogState();
}

class _SuccessDialogState extends State<_SuccessDialog> {
  final _cardKey = GlobalKey();
  bool _busy = false;
  String _note = '';

  /// The words that travel with the picture.
  ///
  /// Written to be posted as-is, because anything a student has to rewrite
  /// before posting does not get posted.
  String get _caption {
    final where = (widget.affiliation ?? '').trim();
    final lines = <String>[
      'Just registered for ${widget.title} with Altrobyte Lab 🚀',
      if (where.isNotEmpty) '',
      if (where.isNotEmpty) 'Building real embedded and IoT skills alongside $where.',
      '',
      'If you are into electronics, hardware or embedded systems, take a look:',
      widget.shareUrl,
      '',
      '#EmbeddedSystems #IoT #Electronics #AltrobyteLab',
    ];
    return lines.join('\n');
  }

  Future<Uint8List> _render() async {
    final boundary =
        _cardKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 3);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  String get _fileName {
    final safe = widget.title
        .replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_')
        .toLowerCase();
    return 'altrobytelab_$safe.png';
  }

  Future<void> _download() async {
    setState(() => _busy = true);
    try {
      final bytes = await _render();
      final blob = html.Blob([bytes], 'image/png');
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', _fileName)
        ..click();
      html.Url.revokeObjectUrl(url);
      _say('Saved to your downloads');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// The phone's own share sheet, which is the only route that can hand an
  /// image straight to Instagram.
  ///
  /// Instagram has no web link that accepts a picture, so "share to Instagram"
  /// can only ever mean this on a phone, or save-and-post on a desktop. Saying
  /// that plainly beats a button that silently does nothing.
  Future<bool> _shareSheet() async {
    try {
      final navigator = html.window.navigator as JSObject;
      if (!navigator.has('share')) return false;

      final bytes = await _render();
      final blob = html.Blob([bytes], 'image/png');
      final file = html.File([blob], _fileName, {'type': 'image/png'});

      final data = JSObject();
      data.setProperty('files'.toJS, [file].jsify()!);
      data.setProperty('text'.toJS, _caption.toJS);
      data.setProperty('title'.toJS, 'Altrobyte Lab'.toJS);

      if (navigator.has('canShare')) {
        final ok = navigator.callMethod<JSBoolean>('canShare'.toJS, data);
        if (!ok.toDart) return false;
      }
      await (navigator.callMethod<JSPromise>('share'.toJS, data)).toDart;
      return true;
    } catch (_) {
      // A cancelled share throws exactly like a failed one. Falling back to a
      // download would then hand somebody a file they did not ask for, so
      // treat it as handled either way.
      return true;
    }
  }

  Future<void> _shareTo(_Channel channel) async {
    setState(() => _busy = true);
    try {
      // Instagram accepts nothing over a link, and WhatsApp and LinkedIn both
      // take text but not an image — so on any device with a share sheet that
      // is the better route for all three.
      if (channel == _Channel.instagram || await _shareSheet()) {
        if (channel == _Channel.instagram) {
          await _download();
          await Clipboard.setData(ClipboardData(text: _caption));
          _say('Image saved and caption copied — open Instagram and post it');
        }
        return;
      }

      final text = Uri.encodeComponent(_caption);
      final uri = switch (channel) {
        _Channel.whatsapp => Uri.parse('https://wa.me/?text=$text'),
        _Channel.linkedin => Uri.parse(
            'https://www.linkedin.com/sharing/share-offsite/?url=${Uri.encodeComponent(widget.shareUrl)}'),
        _Channel.instagram => Uri.parse(widget.shareUrl),
      };
      await launchUrl(uri, mode: LaunchMode.externalApplication);

      if (channel == _Channel.linkedin) {
        // LinkedIn's share dialog takes a URL and writes its own preview, so
        // the words have to arrive by clipboard for them to paste.
        await Clipboard.setData(ClipboardData(text: _caption));
        _say('Caption copied — paste it into your LinkedIn post');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _say(String message) {
    if (!mounted) return;
    setState(() => _note = message);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            RepaintBoundary(
              key: _cardKey,
              child: _ShareCard(
                typeLabel: widget.typeLabel,
                title: widget.title,
                studentName: widget.studentName,
                extraLine: widget.extraLine,
                affiliation: widget.affiliation,
                occupation: widget.occupation,
              ),
            ),
            const SizedBox(height: 14),
            if (widget.payLater) _payLaterNote(),
            _shareRow(),
            const SizedBox(height: 10),
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
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      padding: const EdgeInsets.symmetric(vertical: 13)),
                  onPressed: _busy ? null : _download,
                  icon: _busy
                      ? const SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.download_rounded, size: 17),
                  label: const Text('Download'),
                ),
              ),
            ]),
            if (_note.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(_note,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                      fontSize: 12, height: 1.4, color: Colors.white70)),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _payLaterNote() => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(children: [
          const Icon(Icons.schedule_rounded,
              size: 17, color: AppColors.warning),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
                'Your seat is held. Pay before the session starts and the '
                'joining link comes to you on WhatsApp.',
                style: GoogleFonts.inter(
                    fontSize: 11.5, height: 1.45, color: Colors.white)),
          ),
        ]),
      );

  Widget _shareRow() => Row(children: [
        Expanded(
          child: _shareButton('WhatsApp', Icons.chat_rounded,
              const Color(0xFF25D366), _Channel.whatsapp),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _shareButton('LinkedIn', Icons.work_rounded,
              const Color(0xFF0A66C2), _Channel.linkedin),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _shareButton('Instagram', Icons.camera_alt_rounded,
              const Color(0xFFD62976), _Channel.instagram),
        ),
      ]);

  Widget _shareButton(
          String label, IconData icon, Color colour, _Channel channel) =>
      FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: colour,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: _busy ? null : () => _shareTo(channel),
        icon: Icon(icon, size: 15),
        label: FittedBox(
          child: Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 12, fontWeight: FontWeight.w600)),
        ),
      );
}

enum _Channel { whatsapp, linkedin, instagram }

/// The picture itself.
///
/// Held to a fixed aspect close to a portrait post, because a card that is
/// cropped by the platform it was made for is worse than no card.
class _ShareCard extends StatelessWidget {
  final String typeLabel;
  final String title;
  final String? studentName;
  final String? extraLine;
  final String? affiliation;
  final String? occupation;

  const _ShareCard({
    required this.typeLabel,
    required this.title,
    this.studentName,
    this.extraLine,
    this.affiliation,
    this.occupation,
  });

  /// "3rd year · IIT Indore" or "Engineer at Bosch" — the line that makes the
  /// card mean something to the people who see it rather than only its owner.
  String get _who {
    final where = (affiliation ?? '').trim();
    final role = (occupation ?? '').trim().toLowerCase();
    if (where.isEmpty) {
      return role == 'professional' ? 'Working professional' : 'Student';
    }
    return role == 'professional' ? 'Working at $where' : where;
  }

  @override
  Widget build(BuildContext context) {
    final today = DateFormat('d MMMM yyyy').format(DateTime.now());
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0B2450), AppColors.primary, Color(0xFF7A2E06)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(children: [
          // A soft light behind the badge, so the card has some depth in a
          // feed full of flat screenshots.
          Positioned(
            top: -70,
            right: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent.withValues(alpha: 0.22),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(26, 28, 26, 22),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: Image.asset('assets/images/logo.png',
                      width: 26, height: 26, fit: BoxFit.cover),
                ),
                const SizedBox(width: 8),
                Text('AltrobyteLab',
                    style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(6)),
                  child: Text(typeLabel,
                      style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.7)),
                ),
              ]),
              const SizedBox(height: 26),
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3), width: 1.5),
                ),
                child:
                    const Icon(Icons.check_rounded, color: Colors.white, size: 32),
              ),
              const SizedBox(height: 16),
              Text("I'm in.",
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 26,
                      height: 1.1,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text('Registered for',
                  style: GoogleFonts.inter(
                      color: Colors.white70, fontSize: 12.5)),
              const SizedBox(height: 8),
              Text(title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      height: 1.3)),
              if ((extraLine ?? '').isNotEmpty) ...[
                const SizedBox(height: 7),
                Text(extraLine!,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                        color: Colors.white70, fontSize: 12.5)),
              ],
              const SizedBox(height: 22),
              Container(height: 1, color: Colors.white.withValues(alpha: 0.22)),
              const SizedBox(height: 16),
              if ((studentName ?? '').trim().isNotEmpty)
                Text(studentName!.trim(),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(_who,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                      color: Colors.white.withValues(alpha: 0.86),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 14),
              Text(today,
                  style: GoogleFonts.inter(
                      color: Colors.white54, fontSize: 11)),
              const SizedBox(height: 14),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('altrobytelab.com',
                    style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
