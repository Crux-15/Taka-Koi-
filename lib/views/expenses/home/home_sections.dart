import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../models/group_model.dart';
import '../../../utils/app_router.dart';
import '../../../widgets/common/avatar_widget.dart';
import '../../../widgets/common/theme_switch_widget.dart';
import '../../../widgets/ui/ui.dart';

/// Top of Home: tour name, who's in it, and the admin's manage button.
class HomeHeader extends StatelessWidget {
  final GroupModel group;
  final bool isAdmin;

  const HomeHeader({super.key, required this.group, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    final p       = context.palette;
    final t       = Theme.of(context).textTheme;
    final members = group.members.values.toList()..sort((a, b) => a.joinedAt.compareTo(b.joinedAt));

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 7, height: 7,
                    decoration: BoxDecoration(color: p.positive, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text('ACTIVE TOUR · SINCE ${DateFormat('d MMM').format(group.createdAt).toUpperCase()}',
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.overline(p.textMuted)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(group.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Row(
                children: [
                  AvatarStack(
                    names:     members.map((m) => m.name).toList(),
                    imageUrls: members.map((m) => m.avatarUrl).toList(),
                    uids:      members.map((m) => m.userId).toList(),
                    size:      24,
                    max:       5,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text('${members.length} ${members.length == 1 ? 'member' : 'members'}',
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodySmall),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        if (isAdmin) ...[
          _RoundButton(
            icon:    Icons.tune_rounded,
            tooltip: 'Manage tour',
            onTap:   () => context.push(AppRoutes.adminDashboard),
          ),
          const SizedBox(width: 8),
        ],
        const ThemeSwitchWidget(),
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _RoundButton({required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Tooltip(
      message: tooltip,
      child: Pressable(
        onTap: onTap,
        child: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: p.surface, shape: BoxShape.circle, border: Border.all(color: p.hairline)),
          child: Icon(icon, size: 19, color: p.text),
        ),
      ),
    );
  }
}

class QuickAction {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int badge;
  const QuickAction(this.icon, this.label, this.onTap, {this.badge = 0});
}

/// A row of round shortcut buttons under the balance card.
class QuickActions extends StatelessWidget {
  final List<QuickAction> actions;
  const QuickActions({super.key, required this.actions});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        for (final a in actions)
          Pressable(
            onTap: a.onTap,
            child: SizedBox(
              width: 76,
              child: Column(
                children: [
                  Badge(
                    isLabelVisible: a.badge > 0,
                    label: Text('${a.badge}'),
                    offset: const Offset(-2, 2),
                    child: Container(
                      width: 54, height: 54,
                      decoration: BoxDecoration(
                        color:        p.surface,
                        borderRadius: BorderRadius.circular(18),
                        border:       Border.all(color: p.hairline),
                        boxShadow:    p.cardShadow,
                      ),
                      child: Icon(a.icon, color: p.accent, size: 23),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(a.label, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(color: p.text, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class AttentionItem {
  final IconData icon;
  final ChipTone tone;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const AttentionItem({required this.icon, required this.tone, required this.title, required this.subtitle, required this.onTap});
}

/// "Needs you": approvals and payments waiting on the signed-in member.
class AttentionCard extends StatelessWidget {
  final List<AttentionItem> items;
  const AttentionCard({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) Divider(height: 1, color: p.hairline),
            Pressable(
              onTap: items[i].onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    IconTile(items[i].icon, size: 40, radius: 13, color: _toneColor(p, items[i].tone)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(items[i].title, maxLines: 2, overflow: TextOverflow.ellipsis,
                              style: t.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(items[i].subtitle, style: t.bodySmall),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: p.textFaint),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static Color _toneColor(AppPalette p, ChipTone tone) => switch (tone) {
        ChipTone.positive => p.positive,
        ChipTone.negative => p.negative,
        ChipTone.pending  => p.pending,
        ChipTone.info     => p.info,
        _                 => p.accent,
      };
}
