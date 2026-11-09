import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/group_controller.dart';
import '../../controllers/notification_controller.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_router.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/theme_switch_widget.dart';

/// Step 3 of 3 — the user opens the link Firebase emailed them.
///
/// Shown whenever someone is signed in with an unconfirmed email (new sign-ups
/// and accounts made before real verification existed). The database refuses
/// everything but their own profile until they've confirmed, so the router
/// keeps them here. Checks automatically every few seconds.
class VerifyEmailView extends StatefulWidget {
  const VerifyEmailView({super.key});

  @override
  State<VerifyEmailView> createState() => _VerifyEmailViewState();
}

class _VerifyEmailViewState extends State<VerifyEmailView> {
  Timer? _poll;
  Timer? _cooldownTimer;
  int  _cooldown  = 60; // the first email was sent on sign-up / sign-in
  bool _checking  = false;
  bool _resending = false;
  bool _done      = false;

  @override
  void initState() {
    super.initState();
    _startCooldown();
    _poll = Timer.periodic(const Duration(seconds: 5), (_) => _check(silent: true));
  }

  @override
  void dispose() {
    _poll?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    _cooldown = 60;
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() {
        if (_cooldown > 0) {
          _cooldown--;
        } else {
          t.cancel();
        }
      });
    });
  }

  Future<void> _check({bool silent = false}) async {
    if (_checking || _done || !mounted) return;
    _checking = true;
    if (!silent) setState(() {});

    // Grab everything up front: once verified, the router may leave this
    // screen before the await below returns.
    final auth      = context.read<AuthController>();
    final notifs    = context.read<NotificationController>();
    final groups    = context.read<GroupController>();
    final router    = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final ok  = await auth.checkEmailVerified();
    _checking = false;

    if (ok) {
      _done = true;
      _poll?.cancel();
      final user = auth.user;
      if (user != null) {
        notifs.listenToNotifications(user.uid);
        final gid = user.activeGroupId;
        if (gid != null && gid.isNotEmpty) {
          groups.listenToGroup(gid, currentUserId: user.uid);
        }
      }
      messenger.showSnackBar(const SnackBar(
        content:         Text('Email confirmed. Welcome!'),
        backgroundColor: AppColors.success,
      ));
      router.go(AppRoutes.groupHub);
      return;
    }

    if (!mounted) return;
    if (!silent) {
      setState(() {});
      messenger.showSnackBar(const SnackBar(
        content: Text('Not confirmed yet. Open the link in the email, then try again.'),
      ));
    }
  }

  Future<void> _resend() async {
    if (_cooldown > 0 || _resending) return;
    setState(() => _resending = true);
    final error = await context.read<AuthController>().resendVerificationEmail();
    if (!mounted) return;
    setState(() => _resending = false);
    if (error == null) _startCooldown();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:         Text(error ?? 'Sent. Check your inbox (and spam folder).'),
      backgroundColor: error == null ? AppColors.success : AppColors.error,
    ));
  }

  Future<void> _useDifferentAccount() async {
    _poll?.cancel();
    await context.read<AuthController>().signOut();
    if (mounted) context.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final auth   = context.watch<AuthController>();
    final scheme = Theme.of(context).colorScheme;
    final size   = MediaQuery.sizeOf(context);
    final email  = auth.signedInEmail;

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Hero ────────────────────────────────────────────────────────
            Stack(
              children: [
                Container(
                  height: size.height * 0.30,
                  decoration: const BoxDecoration(
                    gradient: AppColors.heroGradient,
                    borderRadius: BorderRadius.only(
                      bottomLeft:  Radius.circular(40),
                      bottomRight: Radius.circular(40),
                    ),
                  ),
                ),
                const Positioned(top: 52, right: 20, child: ThemeSwitchWidget()),
                Positioned.fill(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.mark_email_unread_rounded, size: 42, color: Colors.white),
                      ),
                      const SizedBox(height: 14),
                      const Text('Confirm your email',
                          style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(email,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color:        AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border:       Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'We sent a link to $email. Open it on any device to confirm '
                            'the address. This screen moves on by itself once you have.',
                            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  AppButton(
                    label:     "I've confirmed it",
                    icon:      Icons.check_rounded,
                    isLoading: _checking,
                    onPressed: () => _check(),
                  ),
                  const SizedBox(height: 12),
                  AppButton(
                    label:     _cooldown > 0 ? 'Resend email in ${_cooldown}s' : 'Resend email',
                    icon:      Icons.refresh_rounded,
                    outlined:  true,
                    isLoading: _resending,
                    onPressed: _cooldown > 0 ? null : _resend,
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: TextButton(
                      onPressed: _useDifferentAccount,
                      child: const Text('Use a different account'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
