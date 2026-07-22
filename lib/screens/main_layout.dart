import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_colors.dart';
import '../l10n/app_localizations.dart';
import '../widgets/sidebar_widget.dart';

class MainLayout extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  const MainLayout({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;

    if (isMobile) {
      return Scaffold(
        body: SafeArea(child: navigationShell),
        bottomNavigationBar: _BottomNav(shell: navigationShell),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          const SidebarWidget(),
          Expanded(child: SafeArea(child: navigationShell)),
        ],
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final StatefulNavigationShell shell;
  const _BottomNav({required this.shell});

  // Maps each bottom-nav slot to its branch index in the StatefulShellRoute.
  // (dashboard=0, students=1, test-generator=3, attendance=5, settings=9)
  static const _branchIndices = [0, 1, 3, 5, 9];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final items = [
      (Icons.dashboard_rounded, l10n.bottomNavHome),
      (Icons.people_rounded, l10n.bottomNavStudents),
      (Icons.auto_awesome_rounded, l10n.bottomNavTests),
      (Icons.check_circle_rounded, l10n.bottomNavAttendance),
      (Icons.settings_rounded, l10n.bottomNavSettings),
    ];

    int selected = _branchIndices.indexOf(shell.currentIndex);
    if (selected < 0) selected = 0;

    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      currentIndex: selected,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.textSecondary,
      backgroundColor: Colors.white,
      selectedFontSize: 10,
      unselectedFontSize: 10,
      onTap: (i) {
        final branch = _branchIndices[i];
        // Re-tapping the active tab resets it to the branch root.
        shell.goBranch(branch, initialLocation: branch == shell.currentIndex);
      },
      items: items
          .map((item) => BottomNavigationBarItem(
                icon: Icon(item.$1, size: 22),
                label: item.$2,
              ))
          .toList(),
    );
  }
}
