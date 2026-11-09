import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/expense_controller.dart';
import '../../controllers/group_controller.dart';
import '../../controllers/notification_controller.dart';
import '../../models/notification_model.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_constants.dart';
import '../../utils/app_router.dart';
import '../../utils/display_helpers.dart';
import '../../widgets/common/empty_state_widget.dart';
import '../../widgets/ui/ui.dart';
import 'bkash_request_sheet.dart';

/// In-app notifications list with Unread / Read tabs.
/// Unread tab is shown by default. Tapping a notification marks it read
/// and navigates to the relevant detail screen.
class NotificationsView extends StatefulWidget {
  const NotificationsView({super.key});
  @override
  State<NotificationsView> createState() => _NotificationsViewState();
}

class _NotificationsViewState extends State<NotificationsView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  // ── Helpers ────────────────────────────────────────────────────────────────
  IconData _iconFor(String type) {
    switch (type) {
      case AppConstants.notifExpensePendingApproval:  return Icons.pending_actions_rounded;
      case AppConstants.notifExpenseApproved:         return Icons.check_circle_rounded;
      case AppConstants.notifExpenseRejected:         return Icons.cancel_rounded;
      case AppConstants.notifPaymentPending:          return Icons.payments_rounded;
      case AppConstants.notifPaymentApproved:         return Icons.payments_rounded;
      case AppConstants.notifPaymentRejected:         return Icons.money_off_rounded;
      case AppConstants.notifGroupAutoDeactivated:    return Icons.timer_off_rounded;
      case AppConstants.notifGroupEnded:              return Icons.flag_rounded;
      case AppConstants.notifLeaveRequest:            return Icons.exit_to_app_rounded;
      case AppConstants.notifLeaveApproved:           return Icons.check_circle_outline_rounded;
      case AppConstants.notifLeaveRejected:           return Icons.block_rounded;
      case AppConstants.notifDeleteExpenseRequest:    return Icons.delete_forever_outlined;
      case AppConstants.notifDeleteExpenseApproved:   return Icons.delete_sweep_rounded;
      case AppConstants.notifDeleteExpenseRejected:   return Icons.delete_outline_rounded;
      case AppConstants.notifBkashRequested:          return Icons.phone_android_rounded;
      case AppConstants.notifBkashAccepted:           return Icons.check_circle_rounded;
      default:                                        return Icons.notifications_rounded;
    }
  }

  Color _colorFor(String type) {
    final p = context.palette;
    switch (type) {
      case AppConstants.notifExpensePendingApproval:
      case AppConstants.notifPaymentPending:
      case AppConstants.notifLeaveRequest:
        return p.pending;
      case AppConstants.notifExpenseApproved:
      case AppConstants.notifPaymentApproved:
      case AppConstants.notifLeaveApproved:
      case AppConstants.notifDeleteExpenseApproved:
      case AppConstants.notifBkashAccepted:
        return p.positive;
      case AppConstants.notifExpenseRejected:
      case AppConstants.notifPaymentRejected:
      case AppConstants.notifLeaveRejected:
      case AppConstants.notifDeleteExpenseRequest:
      case AppConstants.notifDeleteExpenseRejected:
        return p.negative;
      case AppConstants.notifGroupAutoDeactivated:
      case AppConstants.notifGroupEnded:
        return p.textMuted;
      case AppConstants.notifBkashRequested:
        return p.info;
      default:
        return p.accent;
    }
  }

  static const _tappableTypes = {
    AppConstants.notifExpensePendingApproval,
    AppConstants.notifExpenseApproved,
    AppConstants.notifExpenseRejected,
    AppConstants.notifPaymentPending,
    AppConstants.notifPaymentApproved,
    AppConstants.notifPaymentRejected,
    AppConstants.notifLeaveRequest,
    AppConstants.notifDeleteExpenseRequest,
    AppConstants.notifDeleteExpenseRejected,
    AppConstants.notifBkashRequested,   // member B must Accept / Decline
  };

  void _handleTap(BuildContext ctx, NotificationModel notif, NotificationController ctrl) {
    ctrl.markAsRead(notif.notificationId);

    final expenseTypes = {
      AppConstants.notifExpensePendingApproval,
      AppConstants.notifExpenseApproved,
      AppConstants.notifExpenseRejected,
    };
    final paymentTypes = {
      AppConstants.notifPaymentPending,
      AppConstants.notifPaymentApproved,
      AppConstants.notifPaymentRejected,
    };

    final groupId = notif.groupId.isNotEmpty
        ? notif.groupId
        : (ctx.read<GroupController>().activeGroup?.groupId ?? '');

    if (expenseTypes.contains(notif.type) && notif.referenceId.isNotEmpty) {
      ctx.push('${AppRoutes.expenseDetail}?expenseId=${notif.referenceId}&groupId=$groupId');
    } else if (paymentTypes.contains(notif.type) && notif.referenceId.isNotEmpty) {
      ctx.push('${AppRoutes.paymentReview}?paymentId=${notif.referenceId}&groupId=$groupId');
    } else if (notif.type == AppConstants.notifLeaveRequest && notif.referenceId.isNotEmpty) {
      _showLeaveApprovalDialog(ctx, notif);
    } else if (notif.type == AppConstants.notifDeleteExpenseRequest && notif.referenceId.isNotEmpty) {
      // Admin taps: go to review page — parse memberName from message
      final memberName = notif.message.split(' is requesting').first.trim();
      ctx.push(
        '${AppRoutes.expenseDeleteReview}'
        '?expenseId=${notif.referenceId}'
        '&groupId=$groupId'
        '&memberName=${Uri.encodeComponent(memberName)}',
      );
    } else if (notif.type == AppConstants.notifDeleteExpenseRejected && notif.referenceId.isNotEmpty) {
      // Member taps: show re-request dialog
      _showDeleteRejectedDialog(ctx, notif, groupId);
    } else if (notif.type == AppConstants.notifBkashRequested && notif.referenceId.isNotEmpty) {
      // Member B taps: show Accept / Decline dialog
      _showBkashRequestDialog(ctx, notif, groupId);
    }
  }

  /// Shows a dialog letting the member re-request expense deletion after rejection.
  void _showDeleteRejectedDialog(BuildContext ctx, NotificationModel notif, String groupId) {
    final expCtrl   = ctx.read<ExpenseController>();
    final groupCtrl = ctx.read<GroupController>();
    final authCtrl  = ctx.read<AuthController>();
    final group     = groupCtrl.activeGroup;
    final symbol    = group?.currencySymbol ?? '৳';
    final adminId   = group?.adminId ?? '';
    final memberName = authCtrl.user?.name ?? '';

    showDialog(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.delete_forever_outlined, color: AppColors.error, size: 22),
          SizedBox(width: 8),
          Text('Re-request Deletion'),
        ]),
        content: Text(
          'Your previous delete request was rejected.\n\n'
          '${notif.groupName.isNotEmpty ? "Group: ${notif.groupName}\n\n" : ""}'
          'Would you like to send another deletion request to the admin?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              // Parse amount from message: "...of ৳123.45 was rejected..."
              double amount = 0;
              final amtMatch = RegExp(r'[\d.,]+').allMatches(notif.message).toList();
              if (amtMatch.isNotEmpty) {
                amount = double.tryParse(amtMatch.first.group(0)?.replaceAll(',', '') ?? '0') ?? 0;
              }
              final ok = await expCtrl.requestDeleteExpense(
                groupId:        groupId,
                groupName:      notif.groupName,
                expenseId:      notif.referenceId,
                adminId:        adminId,
                memberName:     memberName,
                currencySymbol: symbol,
                amount:         amount,
              );
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                  content: Text(ok
                      ? 'Deletion request sent to admin again.'
                      : 'Failed to send request. Try again.'),
                  backgroundColor: ok ? AppColors.success : AppColors.error,
                ));
              }
            },
            child: const Text('Re-request', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showBkashRequestDialog(BuildContext ctx, NotificationModel notif, String groupId) =>
      showBkashRequestSheet(ctx, notif, groupId);

  /// Shows an inline approve/reject dialog for a leave request notification.
  /// Closes [route] if it's still open. Removing that exact route (rather
  /// than popping whatever is on top) can't close the wrong screen.
  static void _closeRoute(NavigatorState nav, Route<dynamic>? route) {
    if (route != null && route.isActive && nav.mounted) nav.removeRoute(route);
  }

  void _showLeaveApprovalDialog(BuildContext ctx, NotificationModel notif) {
    final memberId   = notif.referenceId;
    final groupCtrl  = ctx.read<GroupController>();

    // Resolve member name from active group if possible, otherwise parse from message
    final memberName = groupCtrl.activeGroup?.members[memberId]?.name
        ?? notif.message.split(' has requested').first.trim();

    showDialog(
      context: ctx,
      barrierDismissible: true,
      builder: (dialogCtx) {
        bool loading = false;
        return StatefulBuilder(
          builder: (sCtx, setSt) => AlertDialog(
            title: const Row(children: [
              Icon(Icons.exit_to_app_rounded, color: AppColors.error, size: 22),
              SizedBox(width: 10),
              Text('Leave request'),
            ]),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (notif.groupName.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color:        AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(notif.groupName,
                        style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 12),
                ],
                RichText(
                  text: TextSpan(
                    style: TextStyle(fontSize: 14, color: Theme.of(ctx).colorScheme.onSurface),
                    children: [
                      TextSpan(
                        text: memberName,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const TextSpan(
                        text: ' wants to leave the group.\n\nTheir recorded expenses and debts will remain after leaving.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: loading
                ? [const Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())]
                : [
                    // Reject
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side:  const BorderSide(color: AppColors.error),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () async {
                        // Grab the dialog's route first: a GoRouter rebuild
                        // during the await can make dialogCtx unusable while
                        // the dialog is still on screen (the old black-screen
                        // freeze), so close that exact route afterwards.
                        final nav   = Navigator.of(dialogCtx);
                        final route = ModalRoute.of(dialogCtx);
                        setSt(() => loading = true);
                        final ok = await groupCtrl.rejectLeave(
                          memberId:   memberId,
                          memberName: memberName,
                        );
                        _closeRoute(nav, route);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                            content: Text(ok
                                ? '$memberName\'s leave request rejected.'
                                : (groupCtrl.errorMessage ?? 'Failed. Try again.')),
                            backgroundColor: ok ? AppColors.warning : AppColors.error,
                          ));
                        }
                      },
                      child: const Text('Reject', style: TextStyle(color: AppColors.error)),
                    ),
                    // Approve
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () async {
                        final nav   = Navigator.of(dialogCtx);
                        final route = ModalRoute.of(dialogCtx);
                        setSt(() => loading = true);
                        final ok = await groupCtrl.approveLeave(
                          memberId:   memberId,
                          memberName: memberName,
                        );
                        _closeRoute(nav, route);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                            content: Text(ok
                                ? '$memberName has left the tour.'
                                : (groupCtrl.errorMessage ?? 'Failed. Try again.')),
                            backgroundColor: ok ? AppColors.success : AppColors.error,
                          ));
                        }
                      },
                      child: const Text('Approve', style: TextStyle(color: Colors.white)),
                    ),
                  ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final notifCtrl = context.watch<NotificationController>();
    final user      = context.read<AuthController>().user;

    final unread = notifCtrl.notifications.where((n) => !n.isRead).toList();
    final read   = notifCtrl.notifications.where((n) =>  n.isRead).toList();

    final p = context.palette;
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverSafeArea(
            bottom: false,
            sliver: SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 0),
              sliver: SliverToBoxAdapter(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Activity', style: t.headlineMedium),
                          const SizedBox(height: 4),
                          Text(
                            unread.isEmpty ? 'You\'re all caught up.' : '${unread.length} new ${unread.length == 1 ? 'update' : 'updates'}',
                            style: t.bodyMedium?.copyWith(color: p.textMuted),
                          ),
                        ],
                      ),
                    ),
                    if (notifCtrl.hasUnread)
                      TextButton.icon(
                        onPressed: () => notifCtrl.markAllAsRead(user?.uid ?? ''),
                        icon:  const Icon(Icons.done_all_rounded, size: 18),
                        label: const Text('Mark all read'),
                      ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: PillTabBar(
              controller: _tabs,
              margin: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              tabs: [
                Tab(
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Text('New'),
                    if (unread.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      StatusChip('${unread.length}', tone: ChipTone.negative, dense: true),
                    ],
                  ]),
                ),
                const Tab(text: 'Earlier'),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabs,
          children: [
            _NotifList(
              notifications: unread,
              emptyIcon:     Icons.mark_email_read_rounded,
              emptyTitle:    'All caught up',
              emptySubtitle: 'Approvals, payments and requests that need you show up here.',
              onTap:         _handleTap,
              tappableTypes: _tappableTypes,
              iconFor:       _iconFor,
              colorFor:      _colorFor,
            ),
            _NotifList(
              notifications: read,
              emptyIcon:     Icons.history_rounded,
              emptyTitle:    'Nothing here yet',
              emptySubtitle: 'Updates you\'ve already seen move here.',
              onTap:         _handleTap,
              tappableTypes: _tappableTypes,
              iconFor:       _iconFor,
              colorFor:      _colorFor,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared notification list widget ──────────────────────────────────────────
class _NotifList extends StatelessWidget {
  final List<NotificationModel> notifications;
  final IconData     emptyIcon;
  final String       emptyTitle;
  final String       emptySubtitle;
  final void Function(BuildContext, NotificationModel, NotificationController) onTap;
  final Set<String>  tappableTypes;
  final IconData     Function(String) iconFor;
  final Color        Function(String) colorFor;

  const _NotifList({
    required this.notifications,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.onTap,
    required this.tappableTypes,
    required this.iconFor,
    required this.colorFor,
  });

  @override
  Widget build(BuildContext context) {
    final notifCtrl = context.read<NotificationController>();
    final p         = context.palette;
    final t         = Theme.of(context).textTheme;

    if (notifications.isEmpty) {
      return EmptyStateWidget(icon: emptyIcon, title: emptyTitle, subtitle: emptySubtitle);
    }

    // Group by day, newest first (the list already is).
    final rows = <Object>[];
    String? lastDay;
    for (final n in notifications) {
      final day = dayLabel(n.createdAt);
      if (day != lastDay) {
        rows.add(day);
        lastDay = day;
      }
      rows.add(n);
    }

    return ListView.builder(
      padding:   const EdgeInsets.fromLTRB(20, 8, 20, 32),
      itemCount: rows.length,
      itemBuilder: (_, i) {
        final row = rows[i];
        if (row is String) {
          return Padding(
            padding: EdgeInsets.fromLTRB(4, i == 0 ? 8 : 20, 4, 10),
            child: Text(row.toUpperCase(), style: AppType.overline(p.textMuted)),
          );
        }
        final notif    = row as NotificationModel;
        final color    = colorFor(notif.type);
        final tappable = tappableTypes.contains(notif.type);
        final message  = notif.message.replaceAll(RegExp(r'\s*Tap to [^.]*\.?$'), '').trim();

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: AppCard(
            onTap:       () => onTap(context, notif, notifCtrl),
            padding:     const EdgeInsets.fromLTRB(14, 14, 12, 14),
            color:       notif.isRead ? p.surface : Color.alphaBlend(p.accent.withValues(alpha: p.isDark ? 0.07 : 0.05), p.surface),
            borderColor: notif.isRead ? null : p.accent.withValues(alpha: 0.25),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconTile(iconFor(notif.type), color: color, size: 42, radius: 13),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message,
                        style: t.bodyMedium?.copyWith(
                          fontWeight: notif.isRead ? FontWeight.w400 : FontWeight.w600,
                          height:     1.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(timeAgo(notif.createdAt), style: t.bodySmall),
                          if (notif.groupName.isNotEmpty) StatusChip(notif.groupName, dense: true),
                          if (tappable) const StatusChip('Review', tone: ChipTone.accent, dense: true, icon: Icons.arrow_forward_rounded),
                        ],
                      ),
                    ],
                  ),
                ),
                if (!notif.isRead)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 8),
                    child: Container(
                      width: 9, height: 9,
                      decoration: BoxDecoration(color: p.accent, shape: BoxShape.circle),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
