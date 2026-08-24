import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:timeline_tile/timeline_tile.dart';
import '../constants/app_colors.dart';
import '../l10n/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../providers/institute_provider.dart';
import '../services/api_service.dart';
import '../widgets/stats_card_widget.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _PlanBanner extends StatelessWidget {
  const _PlanBanner();

  @override
  Widget build(BuildContext context) {
    final sub = context.watch<InstituteProvider>().subscription;
    if (sub == null) return const SizedBox.shrink();

    final status = (sub['status'] ?? 'active').toString();
    final planLabel = (sub['plan_label'] ?? 'Basic').toString();
    final used = (sub['students_used'] ?? 0) as int;
    final max = (sub['max_students'] ?? 0) as int;
    final daysLeft = sub['days_left'];
    final unlimited = max >= 100000;

    Color color;
    IconData icon;
    String headline;
    switch (status) {
      case 'trial':
        color = AppColors.primary;
        icon = Icons.auto_awesome_rounded;
        headline = daysLeft != null
            ? 'Free trial — $daysLeft days left'
            : 'Free trial active';
        break;
      case 'grace':
        color = Colors.orange.shade800;
        icon = Icons.warning_amber_rounded;
        headline = 'Subscription expired — renew now to avoid suspension';
        break;
      case 'expired':
        color = AppColors.error;
        icon = Icons.lock_clock_rounded;
        headline = 'Subscription expired — renew to continue';
        break;
      default:
        color = AppColors.success;
        icon = Icons.verified_rounded;
        headline = '$planLabel plan';
    }

    final usageText = unlimited ? '$used students' : '$used / $max students';

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(headline,
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: color)),
                  const SizedBox(height: 2),
                  Text('$planLabel plan • $usageText',
                      style: GoogleFonts.inter(
                          fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            ),
            if (!unlimited && max > 0)
              SizedBox(
                width: 44,
                height: 44,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: (used / max).clamp(0.0, 1.0),
                      strokeWidth: 4,
                      backgroundColor: color.withValues(alpha: 0.15),
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                    Text('${((used / max) * 100).clamp(0, 100).toStringAsFixed(0)}%',
                        style: GoogleFonts.inter(
                            fontSize: 9, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (auth.instituteId != null) {
        final p = context.read<InstituteProvider>();
        p.ensureDashboard(auth.instituteId!);
        p.ensureSubscription(auth.instituteId!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InstituteProvider>();
    final dash = provider.dashboard;
    final loading = provider.isLoading && dash == null;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(),
          const _PlanBanner(),
          const SizedBox(height: 24),
          // Stats row
          if (loading)
            LayoutBuilder(builder: (ctx, bc) {
              final cols = bc.maxWidth > 800 ? 4 : 2;
              return GridView.count(
                crossAxisCount: cols,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: bc.maxWidth > 800 ? 2.2 : 1.5,
                children: List.generate(4, (_) => const StatsCardSkeleton()),
              );
            })
          else
            _StatsRow(dash: dash),
          const SizedBox(height: 20),
          // Whether the next free demo is filling is the one number nobody
          // thinks to go and look for, and the link is worth nothing sitting
          // in an admin screen — so both live here.
          const _NextDemoCard(),
          const SizedBox(height: 24),
          // Middle row
          LayoutBuilder(builder: (ctx, bc) {
            if (bc.maxWidth > 800) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                      flex: 6,
                      child: _ActivityCard(
                          activities: dash?['recent_activity'] ?? [])),
                  const SizedBox(width: 20),
                  Expanded(flex: 4, child: _QuickActions()),
                ],
              );
            }
            return Column(children: [
              _ActivityCard(activities: dash?['recent_activity'] ?? []),
              const SizedBox(height: 16),
              _QuickActions(),
            ]);
          }),
        ],
      ),
    );
  }
}

String _monthAbbr(int m) => ['', 'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][m];

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.dashboardTitle,
                  style: GoogleFonts.poppins(
                      fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              Text(l10n.dashboardWelcome(auth.instituteName ?? 'Coach'),
                  style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 13),
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        Text(
          '${DateTime.now().day} ${_monthAbbr(DateTime.now().month)}',
          style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12),
        ),
      ],
    );
  }
}

