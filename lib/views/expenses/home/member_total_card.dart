import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../controllers/auth_controller.dart';
import '../../../controllers/group_controller.dart';
import '../../../models/group_model.dart';
import '../../../utils/app_colors.dart';
import '../../../widgets/common/avatar_widget.dart';
import '../../../widgets/ui/ui.dart';
import 'bkash_section.dart';

/// One row of the "Who's paid" leaderboard on Home: rank, avatar, name, a bar
/// showing their spend against the top spender, and the amount. Tapping opens
/// the member sheet (stats, bKash number, remove / leave).
class MemberTotalCard extends StatelessWidget {
  final GroupMember member;
  final double      total;
  final double      maxTotal;
  final String      symbol;
  final int         rank;
  final bool        isAdmin;
  final bool        isMe;
  final bool        isGroupAdmin;
  final GroupController groupCtrl;

  const MemberTotalCard({
    super.key,
    required this.member,
    required this.total,
    required this.symbol,
    required this.rank,
    required this.isAdmin,
    required this.groupCtrl,
    this.maxTotal     = 0,
    this.isMe         = false,
    this.isGroupAdmin = false,
  });

  @override
  Widget build(BuildContext context) {
    final p     = context.palette;
    final t     = Theme.of(context).textTheme;
    final ratio = maxTotal > 0 ? (total / maxTotal).clamp(0.0, 1.0) : 0.0;

    return Pressable(
      onTap: () => _showMemberSheet(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              child: Text('$rank',
                  textAlign: TextAlign.center,
                  style: AppType.money(14, color: rank == 1 && total > 0 ? p.accent : p.textFaint)),
            ),
            const SizedBox(width: 10),
            AvatarWidget(imageUrl: member.avatarUrl, uid: member.userId, name: member.name, size: 40, showBorder: rank == 1 && total > 0),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(isMe ? 'You' : member.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: t.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                      ),
                      if (isGroupAdmin) ...[
                        const SizedBox(width: 6),
                        const StatusChip('Admin', tone: ChipTone.accent, dense: true),
                      ],
                    ],
                  ),
                  const SizedBox(height: 7),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(100),
                    child: Stack(
                      children: [
                        Container(height: 5, color: p.surfaceSunken),
                        AnimatedFractionallySizedBox(
                          duration:    const Duration(milliseconds: 600),
                          curve:       Curves.easeOutCubic,
                          widthFactor: ratio,
                          child: Container(
                            height: 5,
                            decoration: BoxDecoration(
                              gradient: isMe ? AppColors.goldGradient : null,
                              color:    isMe ? null : p.textFaint.withValues(alpha: 0.55),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            MoneyText(total, symbol: symbol, size: 15, compact: true, color: total > 0 ? p.text : p.textFaint),
          ],
        ),
      ),
    );
  }

  void _showMemberSheet(BuildContext context) {
    final myUid = context.read<AuthController>().user?.uid ?? '';
    final me    = member.userId == myUid;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) {
        final p = sheetCtx.palette;
        final t = Theme.of(sheetCtx).textTheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AvatarWidget(imageUrl: member.avatarUrl, uid: member.userId, name: member.name, size: 72, showBorder: true),
                const SizedBox(height: 12),
                Text(member.name, style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('In this tour since ${DateFormat('d MMM y').format(member.joinedAt)}', style: t.bodySmall),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: _StatBox(
                        label: 'Paid for the tour',
                        child: MoneyText(total, symbol: symbol, size: 18, compact: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatBox(
                        label: 'Rank',
                        child: Text('#$rank', style: AppType.money(18, color: p.text)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // bKash number (never for your own card)
                if (!me)
                  BkashSection(
                    homeCtx:       context,
                    requesterId:   myUid,
                    requesterName: context.read<AuthController>().user?.name ?? '',
                    targetId:      member.userId,
                    targetName:    member.name,
                    groupCtrl:     groupCtrl,
                  ),

                // Admin: remove (only without approved expenses)
                if (isAdmin && !me) ...[
                  const SizedBox(height: 8),
                  if (!member.hasApprovedExpense)
                    _DangerButton(
                      icon:  Icons.person_remove_rounded,
                      label: 'Remove from tour',
                      onTap: () => _confirmRemove(context, sheetCtx),
                    )
                  else
                    Text('Part of approved expenses, so they can\'t be removed. They can ask to leave.',
                        textAlign: TextAlign.center, style: t.bodySmall),
                ],

                // Your own card: ask to leave
                if (me && !isAdmin) ...[
                  const SizedBox(height: 8),
                  _DangerButton(
                    icon:  Icons.logout_rounded,
                    label: 'Ask to leave this tour',
                    onTap: () => _confirmLeaveRequest(context, sheetCtx),
                  ),
                  const SizedBox(height: 6),
                  Text('The admin approves it. Your expenses and debts stay recorded.',
                      textAlign: TextAlign.center, style: t.bodySmall),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmLeaveRequest(BuildContext homeCtx, BuildContext sheetCtx) {
    Navigator.of(sheetCtx).pop();
    showDialog(
      context: homeCtx,
      builder: (dialogCtx) => AlertDialog(
        title:   const Text('Leave this tour?'),
        content: const Text('Your request goes to the admin, and you\'re removed once they approve. '
            'Your recorded expenses and debts remain.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogCtx).pop(), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogCtx).pop();
              final messenger = ScaffoldMessenger.of(homeCtx);
              final ok = await groupCtrl.requestLeave(userId: member.userId, userName: member.name);
              messenger.showSnackBar(SnackBar(
                content: Text(ok ? 'Leave request sent to the admin.' : (groupCtrl.errorMessage ?? 'Couldn\'t send the request. Try again.')),
              ));
            },
            child: Text('Send request', style: TextStyle(color: homeCtx.palette.negative)),
          ),
        ],
      ),
    );
  }

  void _confirmRemove(BuildContext homeCtx, BuildContext sheetCtx) {
    Navigator.of(sheetCtx).pop();
    showDialog(
      context: homeCtx,
      builder: (dialogCtx) => AlertDialog(
        title:   Text('Remove ${member.name}?'),
        content: const Text('They\'ll be removed from the tour but can rejoin with the join code.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogCtx).pop(), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogCtx).pop();
              final messenger = ScaffoldMessenger.of(homeCtx);
              final ok = await groupCtrl.removeMember(member.userId);
              if (!ok) {
                messenger.showSnackBar(SnackBar(
                  content: Text(groupCtrl.errorMessage ?? 'Couldn\'t remove ${member.name}.'),
                ));
              }
            },
            child: Text('Remove', style: TextStyle(color: homeCtx.palette.negative)),
          ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final Widget child;
  const _StatBox({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color:        p.surfaceRaised,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

class _DangerButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _DangerButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Pressable(
      onTap: onTap,
      child: Container(
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color:        p.soft(p.negative),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: p.negative),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontFamily: AppType.display, fontWeight: FontWeight.w600, fontSize: 14.5, color: p.negative)),
          ],
        ),
      ),
    );
  }
}
