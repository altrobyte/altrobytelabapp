import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../l10n/app_localizations.dart';
import '../providers/auth_provider.dart';

class SidebarWidget extends StatelessWidget {
  const SidebarWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      color: AppColors.sidebar,
      child: Column(
        children: [
          _Header(),
          Expanded(child: _Nav()),
          _Footer(),
        ],
      ),
    );
  }
}

String _instituteInitials(String? name) {
  if (name == null || name.trim().isEmpty) return 'EHL';
  final words = name.trim().split(RegExp(r'\s+'));
  if (words.length >= 3) {
    return '${words[0][0]}${words[1][0]}${words[2][0]}'.toUpperCase();
  }
  if (words.length == 2) return '${words[0][0]}${words[1][0]}'.toUpperCase();
  final n = name.trim();
  return n.substring(0, n.length >= 2 ? 2 : n.length).toUpperCase();
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final l10n = AppLocalizations.of(context)!;
    final initials = _instituteInitials(auth.instituteName);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Center(
              child: Text(initials,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20)),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            auth.instituteName ?? 'AltrobyteLab',
            style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: auth.isManager
                  ? AppColors.primary
                  : AppColors.accent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              auth.isManager
                  ? l10n.roleManager
                  : auth.isSuperAdmin
                      ? l10n.roleSuperAdmin
                      : l10n.roleAdmin,
              style: GoogleFonts.inter(
                  color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _Nav extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final auth = context.watch<AuthProvider>();
    final l10n = AppLocalizations.of(context)!;

    final allItems = [
      _NavItem(Icons.dashboard_rounded, l10n.navDashboard, '/dashboard'),
      _NavItem(Icons.people_rounded, l10n.navStudents, '/students'),
      _NavItem(Icons.groups_rounded, 'Users', '/platform-users'),
      _NavItem(Icons.class_rounded, l10n.navBatches, '/batches'),
      _NavItem(Icons.auto_awesome_rounded, l10n.navTestGenerator, '/test-generator',
          highlight: true),
      _NavItem(Icons.school_rounded, l10n.navTrainingModules, '/training-modules'),
      _NavItem(Icons.science_rounded, 'Experiments', '/experiments'),
      _NavItem(Icons.video_camera_front_rounded, 'Live Sessions', '/live-sessions-admin'),
      _NavItem(Icons.emoji_events_rounded, 'Challenges', '/challenges-admin'),
      _NavItem(Icons.view_stream_rounded, 'Home Strip', '/home-strip-admin'),
      _NavItem(Icons.collections_rounded, 'Stories & Lab', '/showcase-admin'),
      _NavItem(Icons.route_rounded, 'Curriculum', '/curriculum-admin'),
      _NavItem(Icons.contact_phone_rounded, 'CRM', '/crm'),
      _NavItem(Icons.timeline_rounded, 'Activity Feed', '/activity-feed-admin'),
      _NavItem(Icons.event_rounded, 'Events', '/events-admin'),
      _NavItem(Icons.work_rounded, 'Job Updates', '/jobs-admin'),
      _NavItem(Icons.mail_outline_rounded, 'Enquiries', '/enquiries-admin'),
      _NavItem(Icons.sell_rounded, 'Pricing', '/pricing-admin'),
      _NavItem(Icons.check_circle_rounded, l10n.navAttendance, '/attendance'),
      _NavItem(Icons.account_balance_wallet_rounded, l10n.navFeeManagement, '/fees'),
      _NavItem(Icons.bar_chart_rounded, l10n.navAnalytics, '/analytics'),
      if (auth.canBroadcast)
        _NavItem(Icons.campaign_rounded, l10n.navBroadcast, '/broadcast'),
      if (auth.canAccessSettings)
        _NavItem(Icons.settings_rounded, l10n.navSettings, '/settings'),
    ];

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: allItems.map((item) {
        final active = location.startsWith(item.route);
        return _NavTile(item: item, active: active);
      }).toList(),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  final String route;
  final bool highlight;
  const _NavItem(this.icon, this.label, this.route, {this.highlight = false});
}

class _NavTile extends StatelessWidget {
  final _NavItem item;
  final bool active;
  const _NavTile({required this.item, required this.active});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: active
            ? Colors.white.withValues(alpha: 0.15)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => context.go(item.route),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(item.icon,
                    color: active
                        ? Colors.white
                        : item.highlight
                            ? AppColors.accentLight
                            : Colors.white60,
                    size: 20),
                const SizedBox(width: 12),
                Text(
                  item.label,
                  style: GoogleFonts.inter(
                    color: active
                        ? Colors.white
                        : item.highlight
                            ? AppColors.accentLight
                            : Colors.white70,
                    fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
                if (active) ...[
                  const Spacer(),
                  Container(
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                        color: AppColors.accent, shape: BoxShape.circle),
                  )
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Divider(color: Colors.white24),
          const SizedBox(height: 8),
          InkWell(
            onTap: () {
              context.read<AuthProvider>().logout();
              context.go('/login');
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Row(
                children: [
                  const Icon(Icons.logout_rounded,
                      color: Colors.white60, size: 18),
                  const SizedBox(width: 10),
                  Text(AppLocalizations.of(context)!.navLogout,
                      style: GoogleFonts.inter(
                          color: Colors.white60, fontSize: 13)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.poweredByAltrobyte,
            style: GoogleFonts.inter(color: Colors.white30, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
