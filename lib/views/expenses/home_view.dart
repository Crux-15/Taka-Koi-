import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/debt_controller.dart';
import '../../controllers/expense_controller.dart';
import '../../controllers/group_controller.dart';
import '../../controllers/notification_controller.dart';
import '../../utils/app_constants.dart';
import '../../utils/app_router.dart';
import '../../utils/display_helpers.dart';
import '../../utils/money.dart';
import '../../widgets/common/loading_widget.dart';
import '../../widgets/ui/ui.dart';
import '../notifications/bkash_request_sheet.dart';
import '../profile/widgets/invite_sheet.dart';
import 'home/balance_hero_card.dart';
import 'home/home_sections.dart';
import 'home/leave_requests_section.dart';
import 'home/log_expense_fab.dart';
import 'home/member_total_card.dart';

/// Home: where you stand in the tour, what needs you, and what happened.
class HomeView extends StatefulWidget {
  const HomeView({super.key});
  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  String? _listeningFor;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initStreams());
  }

  /// Starts (or keeps) the live data Home needs. Safe to call repeatedly:
  /// each controller ignores a repeat for the same tour and user.
  void _initStreams() {
    if (!mounted) return;
    final gid = context.read<GroupController>().activeGroup?.groupId;
    final uid = context.read<AuthController>().user?.uid;
    if (gid == null || uid == null) return;
    final key = '$gid/$uid';
    if (_listeningFor == key) return;
    _listeningFor = key;
    context.read<ExpenseController>()
      ..listenToApprovedExpenses(gid)
      ..listenToMyExpenses(gid, uid);
    context.read<DebtController>().listenToDebts(gid, uid);
  }

  @override
  Widget build(BuildContext context) {
    final auth      = context.watch<AuthController>();
    final groupCtrl = context.watch<GroupController>();
    final expCtrl   = context.watch<ExpenseController>();
    final debtCtrl  = context.watch<DebtController>();
    final notifs    = context.watch<NotificationController>();
    final group     = groupCtrl.activeGroup;
    final user      = auth.user;
    final p         = context.palette;

    if (group == null || user == null) return const Center(child: AppLoader());

    final symbol       = group.currencySymbol;
    final isAdmin      = group.adminId == user.uid;
    final memberTotals = expCtrl.computeMemberTotals();
    final myTotal      = memberTotals[user.uid] ?? 0.0;
    final groupTotal   = memberTotals.values.fold<double>(0, (s, v) => s + v);

    final members = group.members.values.toList()
      ..sort((a, b) => (memberTotals[b.userId] ?? 0).compareTo(memberTotals[a.userId] ?? 0));
    final maxTotal = members.isEmpty ? 0.0 : (memberTotals[members.first.userId] ?? 0.0);

    final attention = _attentionItems(context, notifs, debtCtrl, group.groupId, symbol);
    final recent    = expCtrl.approvedExpenses.take(5).toList();

    return Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: const LogExpenseFab(),
      body: RefreshIndicator(
        color: p.accent,
        backgroundColor: p.surface,
        onRefresh: () async {
          _listeningFor = null;
          _initStreams();
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            SliverSafeArea(
              bottom: false,
              sliver: SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                sliver: SliverToBoxAdapter(child: HomeHeader(group: group, isAdmin: isAdmin)),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
              sliver: SliverList.list(
                children: [
                  BalanceHeroCard(
                    symbol:        symbol,
                    iOweCents:     debtCtrl.iOweCents,
                    owedToMeCents: debtCtrl.owedToMeCents,
                    mySpent:       myTotal,
                    groupTotal:    groupTotal,
                    loaded:        debtCtrl.isLoaded,
                    onTap:         () => context.go(AppRoutes.debtOverview),
                  ),
                  const SizedBox(height: 22),
                  QuickActions(actions: [
                    QuickAction(Icons.handshake_rounded, 'Settle up', () => context.go(AppRoutes.debtOverview),
                        badge: debtCtrl.pendingForMe.length),
                    QuickAction(Icons.receipt_long_rounded, 'History', () => context.push(AppRoutes.expenseHistory)),
                    QuickAction(Icons.person_add_alt_1_rounded, 'Invite', () => showInviteSheet(context, group)),
                    QuickAction(Icons.notifications_rounded, 'Activity', () => context.go(AppRoutes.notifications),
                        badge: notifs.unreadCount),
                  ]),

                  if (attention.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    SectionHeader('Needs you',
                        trailing: StatusChip('${attention.length}', tone: ChipTone.negative, dense: true)),
                    AttentionCard(items: attention),
                  ],

                  const SizedBox(height: 28),
                  SectionHeader('Who\'s paid',
                      trailing: Text(Money.displayCompact(groupTotal, symbol),
                          style: AppType.money(13.5, weight: FontWeight.w600, color: p.textMuted))),
                  AppCard(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    child: Column(
                      children: [
                        for (var i = 0; i < members.length; i++) ...[
                          if (i > 0) Divider(height: 1, color: p.hairline),
                          MemberTotalCard(
                            member:       members[i],
                            total:        memberTotals[members[i].userId] ?? 0,
                            maxTotal:     maxTotal,
                            symbol:       symbol,
                            rank:         i + 1,
                            isAdmin:      isAdmin,
                            isMe:         members[i].userId == user.uid,
                            isGroupAdmin: members[i].userId == group.adminId,
                            groupCtrl:    groupCtrl,
                          ),
                        ],
                        if (members.length == 1)
                          const Padding(
                            padding: EdgeInsets.fromLTRB(4, 4, 4, 14),
                            child: InfoBanner('Just you so far. Tap Invite to share the join code.',
                                icon: Icons.group_add_rounded, tone: ChipTone.accent),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),
                  SectionHeader('Recent expenses',
                      actionLabel: recent.isEmpty ? null : 'See all',
                      onAction: () => context.push(AppRoutes.expenseHistory)),
                  AppCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: !expCtrl.approvedLoaded
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Column(children: [
                              _RowSkeleton(), SizedBox(height: 16), _RowSkeleton(), SizedBox(height: 16), _RowSkeleton(),
                            ]),
                          )
                        : recent.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.symmetric(vertical: 22),
                                child: Column(
                                  children: [
                                    Icon(Icons.receipt_long_rounded, color: p.textFaint, size: 28),
                                    const SizedBox(height: 8),
                                    Text('Nothing approved yet', style: Theme.of(context).textTheme.titleSmall),
                                    const SizedBox(height: 2),
                                    Text('Expenses show here once everyone in the split approves.',
                                        textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
                                  ],
                                ),
                              )
                            : Column(
                                children: [
                                  for (var i = 0; i < recent.length; i++) ...[
                                    if (i > 0) Divider(height: 1, color: p.hairline),
                                    ExpenseTile(
                                      expense: recent[i],
                                      symbol:  symbol,
                                      myUid:   user.uid,
                                      onTap:   () => context.push(
                                          '${AppRoutes.expenseDetail}?expenseId=${recent[i].expenseId}&groupId=${group.groupId}'),
                                    ),
                                  ],
                                ],
                              ),
                  ),

                  if (isAdmin) LeaveRequestsSection(groupCtrl: groupCtrl),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Things only this member can move forward: shares to approve, payments
  /// to confirm, bKash requests to answer.
  List<AttentionItem> _attentionItems(
    BuildContext context,
    NotificationController notifs,
    DebtController debts,
    String groupId,
    String symbol,
  ) {
    final items = <AttentionItem>[];

    for (final pay in debts.pendingForMe.take(3)) {
      items.add(AttentionItem(
        icon:     Icons.payments_rounded,
        tone:     ChipTone.positive,
        title:    '${firstName(pay.fromUserName)} paid you ${Money.displayCompact(pay.amount, symbol)}',
        subtitle: 'Confirm you received it · ${timeAgo(pay.loggedAt)}',
        onTap:    () => context.push('${AppRoutes.paymentReview}?paymentId=${pay.paymentId}&groupId=$groupId'),
      ));
    }

    for (final n in notifs.notifications.where((n) => !n.isRead && n.groupId == groupId)) {
      if (items.length >= 5) break;
      if (n.type == AppConstants.notifExpensePendingApproval) {
        items.add(AttentionItem(
          icon:     Icons.fact_check_rounded,
          tone:     ChipTone.pending,
          title:    _shorten(n.message),
          subtitle: 'Approve or reject your share · ${timeAgo(n.createdAt)}',
          onTap: () {
            notifs.markAsRead(n.notificationId);
            context.push('${AppRoutes.expenseDetail}?expenseId=${n.referenceId}&groupId=$groupId');
          },
        ));
      } else if (n.type == AppConstants.notifBkashRequested) {
        items.add(AttentionItem(
          icon:     Icons.lock_open_rounded,
          tone:     ChipTone.info,
          title:    _shorten(n.message),
          subtitle: 'Choose whether to share it · ${timeAgo(n.createdAt)}',
          onTap: () {
            notifs.markAsRead(n.notificationId);
            showBkashRequestSheet(context, n, groupId);
          },
        ));
      }
    }
    return items;
  }

  /// Notification text without the trailing "Tap to ..." instruction.
  static String _shorten(String message) =>
      message.replaceAll(RegExp(r'\s*Tap to [^.]*\.?$'), '').trim();
}

class _RowSkeleton extends StatelessWidget {
  const _RowSkeleton();

  @override
  Widget build(BuildContext context) => const Row(
        children: [
          Skeleton(width: 44, height: 44, radius: 14),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [Skeleton(width: 150, height: 13), SizedBox(height: 8), Skeleton(width: 100, height: 11)],
            ),
          ),
          Skeleton(width: 60, height: 15),
        ],
      );
}
