import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/expense_controller.dart';
import '../../controllers/group_controller.dart';
import '../../models/group_model.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_router.dart';
import '../../widgets/common/avatar_widget.dart';
import '../../widgets/common/loading_widget.dart';
import '../../widgets/common/theme_switch_widget.dart';

/// Home dashboard — privacy-respecting expense summary screen.
class HomeView extends StatefulWidget {
  const HomeView({super.key});
  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  bool _streamsInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initStreams());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Also attempt here in case the group stream emits after initState
    if (!_streamsInitialized) _initStreams();
  }

  void _initStreams() {
    final auth     = context.read<AuthController>();
    final group    = context.read<GroupController>();
    final exp      = context.read<ExpenseController>();
    final gid      = group.activeGroup?.groupId;
    final uid      = auth.user?.uid;
    if (gid == null || uid == null) return;
    if (_streamsInitialized) return;
    _streamsInitialized = true;
    exp.listenToApprovedExpenses(gid);
    exp.listenToMyExpenses(gid, uid);
  }

  @override
  Widget build(BuildContext context) {
    final auth     = context.watch<AuthController>();
    final groupCtrl= context.watch<GroupController>();
    final expCtrl  = context.watch<ExpenseController>();
    final group    = groupCtrl.activeGroup;
    final user     = auth.user;
    final scheme   = Theme.of(context).colorScheme;

    if (group == null || user == null) return const Center(child: AppLoader());

    final isAdmin      = group.adminId == user.uid;
    final memberTotals = expCtrl.computeMemberTotals();
    final myTotal      = memberTotals[user.uid] ?? 0.0;

    // Show ALL members, sorted by total (descending). Users with no expenses show ₹0.00.
    final allOtherMembers = group.members.values
        .where((m) => m.userId != user.uid)
        .toList()
      ..sort((a, b) => (memberTotals[b.userId] ?? 0.0)
          .compareTo(memberTotals[a.userId] ?? 0.0));

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => _initStreams(),
        child: CustomScrollView(
          slivers: [
            // ── App Bar ───────────────────────────────────────────────────
            SliverAppBar(
              title: Text(group.name),
              pinned: true,
              actions: [
                if (isAdmin)
                  Padding(
                    padding: const EdgeInsets.only(right: 6, top: 8, bottom: 8),
                    child: GestureDetector(
                      onTap: () => context.push(AppRoutes.adminDashboard),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          gradient:     AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color:      AppColors.primary.withOpacity(0.35),
                              blurRadius: 8,
                              offset:     const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.tune_rounded, color: Color(0xFF1A1A1A), size: 16),
                            SizedBox(width: 6),
                            Text(
                              'Manage Group',
                              style: TextStyle(
                                color:      Color(0xFF1A1A1A),
                                fontSize:   12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                const ThemeSwitchWidget(),
                const SizedBox(width: 8),
              ],
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
              sliver: SliverList(
                delegate: SliverChildListDelegate([

                  // ── My Total Card (tappable) ──────────────────────────────
                  GestureDetector(
                    onTap: () => context.push(AppRoutes.expenseHistory),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient:     AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow:    [BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 24, offset: const Offset(0, 10))],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              AvatarWidget(imageUrl: user.avatarUrl, name: user.name, size: 40, showBorder: true),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'My Total Expenses',
                                      style: TextStyle(color: Color(0x996D5700), fontSize: 13),  // dark amber-brown, subtle
                                    ),
                                    Text(
                                      user.name,
                                      style: const TextStyle(color: Color(0xFF1A1A1A), fontWeight: FontWeight.w700, fontSize: 15),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios_rounded, color: Color(0x881A1A1A), size: 16),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Text(
                            '${group.currencySymbol}${myTotal.toStringAsFixed(2)}',
                            style: const TextStyle(color: Color(0xFF0D0D0D), fontSize: 36, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Tap to view detailed history',
                            style: TextStyle(color: Color(0x886D5700), fontSize: 12),  // muted dark amber
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ── Other Members ─────────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Group Members', style: Theme.of(context).textTheme.titleMedium),
                      Text('${group.members.length} members', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (allOtherMembers.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('No other members yet. Share the group code to invite!',
                          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14)),
                    )
                  else
                    ...allOtherMembers.asMap().entries.map((e) {
                      final member = e.value;
                      return _MemberTotalCard(
                        member:    member,
                        total:     memberTotals[member.userId] ?? 0.0,
                        symbol:    group.currencySymbol,
                        rank:      e.key + 1,
                        isAdmin:   isAdmin,
                        groupCtrl: groupCtrl,
                      );
                    }),

                  // ── Leave Requests (admin only) ───────────────────────────
                  if (isAdmin)
                    StreamBuilder<List<Map<String, dynamic>>>(
                      stream: groupCtrl.leaveRequestsStream(),
                      builder: (ctx, snap) {
                        final requests = snap.data ?? [];
                        if (requests.isEmpty) return const SizedBox.shrink();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 24),
                            Row(children: [
                              const Icon(Icons.exit_to_app_rounded, color: AppColors.error, size: 20),
                              const SizedBox(width: 8),
                              Text('Leave Requests', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.error)),
                            ]),
                            const SizedBox(height: 10),
                            ...requests.map((req) {
                              final memberId   = req['memberId'] as String? ?? '';
                              final memberName = req['memberName'] as String? ?? 'Member';
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  child: Row(children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(memberName, style: const TextStyle(fontWeight: FontWeight.w700)),
                                          const Text('Requested to leave', style: TextStyle(fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () async {
                                        final ok = await groupCtrl.rejectLeave(memberId: memberId, memberName: memberName);
                                        if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(
                                          SnackBar(content: Text(ok ? 'Request rejected.' : 'Failed.'), backgroundColor: ok ? AppColors.warning : AppColors.error),
                                        );
                                      },
                                      child: const Text('Reject', style: TextStyle(color: AppColors.error)),
                                    ),
                                    const SizedBox(width: 4),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                                      onPressed: () async {
                                        final ok = await groupCtrl.approveLeave(memberId: memberId, memberName: memberName);
                                        if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(
                                          SnackBar(content: Text(ok ? '$memberName removed from group.' : 'Failed.'), backgroundColor: ok ? AppColors.success : AppColors.error),
                                        );
                                      },
                                      child: const Text('Approve', style: TextStyle(color: Colors.white)),
                                    ),
                                  ]),
                                ),
                              );
                            }),
                          ],
                        );
                      },
                    ),
                ]),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: ElevatedButton.icon(
        onPressed: () => context.push(AppRoutes.logExpense),
        icon:  const Icon(Icons.add_rounded, size: 22),
        label: const Text(
          'Log Expense',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        style: ElevatedButton.styleFrom(
          padding:         const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape:           RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          elevation:       6,
          shadowColor:     Theme.of(context).colorScheme.primary.withOpacity(0.4),
        ),
      ),
    );
  }
}

