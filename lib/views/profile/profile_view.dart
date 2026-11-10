import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/group_controller.dart';
import '../../controllers/theme_controller.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_constants.dart';
import '../../utils/app_router.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/avatar_widget.dart';
import '../../widgets/common/loading_widget.dart';
import '../../widgets/common/theme_switch_widget.dart';
import 'widgets/group_code_tile.dart';
import '../../widgets/ui/ui.dart';

/// Profile screen — view & edit profile, group management, theme, sign out.
class ProfileView extends StatefulWidget {
  const ProfileView({super.key});
  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  final _nameCtrl   = TextEditingController();
  final _bkashCtrl  = TextEditingController();
  Uint8List? _avatarFile;
  bool  _editing    = false;
  bool  _saving     = false;
  final _picker     = ImagePicker();

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthController>().user;
    if (user != null) {
      _nameCtrl.text  = user.name;
      _bkashCtrl.text = user.bkashNumber ?? '';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bkashCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 75, maxWidth: 512);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (mounted) setState(() { _avatarFile = bytes; _editing = true; });
  }

  Future<void> _saveProfile() async {
    final bkash = _bkashCtrl.text.trim();
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter your name.')));
      return;
    }
    if (bkash.isNotEmpty && !RegExp(r'^01[3-9]\d{8}$').hasMatch(bkash)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That bKash number doesn\'t look right. Use 11 digits, like 017XXXXXXXX.')),
      );
      return;
    }
    setState(() => _saving = true);
    final auth = context.read<AuthController>();
    final ok = await auth.updateProfile(
      name:        _nameCtrl.text.trim(),
      bkashNumber: _bkashCtrl.text.trim(),
      avatarFile:  _avatarFile,
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      // On failure keep the form open with what they typed, so they can retry.
      if (ok) {
        _editing    = false;
        _avatarFile = null;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:         Text(ok ? 'Profile updated!' : auth.errorMessage ?? 'Update failed.'),
      backgroundColor: ok ? AppColors.success : AppColors.error,
    ));
  }

  Future<void> _signOut() async {
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

    // Sign out FIRST — the refreshListenable on the router will automatically
    // redirect to /login once isAuth becomes false.
    // (Navigating to /login BEFORE signOut caused the router to override it back
    // to /home because isAuth was still true at that moment.)
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('activeGroupId');
    if (!mounted) return;
    await context.read<AuthController>().signOut();
    // Also clear the group stream so stale data doesn't flash on next login
    if (mounted) context.read<GroupController>().clearGroup();
  }

  @override
  Widget build(BuildContext context) {
    final auth      = context.watch<AuthController>();
    final groupCtrl = context.watch<GroupController>();
    final themeCtrl = context.watch<ThemeController>();
    final user      = auth.user;
    final group     = groupCtrl.activeGroup;
    final isAdmin   = group != null && group.adminId == user?.uid;
    final p         = context.palette;
    final t         = Theme.of(context).textTheme;

    if (user == null) return const Center(child: AppLoader());

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverSafeArea(
            bottom: false,
            sliver: SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Expanded(child: Text('Profile', style: t.headlineMedium)),
                    const ThemeSwitchWidget(),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            sliver: SliverList.list(
              children: [
                // ── Identity ────────────────────────────────────────────────
                AppCard(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
                  child: Column(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          _avatarFile != null
                              ? ClipOval(child: Image.memory(_avatarFile!, width: 96, height: 96, fit: BoxFit.cover))
                              : AvatarWidget(imageUrl: user.avatarUrl, uid: user.uid, name: user.name, size: 96, showBorder: true, onTap: _pickAvatar),
                          Positioned(
                            bottom: 2, right: 2,
                            child: Pressable(
                              onTap: _pickAvatar,
                              child: Container(
                                width: 34, height: 34,
                                decoration: BoxDecoration(
                                  color:  p.isDark ? AppColors.primary : AppColors.poshObsidian,
                                  shape:  BoxShape.circle,
                                  border: Border.all(color: p.surface, width: 3),
                                ),
                                child: Icon(Icons.photo_camera_rounded, size: 16,
                                    color: p.isDark ? AppColors.ink : Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(user.name, style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w700), textAlign: TextAlign.center),
                      const SizedBox(height: 4),
                      Text(user.email, style: t.bodyMedium?.copyWith(color: p.textMuted)),
                      if (group != null) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          alignment: WrapAlignment.center,
                          children: [
                            StatusChip(group.name, icon: Icons.luggage_rounded),
                            if (isAdmin) const StatusChip('Tour admin', tone: ChipTone.accent, icon: Icons.verified_rounded),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // ── Your details ────────────────────────────────────────────
                const SizedBox(height: 24),
                const SectionHeader('Your details'),
                AppCard(
                  child: Column(
                    children: [
                      AppTextField(
                        label:      'Full name',
                        controller: _nameCtrl,
                        prefixIcon: Icons.badge_rounded,
                        onChanged:  (_) => setState(() => _editing = true),
                      ),
                      const SizedBox(height: 12),
                      AppTextField(
                        label:        'bKash number',
                        hint:         '01XXXXXXXXX',
                        controller:   _bkashCtrl,
                        prefixIcon:   Icons.account_balance_wallet_rounded,
                        keyboardType: TextInputType.phone,
                        onChanged:    (_) => setState(() => _editing = true),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(Icons.lock_rounded, size: 14, color: p.textFaint),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text('Only people you agree to share it with can see your bKash number.',
                                style: t.bodySmall),
                          ),
                        ],
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 220),
                        curve:    Curves.easeOutCubic,
                        child: _editing
                            ? Padding(
                                padding: const EdgeInsets.only(top: 16),
                                child: AppButton(
                                  label:     'Save changes',
                                  icon:      Icons.check_rounded,
                                  isLoading: _saving,
                                  onPressed: _saveProfile,
                                ),
                              )
                            : const SizedBox(width: double.infinity),
                      ),
                    ],
                  ),
                ),

                // ── Tour ────────────────────────────────────────────────────
                if (group != null) ...[
                  const SizedBox(height: 24),
                  SectionHeader(isAdmin ? 'Manage tour' : 'This tour'),
                  AppCard(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                    child: Column(
                      children: [
                        if (isAdmin) ...[
                          GroupCodeTile(group: group, groupCtrl: groupCtrl),
                          const SizedBox(height: 8),
                          Divider(height: 1, color: p.hairline),
                        ],
                        if (isAdmin && group.members.length > 1)
                          _SettingsRow(
                            icon:     Icons.admin_panel_settings_rounded,
                            title:    'Hand over admin',
                            subtitle: 'Make another member the admin',
                            onTap:    () => _showTransferAdminDialog(context, groupCtrl, group),
                          ),
                        if (isAdmin)
                          _SettingsRow(
                            icon:     Icons.flag_rounded,
                            title:    'End this tour',
                            subtitle: 'Moves it to everyone\'s history',
                            danger:   true,
                            onTap:    () => _confirmDeactivate(context, groupCtrl, group),
                          ),
                        if (!isAdmin)
                          _SettingsRow(
                            icon:     Icons.logout_rounded,
                            title:    'Leave this tour',
                            subtitle: 'The admin approves your request',
                            danger:   true,
                            onTap:    () => _confirmLeaveGroup(context, groupCtrl, group, user),
                          ),
                      ],
                    ),
                  ),
                ],

                // ── Preferences & account ───────────────────────────────────
                const SizedBox(height: 24),
                const SectionHeader('Preferences'),
                AppCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Column(
                    children: [
                      _SettingsRow(
                        icon:     themeCtrl.resolveIsDark(context) ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                        title:    'Dark mode',
                        subtitle: 'Easier on the eyes at night',
                        trailing: Switch(
                          value:     themeCtrl.resolveIsDark(context),
                          onChanged: (_) => themeCtrl.toggleTheme(context),
                        ),
                        onTap: () => themeCtrl.toggleTheme(context),
                      ),
                      Divider(height: 1, color: p.hairline),
                      _SettingsRow(
                        icon:     Icons.history_rounded,
                        title:    'Past tours',
                        subtitle: 'See old tours and settle what\'s left',
                        onTap:    () => context.push(AppRoutes.tourHistory),
                      ),
                      Divider(height: 1, color: p.hairline),
                      _SettingsRow(
                        icon:     Icons.logout_rounded,
                        title:    'Sign out',
                        danger:   true,
                        onTap:    _signOut,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Center(
                  child: Text('${AppConstants.appName}  ·  ${AppConstants.appTagline}',
                      style: t.bodySmall?.copyWith(color: p.textFaint)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showTransferAdminDialog(BuildContext context, GroupController groupCtrl, group) {
    final others = group.members.values
        .where((m) => m.userId != group.adminId)
        .toList();

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) => AlertDialog(
        title:   const Text('Hand over admin'),
        content: others.isEmpty
            ? const Text('No other members to transfer admin to.')
            : SizedBox(
                width: 300,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: others.map<Widget>((m) => ListTile(
                    leading:  const Icon(Icons.person_rounded),
                    title:    Text(m.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Tap to make admin'),
                    onTap: () async {
                      Navigator.of(dialogCtx).pop();
                      final messenger = ScaffoldMessenger.of(context);
                      final ok = await groupCtrl.transferAdmin(m.userId);
                      messenger.showSnackBar(SnackBar(
                        content: Text(ok
                            ? '${m.name} is now the tour admin.'
                            : groupCtrl.errorMessage ?? 'Couldn\'t hand over the admin role.'),
                        backgroundColor: ok ? AppColors.success : AppColors.error,
                      ));
                    },
                  )).toList(),
                ),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _confirmDeactivate(BuildContext context, GroupController groupCtrl, group) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) => AlertDialog(
        title:   const Text('End this tour?'),
        content: FutureBuilder<int>(
          future: groupCtrl.openDebtCount(group.groupId),
          builder: (_, snap) {
            final open = snap.data ?? 0;
            return Text(
              'Nobody can add new expenses after this, and everyone is told it ended.'
              '${open > 0 ? '\n\n$open ${open == 1 ? 'debt is' : 'debts are'} still unpaid. '
                  'People can still pay and confirm them from Past tours.' : ''}',
            );
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              // 1. Close the dialog first
              Navigator.pop(dialogCtx);
              if (!mounted) return;
              final rootNav   = Navigator.of(context, rootNavigator: true);
              final router    = GoRouter.of(context);
              final messenger = ScaffoldMessenger.of(context);

              // 2. Show a loading indicator while deactivating
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => const PopScope(
                  canPop: false,
                  child: Center(child: CircularProgressIndicator()),
                ),
              );

              // 3. Await the actual deactivation
              final ok = await groupCtrl.deactivateGroup(
                groupId:   group.groupId,
                memberIds: group.members.keys.toList(),
                groupName: group.name,
              );

              // 4. Dismiss loading dialog, then go to the group hub (or say why not)
              rootNav.pop();
              if (ok) {
                router.go(AppRoutes.groupHub);
              } else {
                messenger.showSnackBar(SnackBar(
                  content:         Text(groupCtrl.errorMessage ?? 'Couldn\'t end the tour.'),
                  backgroundColor: AppColors.error,
                ));
              }
            },
            child: const Text('End Tour', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _confirmLeaveGroup(BuildContext context, GroupController groupCtrl, group, user) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) => AlertDialog(
        title:   const Text('Leave this tour?'),
        content: const Text(
          'Your leave request will be sent to the admin for approval.\n\n'
          'Your expenses and debts will remain recorded even after you leave.\n'
          'You can rejoin later with the join code.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              if (!mounted) return;
              final messenger = ScaffoldMessenger.of(context);
              final ok = await groupCtrl.requestLeave(
                userId:   user.uid,
                userName: user.name,
              );
              messenger.showSnackBar(SnackBar(
                content: Text(ok
                    ? 'Leave request sent to admin. You\'ll be removed once approved.'
                    : (groupCtrl.errorMessage ?? 'Couldn\'t send the request. Try again.')),
                backgroundColor: ok ? AppColors.success : AppColors.error,
                duration: const Duration(seconds: 4),
              ));
            },
            child: const Text('Send Request', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

/// One tappable settings line: icon, title, optional subtitle and trailing.
class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool danger;
  final VoidCallback onTap;

  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trailing,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final c = danger ? p.negative : p.text;
    return Pressable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            IconTile(icon, size: 38, radius: 12, color: danger ? p.negative : p.accent),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: t.titleSmall?.copyWith(color: c, fontWeight: FontWeight.w600)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: t.bodySmall),
                  ],
                ],
              ),
            ),
            trailing ?? Icon(Icons.chevron_right_rounded, color: p.textFaint),
          ],
        ),
      ),
    );
  }
}
