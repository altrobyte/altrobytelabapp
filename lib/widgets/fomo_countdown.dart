import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

/// Decorative urgency countdown for a promo/coupon — loops forever once it
/// hits zero so it always reads as "hurry up" and never looks broken or
/// expired. Not tied to any real backend deadline; purely a marketing FOMO
/// cue shown alongside the coupon field.
class FomoCountdown extends StatefulWidget {
  final Duration initial;
  final String label;
  const FomoCountdown({
    super.key,
    this.initial = const Duration(hours: 2, minutes: 3, seconds: 4),
    this.label = 'Offer ends in',
  });

  @override
  State<FomoCountdown> createState() => _FomoCountdownState();
}

class _FomoCountdownState extends State<FomoCountdown> {
  late Duration _remaining = widget.initial;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _remaining -= const Duration(seconds: 1);
        if (_remaining.inSeconds <= 0) _remaining = widget.initial;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final h = _remaining.inHours;
    final m = _remaining.inMinutes % 60;
    final s = _remaining.inSeconds % 60;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.local_fire_department_rounded, size: 15, color: AppColors.error),
        const SizedBox(width: 6),
        Text('${widget.label} ',
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.error, fontWeight: FontWeight.w600)),
        Text('${_two(h)}:${_two(m)}:${_two(s)}',
            style: GoogleFonts.robotoMono(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.error)),
      ]),
    );
  }
}