class _MemberTotalCard extends StatelessWidget {
  final GroupMember member;
  final double      total;
  final String      symbol;
  final int         rank;
  final bool        isAdmin;
  final GroupController groupCtrl;
  const _MemberTotalCard({
    required this.member,
    required this.total,
    required this.symbol,
    required this.rank,
    required this.isAdmin,
    required this.groupCtrl,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showMemberSheet(context, scheme),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Rank badge
              Container(
                width: 28, height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: rank == 1 ? const Color(0xFFFFC107) : scheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: Text('$rank',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                        color: rank == 1 ? Colors.white : scheme.onSurfaceVariant)),
              ),
              const SizedBox(width: 12),
              AvatarWidget(imageUrl: member.avatarUrl, name: member.name, size: 40),
              const SizedBox(width: 12),
              Expanded(child: Text(member.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15))),
              Text('$symbol${total.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: scheme.primary)),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, size: 18, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  void _showMemberSheet(BuildContext context, ColorScheme scheme) {
    final myUid = context.read<AuthController>().user?.uid ?? '';
    final isMe  = member.userId == myUid;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: scheme.onSurfaceVariant.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Avatar + Name
              AvatarWidget(imageUrl: member.avatarUrl, name: member.name, size: 64),
              const SizedBox(height: 12),
              Text(member.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              Text('Member since ${_formatDate(member.joinedAt)}',
                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
              const SizedBox(height: 24),

              // Stats row
              Row(
                children: [
                  Expanded(child: _StatBox(
                    label: 'Total Expenses',
                    value: '$symbol${total.toStringAsFixed(2)}',
                    icon:  Icons.receipt_long_rounded,
                    color: AppColors.primary,
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _StatBox(
                    label: 'Status',
                    value: member.hasApprovedExpense ? 'Has Expenses' : 'No Expenses',
                    icon:  member.hasApprovedExpense
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: member.hasApprovedExpense ? AppColors.success : scheme.onSurfaceVariant,
                  )),
                ],
              ),
              const SizedBox(height: 20),

              // Admin: Remove member (only if no approved expenses)
              if (isAdmin && !isMe) ...[
                if (!member.hasApprovedExpense)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon:    const Icon(Icons.person_remove_rounded, color: AppColors.error),
                      label:   const Text('Remove from Group', style: TextStyle(color: AppColors.error)),
                      style:   OutlinedButton.styleFrom(
                        side:    const BorderSide(color: AppColors.error),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape:   RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => _confirmRemove(context, sheetCtx),
                    ),
                  ),
                if (member.hasApprovedExpense)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'This member has approved expenses and cannot be removed.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                    ),
                  ),
              ],

              // Member viewing their own card: Leave Group option
              if (isMe && !isAdmin) ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon:    const Icon(Icons.exit_to_app_rounded, color: AppColors.error),
                    label:   const Text('Request to Leave Group', style: TextStyle(color: AppColors.error)),
                    style:   OutlinedButton.styleFrom(
                      side:    const BorderSide(color: AppColors.error),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape:   RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => _confirmLeaveRequest(context, sheetCtx),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Your leave request will be sent to the admin for approval.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                  ),
                ),
              ],