class _StatsRow extends StatelessWidget {
  final Map<String, dynamic>? dash;
  const _StatsRow({this.dash});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cards = [
      _CardData(
        title: l10n.statsTotalStudents,
        value: '${dash?['total_students'] ?? 0}',
        subtitle: l10n.statsEnrolledStudents,
        icon: Icons.people_rounded,
        color: AppColors.primary,
      ),
      _CardData(
        title: l10n.statsActiveBatches,
        value: '${dash?['active_batches'] ?? 0}',
        subtitle: l10n.statsRunningBatches,
        icon: Icons.class_rounded,
        color: AppColors.accent,
      ),
      _CardData(
        title: l10n.statsFeePending,
        value: '${dash?['fee_due_count'] ?? 0}',
        subtitle: l10n.statsStudentsPending,
        icon: Icons.account_balance_wallet_rounded,
        color: AppColors.error,
      ),
      _CardData(
        title: l10n.statsTestsToday,
        value: '${dash?['tests_today'] ?? 0}',
        subtitle: l10n.statsGeneratedToday,
        icon: Icons.quiz_rounded,
        color: AppColors.success,
      ),
    ];

    return LayoutBuilder(builder: (ctx, bc) {
      final isMobile = bc.maxWidth < 800;
      if (isMobile) {
        // 2×2 grid with fixed height cards — no overflow
        return Column(children: [
          Row(children: [
            Expanded(child: StatsCard(title: cards[0].title, value: cards[0].value, subtitle: cards[0].subtitle, icon: cards[0].icon, color: cards[0].color, animIndex: 0)),
            const SizedBox(width: 12),
            Expanded(child: StatsCard(title: cards[1].title, value: cards[1].value, subtitle: cards[1].subtitle, icon: cards[1].icon, color: cards[1].color, animIndex: 1)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: StatsCard(title: cards[2].title, value: cards[2].value, subtitle: cards[2].subtitle, icon: cards[2].icon, color: cards[2].color, animIndex: 2)),
            const SizedBox(width: 12),
            Expanded(child: StatsCard(title: cards[3].title, value: cards[3].value, subtitle: cards[3].subtitle, icon: cards[3].icon, color: cards[3].color, animIndex: 3)),
          ]),
        ]);
      }
      return GridView.count(
        crossAxisCount: 4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 2.2,
        children: cards.asMap().map((i, c) => MapEntry(i, StatsCard(
          title: c.title, value: c.value, subtitle: c.subtitle,
          icon: c.icon, color: c.color, animIndex: i,
        ))).values.toList(),
      );
    });
  }
}

class _CardData {
  final String title, value, subtitle;
  final IconData icon;
  final Color color;
  const _CardData(
      {required this.title,
      required this.value,
      required this.subtitle,
      required this.icon,
      required this.color});
}

class _ActivityCard extends StatelessWidget {
  final List activities;
  const _ActivityCard({required this.activities});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.of(context)!.dashboardRecentActivity,
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 16),
            if (activities.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(AppLocalizations.of(context)!.dashboardNoActivity,
                      style: const TextStyle(color: AppColors.textSecondary)),
                ),
              )
            else
              ...activities.take(8).toList().asMap().entries.map((e) {
                final i = e.key;
                final act = Map<String, dynamic>.from(e.value);
                final isTest = act['type'] == 'test';
                final isLast = i == activities.length - 1;
                return TimelineTile(
                  isLast: isLast,
                  indicatorStyle: IndicatorStyle(
                    width: 14,
                    height: 14,
                    color: isTest ? AppColors.accent : AppColors.primary,
                    padding: const EdgeInsets.all(4),
                  ),
                  beforeLineStyle: const LineStyle(color: Color(0xFFE0E0E0)),
                  endChild: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 4, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(act['student_name'] ?? '',
                            style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: AppColors.textPrimary)),
                        Text(act['detail'] ?? '',
                            style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.of(context)!.dashboardQuickActions,
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 16),
            _actionBtn(context, Icons.person_add_rounded,
                AppLocalizations.of(context)!.actionAddStudent,
                AppColors.primary, '/students'),
            const SizedBox(height: 10),
            _actionBtn(context, Icons.auto_awesome_rounded,
                AppLocalizations.of(context)!.actionGenerateTest,
                AppColors.accent, '/test-generator'),
            const SizedBox(height: 10),
            _actionBtn(context, Icons.check_circle_rounded,
                AppLocalizations.of(context)!.actionMarkAttendance,
                AppColors.success, '/attendance'),
            const SizedBox(height: 10),
            _actionBtn(context, Icons.account_balance_wallet_rounded,
                AppLocalizations.of(context)!.actionManageFees,
                AppColors.primary, '/fees'),
            const SizedBox(height: 10),
            _actionBtn(context, Icons.campaign_rounded,
                AppLocalizations.of(context)!.actionBroadcast,
                AppColors.accent, '/broadcast'),
          ],
        ),
      ),
    );
  }

  Widget _actionBtn(BuildContext context, IconData icon, String label,
      Color color, String route) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: () => context.go(route),
        icon: Icon(icon, size: 18),
        label: Text(label,
            style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
      ),
    );
  }
}


