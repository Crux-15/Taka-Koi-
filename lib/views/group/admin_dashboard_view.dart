import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/group_controller.dart';
import '../../models/group_model.dart';
import '../../utils/app_colors.dart';
import '../../widgets/common/avatar_widget.dart';
import '../../widgets/common/empty_state_widget.dart';
import '../../widgets/common/loading_widget.dart';
import '../../widgets/common/theme_switch_widget.dart';
import '../../widgets/ui/ui.dart';
import '../profile/widgets/group_code_tile.dart';

/// Group Settings — only accessible to the group creator.
class AdminDashboardView extends StatefulWidget {
  const AdminDashboardView({super.key});
  @override
  State<AdminDashboardView> createState() => _AdminDashboardViewState();
}

class _AdminDashboardViewState extends State<AdminDashboardView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final groupCtrl = context.watch<GroupController>();
    final auth      = context.watch<AuthController>();
    final group     = groupCtrl.activeGroup;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tour settings'),
        actions: const [ThemeSwitchWidget(), SizedBox(width: 16)],
        bottom: PillTabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Members'),
            Tab(text: 'Join code'),
          ],
        ),
      ),
      body: group == null
          ? const Center(child: AppLoader())
          : TabBarView(
              controller: _tabs,
              children: [
                _MembersTab(group: group, groupCtrl: groupCtrl, currentUid: auth.user?.uid ?? ''),
                _GroupCodeTab(group: group, groupCtrl: groupCtrl),
              ],
            ),
    );
  }
}

// ── Members Tab ───────────────────────────────────────────────────────────────
class _MembersTab extends StatelessWidget {
  final GroupModel       group;
  final GroupController  groupCtrl;
  final String           currentUid;
  const _MembersTab({required this.group, required this.groupCtrl, required this.currentUid});

  @override
  Widget build(BuildContext context) {
    final members = group.members.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    if (members.isEmpty) {
      return const EmptyStateWidget(
        icon:     Icons.people_alt_outlined,
        title:    'No Members Yet',
        subtitle: 'Share the join code to invite people.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount:        members.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final m       = members[i];
        final isAdmin = m.userId == group.adminId;
        final isSelf  = m.userId == currentUid;
        return Card(
          child: ListTile(
            leading:  AvatarWidget(imageUrl: m.avatarUrl, uid: m.userId, name: m.name, size: 44),
            title:    Text(m.name, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(isAdmin ? 'Started the tour' : 'Member',
                style: TextStyle(fontSize: 12, color: isAdmin ? AppColors.primary : null)),
            trailing: !isAdmin && !isSelf
                ? IconButton(
                    icon:    const Icon(Icons.person_remove_rounded),
                    color:   AppColors.error,
                    tooltip: 'Remove member',
                    onPressed: () => _confirmRemove(context, m),
                  )
                : null,
          ),
        );
      },
    );
  }

  void _confirmRemove(BuildContext context, GroupMember m) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) => AlertDialog(
        title:   Text('Remove ${m.name}?'),
        content: const Text('This person will be removed from the group. They can rejoin with the code.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogCtx).pop();
              final messenger = ScaffoldMessenger.of(context);
              final ok = await groupCtrl.removeMember(m.userId);
              if (!ok) {
                messenger.showSnackBar(SnackBar(
                  content:         Text(groupCtrl.errorMessage ?? 'Couldn\'t remove ${m.name}.'),
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
}

class _GroupCodeTab extends StatelessWidget {
  final GroupModel group;
  final GroupController groupCtrl;
  const _GroupCodeTab({required this.group, required this.groupCtrl});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        AppCard(child: GroupCodeTile(group: group, groupCtrl: groupCtrl)),
        const SizedBox(height: 14),
        const InfoBanner(
          'Codes last an hour, so an old message with the code can\'t be used later. '
          'Make a new one whenever you invite someone.',
          icon: Icons.shield_rounded,
          tone: ChipTone.accent,
        ),
      ],
    );
  }
}

