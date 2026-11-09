import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/group_controller.dart';
import '../../models/group_model.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_router.dart';
import '../../widgets/common/avatar_widget.dart';
import '../../widgets/common/install_hint.dart';
import '../../widgets/common/theme_switch_widget.dart';
import 'past_tour_detail_view.dart';
import '../../widgets/ui/ui.dart';
import '../../utils/display_helpers.dart';

/// Screen shown when the user has no active group.
class GroupHubView extends StatefulWidget {
  const GroupHubView({super.key});
  @override
  State<GroupHubView> createState() => _GroupHubViewState();
}

class _GroupHubViewState extends State<GroupHubView> {

  @override
  void initState() {
    super.initState();
    // Load history on first mount
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadHistory());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Also reload when dependencies change (e.g. after router redirect puts
    // this widget back on screen following a group-end or leave-approval).
    _loadHistory();
  }

  void _loadHistory() {
    final userId = context.read<AuthController>().user?.uid;
    if (userId != null) {
      context.read<GroupController>().loadHistory(userId);
    }
  }

  Future<void> _signOut(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) => AlertDialog(
        title:   const Text('Sign Out?'),
        content: const Text('You will be returned to the login screen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Sign Out', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    final auth = context.read<AuthController>();
    // Sign out first — router refreshListenable handles navigation to /login
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('activeGroupId');
    await auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final auth    = context.watch<AuthController>();
    final group   = context.watch<GroupController>();
    final scheme  = Theme.of(context).colorScheme;
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final user    = auth.user;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── App Bar ───────────────────────────────────────────────────
            SliverAppBar(
              expandedHeight: 160,
              pinned: true,
              actions: [
                const ThemeSwitchWidget(),
                IconButton(
                  icon:    const Icon(Icons.logout_rounded, color: Colors.white),
                  tooltip: 'Sign out',
                  onPressed: () => _signOut(context),
                ),
                const SizedBox(width: 4),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: isDark
                        ? const LinearGradient(
                            colors: [AppColors.darkHeroStart, AppColors.darkHeroEnd],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          )
                        : const LinearGradient(
                            colors: [AppColors.poshObsidian, AppColors.obsidianWarm],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                  ),
                  padding: const EdgeInsets.fromLTRB(24, 60, 24, 20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      AvatarWidget(imageUrl: user?.avatarUrl, name: user?.name ?? 'U', size: 52, showBorder: true),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Hello, ${user?.name.split(' ').first ?? 'Traveller'}! 👋',
                                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text('Ready for your next adventure?',
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              backgroundColor: isDark ? AppColors.darkHeroEnd : AppColors.poshObsidian,
            ),

            // ── Action Cards ──────────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const InstallHint(),
                  // Create Group Card (Smart Posh Burnished Gold / Midnight Obsidian)
                  _ActionCard(
                    gradient: isDark
                        ? const LinearGradient(
                            colors: [AppColors.goldBright, AppColors.goldDeep],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : const LinearGradient(
                            colors: [AppColors.poshObsidian, AppColors.obsidianLight],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                    icon:          Icons.group_add_rounded,
                    title:         'Start a new tour',
                    subtitle:      'Start a tour and invite your friends',
                    onTap:         () => context.push(AppRoutes.createGroup),
                    textColor:     isDark ? AppColors.ink : Colors.white,
                    iconColor:     isDark ? AppColors.ink : Colors.white,
                    subtitleColor: isDark ? AppColors.inkMuted : Colors.white70,
                    shadowColor:   isDark ? AppColors.goldDeep.withValues(alpha: 0.24) : Colors.black.withValues(alpha: 0.18),
                  ),
                  const SizedBox(height: 16),

                  // Join Group Card
                  _ActionCard(
                    gradient:   null,
                    icon:       Icons.qr_code_rounded,
                    title:      'Join a tour',
                    subtitle:   'Got a 6-letter code from a friend? Join here',
                    onTap:      () => context.push(AppRoutes.joinGroup),
                    textColor:  scheme.onSurface,
                    iconColor:  isDark ? AppColors.primary : AppColors.poshGold,
                    outlined:   true,
                  ),
                  const SizedBox(height: 32),

                  // Past Tours header
                  if (group.history.isNotEmpty) ...[
                    Text('Past tours', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    ...group.history.map((g) => _HistoryGroupCard(group: g)),
                  ] else ...[
                    const _HowItWorks(),
                  ],
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final LinearGradient? gradient;
  final IconData  icon;
  final String    title;
  final String    subtitle;
  final VoidCallback onTap;
  final Color     textColor;
  final Color?    iconColor;
  final Color?    subtitleColor;
  final Color?    shadowColor;
  final bool      outlined;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.textColor,
    this.iconColor,
    this.subtitleColor,
    this.shadowColor,
    this.gradient,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final effectiveIconColor = iconColor ?? (gradient != null ? Colors.white : AppColors.primary);
    final effectiveSubtitleColor = subtitleColor ?? (gradient != null ? Colors.white70 : scheme.onSurfaceVariant);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            gradient:      gradient,
            color:         gradient == null ? scheme.surface : null,
            borderRadius:  BorderRadius.circular(20),
            border:        outlined ? Border.all(color: scheme.outline, width: 1.5) : null,
            boxShadow: gradient != null
                ? [BoxShadow(color: shadowColor ?? AppColors.primary.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))]
                : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color:  gradient != null ? effectiveIconColor.withValues(alpha: 0.18) : AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, size: 28, color: effectiveIconColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,    style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: TextStyle(color: effectiveSubtitleColor, fontSize: 13)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, size: 16, color: effectiveSubtitleColor),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryGroupCard extends StatelessWidget {
  final GroupModel group;
  const _HistoryGroupCard({required this.group});

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) => AlertDialog(
        title:   const Text('Remove from History?'),
        content: Text('This will remove "${group.name}" from your history. Other members will still see it.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogCtx).pop();
              final uid       = context.read<AuthController>().user?.uid ?? '';
              final groups    = context.read<GroupController>();
              final messenger = ScaffoldMessenger.of(context);
              final ok = await groups.removeFromHistory(
                groupId: group.groupId,
                userId:  uid,
              );
              if (!ok) {
                messenger.showSnackBar(SnackBar(
                  content:         Text(groups.errorMessage ?? 'Couldn\'t remove that tour.'),
                  backgroundColor: AppColors.error,
                ));
              }
            },
            child: const Text('Remove', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => PastTourDetailView(group: group)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
          child: Row(
            children: [
              const IconTile(Icons.luggage_rounded, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(group.name,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(
                      group.inactivatedAt != null
                          ? '${group.members.length} people · ended ${timeAgo(group.inactivatedAt!)}'
                          : '${group.members.length} people',
                      style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              // View badge
              const StatusChip('Open', tone: ChipTone.accent, icon: Icons.chevron_right_rounded),
              const SizedBox(width: 4),
              // Delete button
              IconButton(
                icon:    const Icon(Icons.delete_outline_rounded),
                color:   AppColors.error,
                tooltip: 'Remove from history',
                splashRadius: 20,
                onPressed: () => _confirmDelete(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// First-run guide: the whole app in four steps, for people new to it.
class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    const steps = [
      (Icons.group_add_rounded, 'Start or join a tour', 'One person starts it and shares a 6-letter code. Friends join with the code.'),
      (Icons.receipt_long_rounded, 'Add what you pay', 'Paid for dinner or tickets? Add it and choose who shares it.'),
      (Icons.fact_check_rounded, 'Everyone okays their share', 'Each person approves only their own part, so there are no surprises.'),
      (Icons.handshake_rounded, 'Settle up', 'See who owes whom, pay by bKash or cash, and the other person confirms.'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('How Taka Koi works', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        AppCard(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
          child: Column(
            children: [
              for (var i = 0; i < steps.length; i++) ...[
                if (i > 0) Divider(height: 1, color: p.hairline),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          IconTile(steps[i].$1, size: 42, radius: 13),
                          Positioned(
                            top: -5, left: -5,
                            child: Container(
                              width: 18, height: 18,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(color: p.accent, shape: BoxShape.circle),
                              child: Text('${i + 1}',
                                  style: TextStyle(fontFamily: AppType.display, fontSize: 10.5, fontWeight: FontWeight.w700, color: p.onAccent)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(steps[i].$2, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text(steps[i].$3, style: t.bodySmall),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
