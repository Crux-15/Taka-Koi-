import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
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
                        onTap:   () => _confirmLeaveGroup(context, groupCtrl, group, user),
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
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color:        AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border:       Border.all(color: AppColors.primary.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 32), // balances the share button on the right
                    Expanded(
                      child: Text(
                        group.groupCode as String,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 6, color: AppColors.primary),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Tooltip(
                      message: 'Share invite to WhatsApp, Messenger, etc.',
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => _showInviteSheet(context, group),
                          child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.share_rounded, size: 18, color: AppColors.primary),
                          ),
                        ),
                      ),
                    ),
                  ],
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

  void _showInviteSheet(BuildContext context, dynamic group) {
    final scheme = Theme.of(context).colorScheme;
    final code = group.groupCode as String;
    final tourName = group.name as String;
    final inviteText = '$code\n\n'
        'Join our tour "$tourName" on Taka Koi? to track all our shared expenses!';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.88,
          ),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF141311) : scheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 20,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: scheme.onSurfaceVariant.withOpacity(0.35),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Title Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFFD4A017).withOpacity(0.18)
                              : AppColors.primary.withOpacity(0.14),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.send_rounded,
                          color: isDark ? const Color(0xFFFFD700) : AppColors.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Invite to $tourName',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: scheme.onSurface,
                              ),
                            ),
                            Text(
                              'Share the group code via messaging apps',
                              style: TextStyle(
                                fontSize: 12,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Code Display Card (Never wraps, prominent, elegant)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1C18) : AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFFD4A017).withOpacity(0.3)
                            : AppColors.primary.withOpacity(0.3),
                        width: 1.2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'GROUP JOIN CODE',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.5,
                                color: isDark ? const Color(0xFFB0A880) : scheme.onSurfaceVariant,
                              ),
                            ),
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  Clipboard.setData(ClipboardData(text: code));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('✅ Join code copied!'),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFFD4A017).withOpacity(0.18)
                                        : AppColors.primary.withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.copy_rounded,
                                        size: 14,
                                        color: isDark ? const Color(0xFFFFD700) : AppColors.poshGold,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Copy Code',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? const Color(0xFFFFD700) : AppColors.poshGold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            code,
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 8,
                              color: isDark ? const Color(0xFFFFD700) : AppColors.poshGold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Share Targets with Actual Brand Icons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _ShareTargetButton(
                        label: 'WhatsApp',
                        app: 'whatsapp',
                        onTap: () {
                          Navigator.pop(ctx);
                          _launchShare(tourName: tourName, code: code, target: 'whatsapp');
                        },
                      ),
                      _ShareTargetButton(
                        label: 'Messenger',
                        app: 'messenger',
                        onTap: () {
                          Navigator.pop(ctx);
                          _launchShare(tourName: tourName, code: code, target: 'messenger');
                        },
                      ),
                      _ShareTargetButton(
                        label: 'Instagram',
                        app: 'instagram',
                        onTap: () {
                          Navigator.pop(ctx);
                          _launchShare(tourName: tourName, code: code, target: 'instagram');
                        },
                      ),
                      _ShareTargetButton(
                        label: 'More Apps',
                        app: 'more',
                        onTap: () {
                          Navigator.pop(ctx);
                          _launchShare(tourName: tourName, code: code, target: null);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Formatted Message Preview Card (Clean, NO Github link)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1C18) : scheme.surfaceVariant.withOpacity(0.35),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark ? const Color(0xFFD4A017).withOpacity(0.2) : scheme.outline.withOpacity(0.15),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'MESSAGE PREVIEW',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: inviteText));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('✅ Full invite message copied!'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              },
                              child: Row(
                                children: [
                                  Icon(Icons.copy_rounded, size: 12, color: scheme.primary),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Copy Message',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: scheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFFD4A017).withOpacity(0.18)
                                : AppColors.primary.withOpacity(0.14),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            code,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2,
                              color: isDark ? const Color(0xFFFFD700) : AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Join our tour "$tourName" on Taka Koi? to track all our shared expenses!',
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            fontWeight: FontWeight.w500,
                            color: scheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _launchShare({
    required String tourName,
    required String code,
    String? target,
  }) async {
    final inviteText = '$code\n\n'
        'Join our tour "$tourName" on Taka Koi? to track all our shared expenses!';

    const channel = MethodChannel('com.tourtracker.tour_expense_tracker/app_launcher');

    if (target == 'whatsapp') {
      try {
        final ok = await channel.invokeMethod<bool>('shareToPackage', {
          'package': 'com.whatsapp',
          'text': inviteText,
        });
        if (ok == true) return;
      } catch (_) {}

      final uri = Uri.parse('whatsapp://send?text=${Uri.encodeComponent(inviteText)}');
      try {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return;
        }
      } catch (_) {}

      final webUri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(inviteText)}');
      try {
        if (await canLaunchUrl(webUri)) {
          await launchUrl(webUri, mode: LaunchMode.externalApplication);
          return;
        }
      } catch (_) {}
    } else if (target == 'messenger') {
      try {
        final ok = await channel.invokeMethod<bool>('shareToPackage', {
          'package': 'com.facebook.orca',
          'text': inviteText,
        });
        if (ok == true) return;
      } catch (_) {}
    } else if (target == 'instagram') {
      try {
        final ok = await channel.invokeMethod<bool>('shareToPackage', {
          'package': 'com.instagram.android',
          'text': inviteText,
        });
        if (ok == true) return;
      } catch (_) {}
    }

    // System share sheet (Default / "More Apps")
    try {
      final ok = await channel.invokeMethod<bool>('shareText', {
        'text': inviteText,
        'title': 'Invite Members to $tourName',
      });
      if (ok == true) return;
    } catch (_) {}

    // Fallback: copy to clipboard
    await Clipboard.setData(ClipboardData(text: inviteText));
  }
}

