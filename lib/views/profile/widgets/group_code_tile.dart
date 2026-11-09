import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../controllers/group_controller.dart';
import '../../../models/group_model.dart';
import '../../../widgets/ui/ui.dart';
import 'invite_sheet.dart';

/// The tour's join code, shown like a ticket: big spaced letters, how long
/// it stays valid, and copy / share / new-code actions.
class GroupCodeTile extends StatelessWidget {
  final GroupModel      group;
  final GroupController groupCtrl;
  const GroupCodeTile({super.key, required this.group, required this.groupCtrl});

  @override
  Widget build(BuildContext context) {
    final p            = context.palette;
    final t            = Theme.of(context).textTheme;
    final isExpired    = group.isCodeExpired;
    final minsLeft     = group.groupCodeExpiresAt.difference(DateTime.now()).inMinutes.clamp(0, 60);
    final isRefreshing = groupCtrl.isRefreshingCode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('JOIN CODE', style: AppType.overline(p.textMuted)),
            const Spacer(),
            StatusChip(
              isExpired ? 'Expired' : 'Valid for ${minsLeft}m',
              tone: isExpired ? ChipTone.negative : ChipTone.positive,
              icon: isExpired ? Icons.timer_off_rounded : Icons.timer_rounded,
              dense: true,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color:        p.soft(p.accent),
            borderRadius: BorderRadius.circular(16),
            border:       Border.all(color: p.accent.withValues(alpha: 0.30)),
          ),
          child: Text(
            group.groupCode,
            textAlign: TextAlign.center,
            style: AppType.money(28, color: isExpired ? p.textFaint : p.accent).copyWith(
              letterSpacing: 10,
              decoration:    isExpired ? TextDecoration.lineThrough : null,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          isExpired
              ? 'This code no longer works. Make a new one to invite people.'
              : 'Anyone with this code can join until it expires.',
          style: t.bodySmall,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _CodeAction(
                icon:  Icons.copy_rounded,
                label: 'Copy',
                onTap: isExpired
                    ? null
                    : () {
                        Clipboard.setData(ClipboardData(text: group.groupCode));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Code copied'), duration: Duration(seconds: 2)),
                        );
                      },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _CodeAction(
                icon:  Icons.ios_share_rounded,
                label: 'Share',
                onTap: isExpired ? null : () => showInviteSheet(context, group),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _CodeAction(
                icon:      Icons.autorenew_rounded,
                label:     'New code',
                highlight: isExpired,
                busy:      isRefreshing,
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  await groupCtrl.refreshGroupCode();
                  messenger.showSnackBar(SnackBar(
                    content: Text(groupCtrl.errorMessage ?? 'New code ready. Share it with your friends.'),
                  ));
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CodeAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool highlight;
  final bool busy;

  const _CodeAction({required this.icon, required this.label, this.onTap, this.highlight = false, this.busy = false});

  @override
  Widget build(BuildContext context) {
    final p       = context.palette;
    final enabled = onTap != null && !busy;
    final c       = !enabled ? p.textFaint : (highlight ? p.onAccent : p.text);
    return Pressable(
      onTap: enabled ? onTap : null,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color:        highlight ? p.accent : p.surfaceRaised,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            busy
                ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: c))
                : Icon(icon, size: 17, color: c),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontFamily: AppType.display, fontSize: 13, fontWeight: FontWeight.w600, color: c)),
          ],
        ),
      ),
    );
  }
}
