import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../models/analytics_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/stats_card_widget.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  InstituteAnalytics? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load({bool force = false}) async {
    if (!force && _data != null) return;
    setState(() => _loading = true);
    final auth = context.read<AuthProvider>();
    if (auth.instituteId != null) {
      try {
        final raw = await ApiService.getAnalytics(auth.instituteId!);
        setState(() =>
            _data = InstituteAnalytics.fromJson(Map<String, dynamic>.from(raw)));
      } catch (_) {}
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingWidget(message: 'Loading analytics...');
    if (_data == null) {
      return const EmptyState(
          icon: Icons.bar_chart_outlined, title: 'Analytics not available');
    }
    return RefreshIndicator(
      onRefresh: () => _load(force: true),
      child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Analytics',
              style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          _OverviewCards(data: _data!),
          const SizedBox(height: 20),
          LayoutBuilder(builder: (ctx, bc) {
            if (bc.maxWidth > 800) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _TopPerformers(data: _data!)),
                  const SizedBox(width: 20),
                  Expanded(child: _WeakStudents(data: _data!)),
                ],
              );
            }
            return Column(children: [
              _TopPerformers(data: _data!),
              const SizedBox(height: 16),
              _WeakStudents(data: _data!),
            ]);
          }),
          const SizedBox(height: 20),
          _SubjectChart(data: _data!),
        ],
      ),
    ),
    );
  }
}

class _OverviewCards extends StatelessWidget {
  final InstituteAnalytics data;
  const _OverviewCards({required this.data});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, bc) {
      final cards = [
        StatsCard(title: 'Tests Conducted', value: '${data.totalTests}', icon: Icons.quiz_rounded, color: AppColors.primary),
        StatsCard(title: 'Avg Score', value: '${data.avgTestScore}%', icon: Icons.trending_up_rounded, color: AppColors.accent),
        StatsCard(title: 'Attendance Rate', value: '${data.attendanceRate}%', icon: Icons.check_circle_rounded, color: AppColors.success),
        StatsCard(title: 'Fee Collection', value: '${data.feeCollectionRate}%', subtitle: '₹${data.feeCollected.toStringAsFixed(0)} collected', icon: Icons.account_balance_wallet_rounded, color: AppColors.warning),
      ];
      if (bc.maxWidth < 800) {
        return Column(children: [
          Row(children: [Expanded(child: cards[0]), const SizedBox(width: 12), Expanded(child: cards[1])]),
          const SizedBox(height: 12),
          Row(children: [Expanded(child: cards[2]), const SizedBox(width: 12), Expanded(child: cards[3])]),
        ]);
      }
      return GridView.count(crossAxisCount: 4, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 2.2, children: cards);
    });
  }
}

class _TopPerformers extends StatelessWidget {
  final InstituteAnalytics data;
  const _TopPerformers({required this.data});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Top Performers',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 12),
            if (data.topPerformers.isEmpty)
              const EmptyState(
                  icon: Icons.emoji_events_outlined,
                  title: 'No test data yet')
            else
              ...data.topPerformers.asMap().entries.map((e) {
                final i = e.key;
                final p = e.value;
                final medals = ['🥇', '🥈', '🥉'];
                final avg = (p['avg_pct'] ?? 0).toDouble();
                return ListTile(
                  dense: true,
                  leading: Text(
                      i < 3 ? medals[i] : '${i + 1}.',
                      style: const TextStyle(fontSize: 20)),
                  title: Text(p['name'] ?? '',
                      style:
                          GoogleFonts.inter(fontWeight: FontWeight.w600)),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('${avg.toStringAsFixed(1)}%',
                        style: GoogleFonts.inter(
                            color: AppColors.success,
                            fontWeight: FontWeight.bold)),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _WeakStudents extends StatelessWidget {
  final InstituteAnalytics data;
  const _WeakStudents({required this.data});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Needs Attention',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600, fontSize: 16)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('<50% avg',
                      style: GoogleFonts.inter(
                          fontSize: 10, color: AppColors.error)),
                )
              ],
            ),
            const SizedBox(height: 12),
            if (data.weakPerformers.isEmpty)
              const EmptyState(
                  icon: Icons.sentiment_very_satisfied_outlined,
                  title: 'All students performing well!')
            else
              ...data.weakPerformers.map((p) {
                final avg = (p['avg_pct'] ?? 0).toDouble();
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.warning_amber_rounded,
                      color: AppColors.error, size: 20),
                  title: Text(p['name'] ?? '',
                      style:
                          GoogleFonts.inter(fontWeight: FontWeight.w600)),
                  trailing: Text('${avg.toStringAsFixed(1)}%',
                      style: const TextStyle(
                          color: AppColors.error,
                          fontWeight: FontWeight.bold)),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _SubjectChart extends StatelessWidget {
  final InstituteAnalytics data;
  const _SubjectChart({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.subjectPerformance.isEmpty) return const SizedBox();
    final subjects = data.subjectPerformance;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Subject Performance',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 20),
            SizedBox(
              height: 220,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: 100,
                  barGroups: subjects.asMap().entries.map((e) {
                    final avg = (e.value['avg_pct'] ?? 0).toDouble();
                    return BarChartGroupData(
                      x: e.key,
                      barRods: [
                        BarChartRodData(
                          toY: avg,
                          color: avg >= 70
                              ? AppColors.success
                              : avg >= 50
                                  ? AppColors.warning
                                  : AppColors.error,
                          width: 20,
                          borderRadius:
                              const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ],
                    );
                  }).toList(),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (val, _) {
                          final i = val.toInt();
                          if (i >= subjects.length) return const SizedBox();
                          final s = subjects[i]['subject'] as String? ?? '';
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                                s.length > 6 ? s.substring(0, 6) : s,
                                style: GoogleFonts.inter(fontSize: 10)),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (val, _) => Text('${val.toInt()}%',
                            style: GoogleFonts.inter(fontSize: 10)),
                        reservedSize: 32,
                      ),
                    ),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: const FlGridData(show: true),
                  borderData: FlBorderData(show: false),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
