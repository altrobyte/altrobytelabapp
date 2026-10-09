// Paying for a programme plan, after enrolling.
//
// The amounts come from the server (fee, GST, total): this page never works a price out. Payment is by UPI to the business's own
// UPI id: scan the QR, or open a UPI app on the phone. The student then types the reference from their receipt, which the team
// checks against the bank. Typing a reference proves nothing by itself, and the page says so.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../constants/app_colors.dart';

/// ₹21,240 in the Indian style.
String rupees(num n) {
  final s = n.round().toString();
  if (s.length <= 3) return '₹$s';
  var head = s.substring(0, s.length - 3);
  final tail = s.substring(s.length - 3);
  final parts = <String>[];
  while (head.length > 2) {
    parts.insert(0, head.substring(head.length - 2));
    head = head.substring(0, head.length - 2);
  }
  if (head.isNotEmpty) parts.insert(0, head);
  return '₹${parts.join(',')},$tail';
}

/// The lines of the bill, top to bottom: what the plan costs, the tax, and what to pay.
List<(String, String)> billLines(Map<String, dynamic> c) {
  final rate = (c['gst_rate'] as num?) ?? 0;
  final shown = rate == rate.roundToDouble() ? rate.round().toString() : rate.toString();
  return [
    ('${c['name']} (${c['tag']}), ${c['period']}', rupees((c['fee'] as num?) ?? 0)),
    ('GST $shown%', rupees((c['gst'] as num?) ?? 0)),
    ('Total to pay', rupees((c['total'] as num?) ?? 0)),
  ];
}

/// A short summary of the plan being enrolled in, shown above the form.
class PlanBanner extends StatelessWidget {
  final Map<String, dynamic> checkout;
  const PlanBanner({super.key, required this.checkout});

  @override
  Widget build(BuildContext context) {
    final c = checkout;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFFFFF6CC), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFFFD21F))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('You are enrolling in', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 2),
        Text('${c['name']}: ${c['tag']}', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 17)),
        const SizedBox(height: 2),
        Text('${rupees((c['fee'] as num?) ?? 0)} ${c['period']} + GST  =  ${rupees((c['total'] as num?) ?? 0)} to pay',
            style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text('Step 1: fill this form. Step 2: pay. It takes about two minutes.', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
      ]),
    );
  }
}

class PlanPaySection extends StatefulWidget {
  final Map<String, dynamic> checkout;

  /// Sends the payment reference. Returns the confirmation to show, or throws with the reason.
  final Future<String> Function(String reference) onPaid;

  /// Opens WhatsApp to ask for help paying (or for the payment details when no UPI id is set). Null hides the button.
  final VoidCallback? onWhatsApp;
  const PlanPaySection({super.key, required this.checkout, required this.onPaid, this.onWhatsApp});

  @override
  State<PlanPaySection> createState() => _PlanPaySectionState();
}

class _PlanPaySectionState extends State<PlanPaySection> {
  final _ref = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _confirmed;

  @override
  void dispose() {
    _ref.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      _confirmed = await widget.onPaid(_ref.text.trim());
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _openUpi(String link) async {
    final ok = await launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication).catchError((_) => false);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No UPI app opened. Scan the QR code with your phone instead.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.checkout;
    final link = '${c['upi_link'] ?? ''}';
    final upiId = '${c['upi_id'] ?? ''}';
    final lines = billLines(c);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Step 2: pay to confirm your seat', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 17)),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.black.withValues(alpha: 0.08))),
        child: Column(children: [
          for (var i = 0; i < lines.length; i++) ...[
            if (i == lines.length - 1) const Divider(height: 18),
            Row(children: [
              Expanded(child: Text(lines[i].$1, style: GoogleFonts.inter(fontSize: 13.5, fontWeight: i == lines.length - 1 ? FontWeight.w700 : FontWeight.w400))),
              Text(lines[i].$2, style: GoogleFonts.poppins(fontSize: i == lines.length - 1 ? 18 : 14, fontWeight: i == lines.length - 1 ? FontWeight.w800 : FontWeight.w500)),
            ]),
            if (i < lines.length - 2) const SizedBox(height: 6),
          ],
        ]),
      ),
      const SizedBox(height: 16),
      if (_confirmed != null)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            const Icon(Icons.check_circle_rounded, color: AppColors.success),
            const SizedBox(width: 10),
            Expanded(child: Text(_confirmed!, style: GoogleFonts.inter(height: 1.45, fontWeight: FontWeight.w600))),
          ]),
        )
      else if (link.isEmpty) ...[
        Text('We will send you the payment details on WhatsApp. Your enrolment is saved.', textAlign: TextAlign.center, style: GoogleFonts.inter(height: 1.5)),
        if (widget.onWhatsApp != null) ...[
          const SizedBox(height: 10),
          Center(child: ElevatedButton.icon(onPressed: widget.onWhatsApp, icon: const Icon(Icons.send_rounded, size: 18), label: const Text('Ask for payment details on WhatsApp'))),
        ],
      ] else ...[
        Center(
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.black.withValues(alpha: 0.1))),
            child: QrImageView(data: link, size: 190, backgroundColor: Colors.white),
          ),
        ),
        const SizedBox(height: 8),
        Text('Scan with any UPI app (GPay, PhonePe, Paytm). The amount is filled in for you.',
            textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textSecondary, height: 1.45)),
        const SizedBox(height: 10),
        Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
          OutlinedButton.icon(onPressed: () => _openUpi(link), icon: const Icon(Icons.phone_android_rounded, size: 18), label: const Text('Pay with a UPI app on this phone')),
          if (upiId.isNotEmpty)
            TextButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: upiId));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('UPI ID copied')));
              },
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: Text('UPI ID: $upiId'),
            ),
        ]),
        const SizedBox(height: 18),
        Text('After paying, enter the reference from your receipt', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13.5)),
        const SizedBox(height: 6),
        TextField(
          controller: _ref,
          decoration: InputDecoration(
            labelText: 'UPI reference / UTR / transaction ID',
            hintText: 'e.g. 412345678901',
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: GoogleFonts.inter(color: AppColors.error, fontSize: 13))),
        const SizedBox(height: 10),
        ElevatedButton(
          onPressed: _busy ? null : _send,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
          child: Text(_busy ? 'Sending…' : 'I have paid', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 6),
        Text('We check it against our bank and confirm your seat on WhatsApp.',
            textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary, height: 1.45)),
        if (widget.onWhatsApp != null) Center(child: TextButton(onPressed: widget.onWhatsApp, child: const Text('Need help paying? Ask on WhatsApp'))),
      ],
    ]);
  }
}
