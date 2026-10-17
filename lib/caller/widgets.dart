import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import 'models.dart';

const heatColors = {
  'hot': AppColors.error,
  'warm': AppColors.warning,
  'cold': AppColors.primaryLight,
  'customer': AppColors.success,
  'out': AppColors.textSecondary,
};

const heatLabels = {'hot': '🔥 Hot', 'warm': 'Warm', 'cold': 'Cold', 'customer': 'Customer', 'out': 'Out'};

class HeatBadge extends StatelessWidget {
  final Heat heat;
  final bool converted;
  const HeatBadge(this.heat, {super.key, this.converted = false});

  @override
  Widget build(BuildContext context) {
    final t = converted ? 'customer' : heat.temperature;
    final color = heatColors[t] ?? AppColors.textSecondary;
    final text = converted ? 'Converted 🎉' : '${heatLabels[t] ?? t} · ${heat.pct}%';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

class Tag extends StatelessWidget {
  final String text;
  final Color color;
  const Tag(this.text, {super.key, this.color = AppColors.primary});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
            border: Border.all(color: color.withValues(alpha: 0.35)), borderRadius: BorderRadius.circular(6)),
        child: Text(text, style: TextStyle(fontSize: 11.5, color: color, fontWeight: FontWeight.w600)),
      );
}

String duration(int s) => s < 60 ? '${s}s' : '${s ~/ 60}m ${(s % 60).toString().padLeft(2, '0')}s';