              // ── bKash Number Section (never shown for own card) ───────────
              if (!isMe) ...[
                const SizedBox(height: 4),
                _BkashSection(
                  homeCtx:       context,
                  requesterId:   myUid,
                  requesterName: context.read<AuthController>().user?.name ?? '',
                  targetId:      member.userId,
                  targetName:    member.name,
                  groupCtrl:     groupCtrl,
                ),
              ],

              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _confirmLeaveRequest(BuildContext homeCtx, BuildContext sheetCtx) {
    Navigator.of(sheetCtx).pop();
    showDialog(
      context: homeCtx,
      barrierDismissible: true,
      builder: (dialogCtx) => AlertDialog(
        title:   const Text('Leave Group?'),
        content: const Text('Your request will be sent to the admin. You will be removed once approved. Your recorded expenses and debts will remain.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogCtx).pop();
              final ok = await groupCtrl.requestLeave(
                userId:   member.userId,
                userName: member.name,
              );
              if (!homeCtx.mounted) return;
              ScaffoldMessenger.of(homeCtx).showSnackBar(SnackBar(
                content: Text(ok
                    ? 'Leave request sent to admin.'
                    : 'Failed to send request. Try again.'),
                backgroundColor: ok ? AppColors.success : AppColors.error,
              ));
            },
            child: const Text('Send Request', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _confirmRemove(BuildContext homeCtx, BuildContext sheetCtx) {
    Navigator.of(sheetCtx).pop(); // close bottom sheet first
    showDialog(
      context: homeCtx,
      barrierDismissible: true,
      builder: (dialogCtx) => AlertDialog(
        title:   Text('Remove ${member.name}?'),
        content: const Text('They will be removed from the group but can rejoin using the group code.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              groupCtrl.removeMember(member.userId);
            },
            child: const Text('Remove', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.day}/${dt.month}/${dt.year}';
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatBox({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: color)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

// ── bKash Number Section ──────────────────────────────────────────────────────
/// Shown inside every member's bottom sheet (never for own card).
/// Displays a request button, pending state, or accepted number with copy.
class _BkashSection extends StatelessWidget {
  final BuildContext  homeCtx;
  final String        requesterId;
  final String        requesterName;
  final String        targetId;
  final String        targetName;
  final GroupController groupCtrl;

  const _BkashSection({
    required this.homeCtx,
    required this.requesterId,
    required this.requesterName,
    required this.targetId,
    required this.targetName,
    required this.groupCtrl,
  });

  @override
  Widget build(BuildContext context) {
    final scheme    = Theme.of(context).colorScheme;
    final groupId   = groupCtrl.activeGroup?.groupId ?? '';
    final groupName = groupCtrl.activeGroup?.name    ?? '';

    return StreamBuilder<String?>(
      stream: groupCtrl.bkashStatusStream(groupId, requesterId, targetId),
      builder: (ctx, snap) {
        final status = snap.data; // 'pending' | 'accepted' | 'declined' | null

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(height: 28),
            Row(children: [
              const Icon(Icons.phone_android_rounded, size: 17, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text('bKash Number', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            ]),
            const SizedBox(height: 10),

            // ── ACCEPTED: show number or "not set" ──────────────────────────
            if (status == 'accepted') ...[
              FutureBuilder<String?>(
                future: groupCtrl.fetchMemberBkash(targetId),
                builder: (ctx2, bkSnap) {
                  if (bkSnap.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2)));
                  }
                  final number = bkSnap.data ?? '';
                  if (number.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(children: [
                        const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.warning),
                        const SizedBox(width: 8),
                        Expanded(child: Text(
                          "$targetName hasn't set a bKash number yet.",
                          style: const TextStyle(fontSize: 13),
                        )),
                      ]),
                    );
                  }
                  // Number available — show with copy button
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color:  AppColors.primary.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.primary.withOpacity(0.35), width: 1.5),
                    ),
                    child: Row(children: [
                      const Icon(Icons.phone_android_rounded, size: 18, color: AppColors.primaryDark),
                      const SizedBox(width: 10),
                      Expanded(child: Text(
                        number,
                        style: const TextStyle(
                          fontSize:   17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: AppColors.primaryDark,
                        ),
                      )),
                      IconButton(
                        icon:    const Icon(Icons.copy_rounded, size: 20, color: AppColors.primaryDark),
                        tooltip: 'Copy number',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: number));
                          ScaffoldMessenger.of(homeCtx).showSnackBar(const SnackBar(
                            content: Text('✅ bKash number copied!'),
                            duration: Duration(seconds: 2),
                          ));
                        },
                      ),
                    ]),
                  );
                },
              ),

            // ── PENDING: waiting for target to respond ───────────────────────
            ] else if (status == 'pending') ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(children: [
                  const Icon(Icons.schedule_rounded, size: 16, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    'Waiting for $targetName to accept your request...',
                    style: const TextStyle(fontSize: 13),
                  )),
                ]),
              ),

            // ── DEFAULT (null/declined): show hidden state + request button ──
            ] else ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(children: [
                  Icon(Icons.lock_rounded, size: 16, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Text('bKash number is hidden.',
                      style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
                ]),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon:  const Icon(Icons.phone_android_rounded, size: 18),
                  label: const Text('Request bKash Number'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryDark,
                    side:  const BorderSide(color: AppColors.primary, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    minimumSize: Size.zero,
                    textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  onPressed: () async {
                    final ok = await groupCtrl.requestBkash(
                      groupId:      groupId,
                      requesterId:  requesterId,
                      requesterName:requesterName,
                      targetId:     targetId,
                      targetName:   targetName,
                      groupName:    groupName,
                    );
                    if (homeCtx.mounted) {
                      ScaffoldMessenger.of(homeCtx).showSnackBar(SnackBar(
                        content: Text(ok
                            ? 'Request sent to $targetName! 📲'
                            : 'Failed to send request. Try again.'),
                        backgroundColor: ok ? AppColors.success : AppColors.error,
                      ));
                    }
                  },
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
