import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../controllers/notification_controller.dart';
import '../../utils/app_router.dart';
import '../../widgets/common/offline_banner.dart';

/// Bottom navigation shell — wraps all main tabs.
class MainShellView extends StatelessWidget {
  final Widget child;
  const MainShellView({super.key, required this.child});

  int _locationToIndex(String location) {
    if (location.startsWith(AppRoutes.home))        return 0;
    if (location.startsWith(AppRoutes.debtOverview))return 1;
    if (location.startsWith(AppRoutes.notifications))return 2;
    if (location.startsWith(AppRoutes.profile))     return 3;
    return 0;
  }

  void _onTap(BuildContext context, int index) {
    switch (index) {
      case 0: context.go(AppRoutes.home);          break;
      case 1: context.go(AppRoutes.debtOverview);  break;
      case 2: context.go(AppRoutes.notifications); break;
      case 3: context.go(AppRoutes.profile);       break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final location  = GoRouterState.of(context).matchedLocation;
    final current   = _locationToIndex(location);
    final notifCtrl = context.watch<NotificationController>();

    return Scaffold(
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: current,
        onDestinationSelected: (i) => _onTap(context, i),
        destinations: [
          const NavigationDestination(
            icon:           Icon(Icons.home_outlined),
            selectedIcon:   Icon(Icons.home_rounded),
            label:          'Home',
          ),
          const NavigationDestination(
            icon:           Icon(Icons.account_balance_wallet_outlined),
            selectedIcon:   Icon(Icons.account_balance_wallet_rounded),
            label:          'Debts',
          ),
          NavigationDestination(
            icon:    Badge(
              isLabelVisible: notifCtrl.hasUnread,
              label: Text('${notifCtrl.unreadCount}'),
              child: const Icon(Icons.notifications_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: notifCtrl.hasUnread,
              label: Text('${notifCtrl.unreadCount}'),
              child: const Icon(Icons.notifications_rounded),
            ),
            label: 'Notifications',
          ),
          const NavigationDestination(
            icon:           Icon(Icons.person_outline_rounded),
            selectedIcon:   Icon(Icons.person_rounded),
            label:          'Profile',
          ),
        ],
      ),
    );
  }
}