class _ShareTargetButton extends StatelessWidget {
  final String label;
  final String app;
  final VoidCallback onTap;

  const _ShareTargetButton({
    required this.label,
    required this.app,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BrandLogoWidget(app: app, size: 52),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BrandLogoWidget extends StatelessWidget {
  final String app;
  final double size;

  const BrandLogoWidget({super.key, required this.app, this.size = 52});

  @override
  Widget build(BuildContext context) {
    switch (app) {
      case 'whatsapp':
        return Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            color: Color(0xFF25D366),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: Color(0x3325D366), blurRadius: 10, offset: Offset(0, 4)),
            ],
          ),
          child: Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: Size(size * 0.58, size * 0.58),
                  painter: _WhatsAppBubblePainter(),
                ),
                Icon(
                  Icons.call_rounded,
                  size: size * 0.32,
                  color: const Color(0xFF25D366),
                ),
              ],
            ),
          ),
        );

      case 'messenger':
        return Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [Color(0xFF00B2FE), Color(0xFF006AFF)],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            boxShadow: [
              BoxShadow(color: Color(0x33006AFF), blurRadius: 10, offset: Offset(0, 4)),
            ],
          ),
          child: Center(
            child: CustomPaint(
              size: Size(size * 0.58, size * 0.58),
              painter: _MessengerPainter(),
            ),
          ),
        );

      case 'instagram':
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size * 0.28),
            gradient: const RadialGradient(
              center: Alignment(-0.8, 1.0),
              radius: 1.4,
              colors: [
                Color(0xFFFFDC80),
                Color(0xFFF77737),
                Color(0xFFF56040),
                Color(0xFFFD1D1D),
                Color(0xFFE1306C),
                Color(0xFFC13584),
                Color(0xFF833AB4),
              ],
              stops: [0.0, 0.2, 0.35, 0.5, 0.65, 0.8, 1.0],
            ),
            boxShadow: const [
              BoxShadow(color: Color(0x33FD1D1D), blurRadius: 10, offset: Offset(0, 4)),
            ],
          ),
          child: Center(
            child: CustomPaint(
              size: Size(size * 0.56, size * 0.56),
              painter: _InstagramPainter(),
            ),
          ),
        );

      default:
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDark ? const Color(0xFF26231C) : const Color(0xFFEDE8DD),
            border: Border.all(
              color: isDark ? const Color(0xFFD4A017).withOpacity(0.35) : const Color(0xFFD0C8B8),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.35 : 0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Icon(
              Icons.apps_rounded,
              size: size * 0.44,
              color: isDark ? const Color(0xFFFFD700) : const Color(0xFF1C1917),
            ),
          ),
        );
    }
  }
}

class _WhatsAppBubblePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final path = Path();
    final rect = Rect.fromCenter(center: Offset(w * 0.5, h * 0.48), width: w * 0.92, height: h * 0.88);
    path.addOval(rect);
    path.moveTo(w * 0.22, h * 0.76);
    path.lineTo(w * 0.06, h * 0.96);
    path.lineTo(w * 0.38, h * 0.88);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MessengerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // White speech bubble
    final bubblePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final bubblePath = Path();
    final rect = Rect.fromCenter(center: Offset(w * 0.5, h * 0.48), width: w * 0.94, height: h * 0.90);
    bubblePath.addOval(rect);
    bubblePath.moveTo(w * 0.22, h * 0.78);
    bubblePath.lineTo(w * 0.06, h * 0.98);
    bubblePath.lineTo(w * 0.38, h * 0.88);
    bubblePath.close();

    canvas.drawPath(bubblePath, bubblePaint);

    // Lightning bolt in Messenger blue
    final boltPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF00B2FE), Color(0xFF006AFF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.fill;

    final boltPath = Path();
    boltPath.moveTo(w * 0.30, h * 0.54);
    boltPath.lineTo(w * 0.48, h * 0.34);
    boltPath.lineTo(w * 0.43, h * 0.48);
    boltPath.lineTo(w * 0.70, h * 0.42);
    boltPath.lineTo(w * 0.52, h * 0.62);
    boltPath.lineTo(w * 0.57, h * 0.48);
    boltPath.close();

    canvas.drawPath(boltPath, boltPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _InstagramPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final strokePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;

    final fillPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // Rounded rectangle camera body
    final cameraRect = Rect.fromCenter(center: Offset(w * 0.5, h * 0.5), width: w * 0.78, height: h * 0.78);
    canvas.drawRRect(RRect.fromRectAndRadius(cameraRect, const Radius.circular(8)), strokePaint);

    // Center lens circle
    canvas.drawCircle(Offset(w * 0.5, h * 0.5), w * 0.20, strokePaint);

    // Flash dot in top-right
    canvas.drawCircle(Offset(w * 0.70, h * 0.30), 2.2, fillPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
