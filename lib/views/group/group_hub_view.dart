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
import '../../widgets/common/loading_widget.dart';
import '../../widgets/common/theme_switch_widget.dart';
import 'past_tour_detail_view.dart';

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
    if (confirm != true || !mounted) return;
    // Sign out first — router refreshListenable handles navigation to /login
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('activeGroupId');
    if (!mounted) return;
    await context.read<AuthController>().signOut();
  }

  @override
  Widget build(BuildContext context) {
    final auth    = context.watch<AuthController>();
    final group   = context.watch<GroupController>();
    final scheme  = Theme.of(context).colorScheme;
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
                  tooltip: 'Sign Out',
                  onPressed: () => _signOut(context),
                ),
                const SizedBox(width: 4),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(gradient: AppColors.heroGradient),
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
                                style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              backgroundColor: AppColors.primary,
            ),

            // ── Action Cards ──────────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Create Group Card
                  _ActionCard(
                    gradient:   AppColors.primaryGradient,
                    icon:       Icons.group_add_rounded,
                    title:      'Start a New Tour',
                    subtitle:   'Create a group and invite your travel mates',
                    onTap:      () => context.push(AppRoutes.createGroup),
                    textColor:  Colors.white,
                  ),
                  const SizedBox(height: 16),

                  // Join Group Card
                  _ActionCard(
                    gradient:   null,
                    icon:       Icons.qr_code_rounded,
                    title:      'Join an Existing Tour',
                    subtitle:   'Enter the group code shared by your admin',
                    onTap:      () => context.push(AppRoutes.joinGroup),
                    textColor:  scheme.onSurface,
                    outlined:   true,
                  ),
                  const SizedBox(height: 32),

                  // Past Tours header
                  if (group.history.isNotEmpty) ...[
                    Text('Past Tours', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    ...group.history.map((g) => _HistoryGroupCard(group: g)),
                  ] else ...[
                    const SizedBox(height: 16),
                    EmptyState(
                      icon:     Icons.history_rounded,
                      title:    'No Past Tours',
                      subtitle: 'Your completed tours will appear here.',
                    ),
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
  final bool      outlined;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.textColor,
    this.gradient,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
                ? [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))]
                : [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color:  gradient != null ? Colors.white.withOpacity(0.2) : AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, size: 28, color: gradient != null ? Colors.white : AppColors.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,    style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: TextStyle(color: gradient != null ? Colors.white70 : scheme.onSurfaceVariant, fontSize: 13)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, size: 16, color: gradient != null ? Colors.white70 : scheme.onSurfaceVariant),
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
              final uid = context.read<AuthController>().user?.uid ?? '';
              await context.read<GroupController>().removeFromHistory(
                groupId: group.groupId,
                userId:  uid,
              );
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
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.travel_explore_rounded, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(group.name,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(
                      '${group.members.length} members • ${group.currencySymbol} ${group.currency}',
                      style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              // View badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color:        AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('View',
                    style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
              ),
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