/// The next free demo, and the link that fills it.
///
/// Shows nothing at all when there is no demo coming up: an empty card on a
/// dashboard trains people to stop reading that part of the screen.
class _NextDemoCard extends StatefulWidget {
  const _NextDemoCard();

  @override
  State<_NextDemoCard> createState() => _NextDemoCardState();
}

class _NextDemoCardState extends State<_NextDemoCard> {
  List<dynamic> _upcoming = [];
  bool _loading = true;

  static const _shareUrl = 'https://lab.altrobyte.com/demo';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final all = await ApiService.adminGetDemos();
      final now = DateTime.now();
      final up = all.where((d) {
        final raw = (d as Map)['session_date'];
        final when = raw == null ? null : DateTime.tryParse('$raw');
        return when != null && when.isAfter(now);
      }).toList()
        ..sort((a, b) => DateTime.parse('${(a as Map)['session_date']}')
            .compareTo(DateTime.parse('${(b as Map)['session_date']}')));
      if (mounted) setState(() { _upcoming = up; _loading = false; });
    } catch (_) {
      // A dashboard that fails to load one card should still be a dashboard.
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _upcoming.isEmpty) return const SizedBox.shrink();
    final d = _upcoming.first as Map<String, dynamic>;
    final booked = (d['registration_count'] as int?) ?? 0;
    final cap = (d['capacity'] as int?) ?? 0;
    final published = d['is_published'] == true;
    final ratio = cap > 0 ? (booked / cap).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0B2450), Color(0xFF16407F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.event_seat_rounded, size: 17, color: Colors.white70),
          const SizedBox(width: 7),
          Text('NEXT FREE DEMO',
              style: GoogleFonts.inter(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.9,
                  color: Colors.white.withValues(alpha: 0.65))),
          const Spacer(),
          // A demo nobody can see is the failure mode worth shouting about,
          // because everything else on this card looks fine while it happens.
          if (!published)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFE65100),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('NOT VISIBLE',
                  style: GoogleFonts.inter(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ),
          if (_upcoming.length > 1)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text('+${_upcoming.length - 1} more',
                  style: GoogleFonts.inter(
                      fontSize: 10.5,
                      color: Colors.white.withValues(alpha: 0.6))),
            ),
        ]),
        const SizedBox(height: 11),
        Text('${d['title']}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                height: 1.3,
                color: Colors.white)),
        const SizedBox(height: 4),
        Text('${d['when'] ?? ''}',
            style: GoogleFonts.inter(
                fontSize: 12.5,
                color: Colors.white.withValues(alpha: 0.8))),
        if (cap > 0) ...[
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 6,
                  backgroundColor: Colors.white.withValues(alpha: 0.18),
                  valueColor: AlwaysStoppedAnimation(
                      ratio >= 1 ? const Color(0xFFFFC107) : Colors.white),
                ),
              ),
            ),
            const SizedBox(width: 11),
            Text('$booked / $cap',
                style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
          ]),
        ] else ...[
          const SizedBox(height: 12),
          Text('$booked booked',
              style: GoogleFonts.poppins(
                  fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
        ],
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: () {
                Clipboard.setData(const ClipboardData(text: _shareUrl));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Booking link copied')));
              },
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF0B2450),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.link_rounded, size: 17),
              label: Text('Copy booking link',
                  style: GoogleFonts.poppins(
                      fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(width: 9),
          OutlinedButton(
            onPressed: () => context.go('/demos-admin'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.4)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Manage',
                style: GoogleFonts.poppins(
                    fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ]),
      ]),
    );
  }
}
