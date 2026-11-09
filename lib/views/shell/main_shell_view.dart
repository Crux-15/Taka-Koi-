import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../controllers/notification_controller.dart';
import '../../utils/app_router.dart';
import '../../widgets/common/offline_banner.dart';
import '../../widgets/ui/ui.dart';

/// Bottom navigation shell: wraps the four main tabs.
class MainShellView extends StatelessWidget {
  final Widget child;
  const MainShellView({super.key, required this.child});

  static const _routes = [
    AppRoutes.home,
    AppRoutes.debtOverview,
    AppRoutes.notifications,
    AppRoutes.profile,
  ];

  int _locationToIndex(String location) {
    for (var i = 0; i < _routes.length; i++) {
      if (location.startsWith(_routes[i])) return i;
    }
    return 0;
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
      bottomNavigationBar: FloatingNavBar(
        currentIndex: current,
        onTap: (i) {
          if (i != current) context.go(_routes[i]);
        },
        items: [
          const NavItem(Icons.home_outlined, Icons.home_rounded, 'Home'),
          const NavItem(Icons.account_balance_wallet_outlined, Icons.account_balance_wallet_rounded, 'Balances'),
          NavItem(Icons.notifications_none_rounded, Icons.notifications_rounded, 'Activity',
              badge: notifCtrl.hasUnread ? notifCtrl.unreadCount : 0),
          const NavItem(Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
        ],
      ),
    );
  }
}
