import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/expense_controller.dart';
import '../../controllers/group_controller.dart';
import '../../controllers/notification_controller.dart';
import '../../models/notification_model.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_constants.dart';
import '../../utils/app_router.dart';
import '../../widgets/common/empty_state_widget.dart';

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
  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1)  return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours   < 24) return '${diff.inHours}h ago';
    if (diff.inDays    < 7)  return '${diff.inDays}d ago';
    return DateFormat('MMM d, y').format(date);
  }

  IconData _iconFor(String type) {
    switch (type) {
      case AppConstants.notifExpensePendingApproval:  return Icons.pending_actions_rounded;
      case AppConstants.notifExpenseApproved:         return Icons.check_circle_rounded;
      case AppConstants.notifExpenseRejected:         return Icons.cancel_rounded;
      case AppConstants.notifPaymentApproved:         return Icons.payments_rounded;
      case AppConstants.notifPaymentRejected:         return Icons.money_off_rounded;
      case AppConstants.notifJoinApproved:            return Icons.group_add_rounded;
      case AppConstants.notifJoinRejected:            return Icons.person_remove_rounded;
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
    switch (type) {
      case AppConstants.notifExpensePendingApproval:  return Colors.orange;
      case AppConstants.notifExpenseApproved:         return AppColors.success;
      case AppConstants.notifExpenseRejected:         return AppColors.error;
      case AppConstants.notifPaymentApproved:         return AppColors.success;
      case AppConstants.notifPaymentRejected:         return AppColors.error;
      case AppConstants.notifGroupAutoDeactivated:    return AppColors.warning;
      case AppConstants.notifGroupEnded:              return AppColors.warning;
      case AppConstants.notifLeaveRequest:            return Colors.orange;
      case AppConstants.notifLeaveApproved:           return AppColors.success;
      case AppConstants.notifLeaveRejected:           return AppColors.error;
      case AppConstants.notifDeleteExpenseRequest:    return AppColors.error;
      case AppConstants.notifDeleteExpenseApproved:   return AppColors.success;
      case AppConstants.notifDeleteExpenseRejected:   return AppColors.error;
      case AppConstants.notifBkashRequested:          return AppColors.primary;
      case AppConstants.notifBkashAccepted:           return AppColors.success;
      default:                                        return AppColors.primary;
    }
  }

  static const _tappableTypes = {
    AppConstants.notifExpensePendingApproval,
    AppConstants.notifExpenseApproved,
    AppConstants.notifExpenseRejected,
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

  /// Shows Accept / Decline dialog when member B gets a bKash request.
  void _showBkashRequestDialog(BuildContext ctx, NotificationModel notif, String groupId) {
    final groupCtrl   = ctx.read<GroupController>();
    final authCtrl    = ctx.read<AuthController>();
    final requesterId = notif.referenceId;                               // who asked
    final requesterName = notif.message.split(' is requesting').first.trim();
    final targetId    = authCtrl.user?.uid    ?? '';                     // me (B)
    final targetName  = authCtrl.user?.name   ?? '';
    final groupName   = notif.groupName;

    showDialog(
      context: ctx,
      barrierDismissible: true,
      builder: (dialogCtx) {
        bool _loading = false;
        return StatefulBuilder(
          builder: (sCtx, setSt) => AlertDialog(
            title: const Row(children: [
              Icon(Icons.phone_android_rounded, color: AppColors.primary, size: 22),
              SizedBox(width: 10),
              Text('bKash Request'),
            ]),
            content: Text(
              '$requesterName is requesting your bKash number.\n\n'
              'If you accept, they will be able to see your bKash number.',
            ),
            actions: [
              // Decline
              TextButton(
                onPressed: _loading ? null : () async {
                  setSt(() => _loading = true);
                  await groupCtrl.declineBkashRequest(
                    groupId:     groupId,
                    requesterId: requesterId,
                    targetId:    targetId,
                  );
                  if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                      content: Text('Request declined.'),
                    ));
                  }
                },
                child: const Text('Decline', style: TextStyle(color: AppColors.error)),
              ),
              // Accept
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                onPressed: _loading ? null : () async {
                  setSt(() => _loading = true);
                  final ok = await groupCtrl.acceptBkashRequest(
                    groupId:       groupId,
                    requesterId:   requesterId,
                    requesterName: requesterName,
                    targetId:      targetId,
                    targetName:    targetName,
                    groupName:     groupName,
                  );
                  if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                      content: Text(ok
                          ? 'bKash number shared with $requesterName ✅'
                          : 'Failed. Try again.'),
                      backgroundColor: ok ? AppColors.success : AppColors.error,
                    ));
                  }
                },
                child: _loading
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Accept', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Shows an inline approve/reject dialog for a leave request notification.
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
        bool _loading = false;
        return StatefulBuilder(
          builder: (sCtx, setSt) => AlertDialog(
            title: Row(children: [
              const Icon(Icons.exit_to_app_rounded, color: AppColors.error, size: 22),
              const SizedBox(width: 10),
              const Text('Leave Request'),
            ]),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (notif.groupName.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color:        AppColors.primary.withOpacity(0.1),
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
            actions: _loading
                ? [const Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())]
                : [
                    // Reject
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side:  const BorderSide(color: AppColors.error),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () async {
                        setSt(() => _loading = true);
                        final ok = await groupCtrl.rejectLeave(
                          memberId:   memberId,
                          memberName: memberName,
                        );
                        // Always close the dialog — don't gate on mounted because
                        // a GoRouter notifyListeners() during the await can make
                        // dialogCtx.mounted return false even though the dialog is still
                        // visible, causing the black-screen freeze.
                        try { Navigator.of(dialogCtx).pop(); } catch (_) {}
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                            content: Text(ok
                                ? '$memberName\'s leave request rejected.'
                                : 'Failed. Try again.'),
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
                        setSt(() => _loading = true);
                        final ok = await groupCtrl.approveLeave(
                          memberId:   memberId,
                          memberName: memberName,
                        );
                        // Always close — same reason as above
                        try { Navigator.of(dialogCtx).pop(); } catch (_) {}
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                            content: Text(ok
                                ? '$memberName has been removed from the group.'
                                : 'Failed. Try again.'),
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (notifCtrl.hasUnread)
            TextButton(
              onPressed: () => notifCtrl.markAllAsRead(user?.uid ?? ''),
              child: const Text('Mark all read'),
            ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Text('Unread'),
                if (unread.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color:        AppColors.error,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('${unread.length}',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                ],
              ]),
            ),
            const Tab(text: 'Read'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _NotifList(
            notifications: unread,
            emptyIcon:     Icons.mark_email_read_outlined,
            emptyTitle:    'All caught up!',
            emptySubtitle: 'New notifications appear here.',
            onTap:         _handleTap,
            tappableTypes: _tappableTypes,
            iconFor:       _iconFor,
            colorFor:      _colorFor,
            timeAgo:       _timeAgo,
          ),
          _NotifList(
            notifications: read,
            emptyIcon:     Icons.notifications_off_outlined,
            emptyTitle:    'No Read Notifications',
            emptySubtitle: 'Notifications you have seen will appear here.',
            onTap:         _handleTap,
            tappableTypes: _tappableTypes,
            iconFor:       _iconFor,
            colorFor:      _colorFor,
            timeAgo:       _timeAgo,
          ),
        ],
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
  final String       Function(DateTime) timeAgo;

  const _NotifList({
    required this.notifications,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.onTap,
    required this.tappableTypes,
    required this.iconFor,
    required this.colorFor,
    required this.timeAgo,
  });

  @override
  Widget build(BuildContext context) {
    final notifCtrl = context.read<NotificationController>();
    final scheme    = Theme.of(context).colorScheme;

    if (notifications.isEmpty) {
      return EmptyStateWidget(
        icon:     Icons.notifications_off_outlined,
        title:    emptyTitle,
        subtitle: emptySubtitle,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: notifications.length,
      separatorBuilder: (_, __) => Divider(height: 1, indent: 72, color: scheme.outlineVariant),
      itemBuilder: (_, i) {
        final notif    = notifications[i];
        final color    = colorFor(notif.type);
        final tappable = tappableTypes.contains(notif.type);

        return InkWell(
          onTap: () => onTap(context, notif, notifCtrl),
          child: Container(
            color: notif.isRead ? null : scheme.primaryContainer.withOpacity(0.35),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon circle
                Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                    color:  color.withOpacity(0.12),
                    shape:  BoxShape.circle,
                  ),
                  child: Icon(iconFor(notif.type), color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Group name badge (if present)
                      if (notif.groupName.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          margin: const EdgeInsets.only(bottom: 5),
                          decoration: BoxDecoration(
                            color:        AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            notif.groupName,
                            style: const TextStyle(
                              fontSize:   11,
                              fontWeight: FontWeight.w600,
                              color:      AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                      // Message
                      Text(
                        notif.message,
                        style: TextStyle(
                          fontSize:   14,
                          fontWeight: notif.isRead ? FontWeight.w400 : FontWeight.w600,
                          height:     1.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Time + tap hint
                      Row(children: [
                        Text(timeAgo(notif.createdAt),
                            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                        if (tappable) ...[
                          const SizedBox(width: 6),
                          Text('· Tap to review',
                              style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
                        ],
                      ]),
                    ],
                  ),
                ),
                // Unread dot
                if (!notif.isRead)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, left: 4),
                    child: Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle),
                    ),
                  ),
                if (tappable)
                  Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant, size: 20),
              ],
            ),
          ),
        );
      },
    );
  }
}
