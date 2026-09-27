import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/group_controller.dart';
import '../../models/group_model.dart';
import '../../utils/app_colors.dart';
import '../../widgets/common/avatar_widget.dart';
import '../../widgets/common/empty_state_widget.dart';
import '../../widgets/common/loading_widget.dart';
import '../../widgets/common/theme_switch_widget.dart';

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
        title: const Text('Group Settings'),
        actions: [const ThemeSwitchWidget(), const SizedBox(width: 16)],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Members'),
            Tab(text: 'Group Code'),
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
        subtitle: 'Share the group code to invite people.',
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
            leading:  AvatarWidget(imageUrl: m.avatarUrl, name: m.name, size: 44),
            title:    Text(m.name, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(isAdmin ? 'Group Creator' : 'Member',
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
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              groupCtrl.removeMember(m.userId);
            },
            child: const Text('Remove', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

// ── Group Code Tab ────────────────────────────────────────────────────────────
class _GroupCodeTab extends StatelessWidget {
  final GroupModel      group;
  final GroupController groupCtrl;
  const _GroupCodeTab({required this.group, required this.groupCtrl});

  @override
  Widget build(BuildContext context) {
    final scheme   = Theme.of(context).colorScheme;
    final isExpired = group.isCodeExpired;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 36),
            decoration: BoxDecoration(
              gradient:     AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                Text(
                  group.groupCode,
                  style: const TextStyle(
                    fontSize: 48, fontWeight: FontWeight.w900,
                    color: Colors.white, letterSpacing: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isExpired ? '⚠ Code expired — tap Refresh' : 'Share this code to invite members',
                  style: TextStyle(
                    color: isExpired ? Colors.orangeAccent : Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon:  const Icon(Icons.copy_rounded),
                  label: const Text('Copy Code'),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: group.groupCode));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Code copied to clipboard!')),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  icon:  const Icon(Icons.refresh_rounded),
                  label: const Text('Refresh Code'),
                  style: FilledButton.styleFrom(backgroundColor: scheme.secondary),
                  onPressed: groupCtrl.isLoading ? null : () => groupCtrl.refreshGroupCode(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            isExpired
                ? 'This code has expired. Refresh to generate a new one.'
                : 'Code valid until ${_formatExpiry(group.groupCodeExpiresAt)}',
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _formatExpiry(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} at ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

