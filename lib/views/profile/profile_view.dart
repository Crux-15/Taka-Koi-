import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// Profile screen — view & edit profile, group management, theme, sign out.
class ProfileView extends StatefulWidget {
  const ProfileView({super.key});
  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  final _nameCtrl   = TextEditingController();
  final _bkashCtrl  = TextEditingController();
  File? _avatarFile;
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
    if (picked != null) setState(() { _avatarFile = File(picked.path); _editing = true; });
  }

  Future<void> _saveProfile() async {
    setState(() => _saving = true);
    final ok = await context.read<AuthController>().updateProfile(
      name:        _nameCtrl.text.trim(),
      bkashNumber: _bkashCtrl.text.trim(),
      avatarFile:  _avatarFile,
    );
    setState(() { _saving = false; _editing = false; _avatarFile = null; });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:         Text(ok ? 'Profile updated!' : 'Update failed.'),
        backgroundColor: ok ? AppColors.success : AppColors.error,
      ));
    }
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
    final scheme    = Theme.of(context).colorScheme;

    if (user == null) return const Center(child: AppLoader());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [const ThemeSwitchWidget(), const SizedBox(width: 8)],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [

            // ── Avatar ────────────────────────────────────────────────────
            Center(
              child: Stack(
                children: [
                  _avatarFile != null
                      ? ClipOval(child: Image.file(_avatarFile!, width: 100, height: 100, fit: BoxFit.cover))
                      : AvatarWidget(imageUrl: user.avatarUrl, name: user.name, size: 100, showBorder: true, onTap: _pickAvatar),
                  Positioned(
                    bottom: 0, right: 0,
                    child: GestureDetector(
                      onTap: _pickAvatar,
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color:       scheme.surface,
                          shape:       BoxShape.circle,
                          border: Border.all(color: scheme.primary, width: 1.5),
                        ),
                        child: Icon(Icons.camera_alt_rounded, size: 18, color: scheme.primary),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Center(child: Text(user.email, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13))),
            const SizedBox(height: 24),

            // ── Edit Fields ───────────────────────────────────────────────
            _SectionCard(
              title: 'Personal Info',
              child: Column(
                children: [
                  AppTextField(
                    label:      'Full Name',
                    controller: _nameCtrl,
                    prefixIcon: Icons.badge_rounded,
                    onChanged:  (_) => setState(() => _editing = true),
                  ),
                  const SizedBox(height: 14),
                  AppTextField(
                    label:        'Bkash Number',
                    hint:         '01XXXXXXXXX',
                    controller:   _bkashCtrl,
                    prefixIcon:   Icons.mobile_friendly_rounded,
                    keyboardType: TextInputType.phone,
                    onChanged:    (_) => setState(() => _editing = true),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Save button (only when editing)
            if (_editing)
              AppButton(
                label:     'Save Changes',
                icon:      Icons.save_rounded,
                isLoading: _saving,
                onPressed: _saveProfile,
              ),
            const SizedBox(height: 16),

            // ── Group / Admin Section ─────────────────────────────────────
            if (group != null) ...[
              _SectionCard(
                title: 'Active Group: ${group.name}',
                child: Column(
                  children: [
                    // Group Code (admin only)
                    if (isAdmin) ...[
                      _GroupCodeTile(group: group, groupCtrl: groupCtrl),
                      const Divider(height: 20),
                    ],

                    // Transfer Admin (admin only, only if other members exist)
                    if (isAdmin && group.members.length > 1)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.admin_panel_settings_rounded, color: AppColors.tertiary),
                        title:   const Text('Transfer Admin Role'),
                        subtitle:const Text('Hand over admin to another member'),
                        onTap:   () => _showTransferAdminDialog(context, groupCtrl, group),
                      ),

                    // End Tour (admin only)
                    if (isAdmin)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.timer_off_rounded, color: AppColors.error),
                        title:   const Text('End This Tour', style: TextStyle(color: AppColors.error)),
                        subtitle:const Text('Mark this group as inactive'),
                        onTap:   () => _confirmDeactivate(context, groupCtrl, group),
                      ),

                    // Leave Group (members only — not shown to admin)
                    if (!isAdmin)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.exit_to_app_rounded, color: AppColors.error),
                        title:   const Text('Leave Group', style: TextStyle(color: AppColors.error)),
                        subtitle:const Text('Request to leave — requires admin approval'),
                        onTap:   () => _confirmLeaveGroup(context, groupCtrl, group, user!),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── Appearance ────────────────────────────────────────────────
            _SectionCard(
              title: 'Appearance',
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    Icon(themeCtrl.resolveIsDark(context) ? Icons.nightlight_round : Icons.wb_sunny_rounded,
                        color: scheme.primary),
                    const SizedBox(width: 12),
                    Text(themeCtrl.resolveIsDark(context) ? 'Dark Mode' : 'Light Mode',
                        style: const TextStyle(fontWeight: FontWeight.w500)),
                  ]),
                  ThemeSwitchWidget(),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Sign Out ──────────────────────────────────────────────────
            AppButton(
              label:    'Sign Out',
              icon:     Icons.logout_rounded,
              outlined: true,
              color:    AppColors.error,
              onPressed: _signOut,
            ),
            const SizedBox(height: 32),
          ],
        ),
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
        title:   const Text('Transfer Admin Role'),
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
                    onTap: () {
                      Navigator.of(dialogCtx).pop();
                      groupCtrl.transferAdmin(m.userId);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('${m.name} is now the group admin.'),
                        backgroundColor: AppColors.success,
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
        title:   const Text('End This Tour?'),
        content: const Text('The group will be moved to history and all members will be notified.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              // 1. Close the dialog first
              Navigator.pop(dialogCtx);

              // 2. Show a loading indicator while deactivating
              if (!mounted) return;
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => const PopScope(
                  canPop: false,
                  child: Center(child: CircularProgressIndicator()),
                ),
              );

              // 3. Await the actual deactivation
              await groupCtrl.deactivateGroup(
                groupId:   group.groupId,
                reason:    AppConstants.inactivatedByAdmin,
                memberIds: group.members.keys.toList(),
                groupName: group.name,
              );

              // 4. Dismiss loading dialog + navigate to group hub
              if (!mounted) return;
              Navigator.of(context, rootNavigator: true).pop(); // dismiss loader
              context.go(AppRoutes.groupHub);
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
        title:   const Text('Leave Group?'),
        content: const Text(
          'Your leave request will be sent to the admin for approval.\n\n'
          'Your expenses and debts will remain recorded even after you leave.\n'
          'You can rejoin later using the group code.',
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
              final ok = await groupCtrl.requestLeave(
                userId:   user.uid,
                userName: user.name,
              );
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(ok
                    ? 'Leave request sent to admin. You\'ll be removed once approved.'
                    : 'Failed to send request. Please try again.'),
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

// ── Group Code Tile ───────────────────────────────────────────────────────────
class _GroupCodeTile extends StatelessWidget {
  final dynamic        group;
  final GroupController groupCtrl;
  const _GroupCodeTile({required this.group, required this.groupCtrl});

  @override
  Widget build(BuildContext context) {
    final scheme      = Theme.of(context).colorScheme;
    final isExpired   = group.isCodeExpired as bool;
    final timeLeft    = (group.groupCodeExpiresAt as DateTime).difference(DateTime.now());
    final minsLeft    = timeLeft.inMinutes.clamp(0, 60);
    final isRefreshing = groupCtrl.isRefreshingCode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Group Join Code', style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color:        AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  group.groupCode as String,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 6, color: AppColors.primary),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Column(
              children: [
                IconButton(
                  icon:     const Icon(Icons.copy_rounded),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: group.groupCode as String));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Group code copied!'), duration: Duration(seconds: 2)),
                    );
                  },
                  tooltip: 'Copy code',
                ),
                // Refresh button — shows spinner while refreshing
                isRefreshing
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : IconButton(
                        icon:     Icon(Icons.refresh_rounded, color: isExpired ? AppColors.error : AppColors.success),
                        onPressed: () async {
                          await groupCtrl.refreshGroupCode();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('✅ Code refreshed! Share it with members.'),
                                duration: Duration(seconds: 3),
                              ),
                            );
                          }
                        },
                        tooltip: 'Refresh code',
                      ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(children: [
          Icon(
            isExpired ? Icons.timer_off_rounded : Icons.timer_rounded,
            size:  14,
            color: isExpired ? AppColors.error : AppColors.success,
          ),
          const SizedBox(width: 4),
          Text(
            isExpired ? 'Code expired — tap refresh' : 'Expires in ${minsLeft}m',
            style: TextStyle(fontSize: 12, color: isExpired ? AppColors.error : AppColors.success, fontWeight: FontWeight.w500),
          ),
        ]),
      ],
    );
  }
}

// ── Helper Card ───────────────────────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding:    const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        scheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
