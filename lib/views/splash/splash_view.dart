import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/group_controller.dart';
import '../../controllers/notification_controller.dart';
import '../../utils/app_constants.dart';
import '../../utils/app_router.dart';

/// Animated splash screen — auto-navigates based on auth state.
/// Theme: black background matching the Taka Koi! logo palette.
class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double>   _fadeIn;
  late Animation<double>   _scaleIn;
  late Animation<double>   _slideUp;

  // Brand colours extracted from the Taka Koi! logo
  static const Color _bgColor     = Color(0xFF0A0A0A); // near-black
  static const Color _yellow      = Color(0xFFFFD700); // bold yellow
  static const Color _yellowLight = Color(0xFFFFF176); // soft yellow for tagline

  @override
  void initState() {
    super.initState();
    // Force status bar to transparent so it blends with the dark background
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor:      Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _fadeIn  = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _scaleIn = Tween<double>(begin: 0.75, end: 1.0).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.elasticOut),
    );
    _slideUp = Tween<double>(begin: 30, end: 0).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic),
    );
    _animCtrl.forward();
    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(AppConstants.splashDuration);
    if (!mounted) return;

    final auth      = context.read<AuthController>();
    final group     = context.read<GroupController>();
    final notifCtrl = context.read<NotificationController>();

    auth.listenToAuthChanges();

    await auth.authReady.timeout(
      const Duration(seconds: 8),
      onTimeout: () {},
    );
    if (!mounted) return;

    if (!auth.isAuthenticated) {
      context.go(AppRoutes.login);
      return;
    }

    final uid = auth.user?.uid;
    if (uid != null) {
      notifCtrl.listenToNotifications(uid);
    }

    final activeGroupId = auth.user?.activeGroupId;
    if (activeGroupId != null && activeGroupId.isNotEmpty) {
      group.listenToGroup(activeGroupId, currentUserId: uid);
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      context.go(AppRoutes.home);
    } else {
      context.go(AppRoutes.groupHub);
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(
        child: Center(
          child: FadeTransition(
            opacity: _fadeIn,
            child: AnimatedBuilder(
              animation: _animCtrl,
              builder: (_, __) => Transform.translate(
                offset: Offset(0, _slideUp.value),
                child: ScaleTransition(
                  scale: _scaleIn,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── Logo image ──────────────────────────────────────
                      SizedBox(
                        width:  size.width * 0.68,
                        height: size.width * 0.68,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(32),
                          child: Image.asset(
                            'assets/images/taka_koi_logo.jpg',
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.travel_explore_rounded,
                              size:  96,
                              color: _yellow,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // ── App name ─────────────────────────────────────────
                      Text(
                        AppConstants.appName,
                        style: const TextStyle(
                          color:         _yellow,
                          fontSize:      36,
                          fontWeight:    FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // ── Tagline ───────────────────────────────────────────
                      Text(
                        AppConstants.appTagline,
                        style: const TextStyle(
                          color:         _yellowLight,
                          fontSize:      14,
                          fontWeight:    FontWeight.w400,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 52),

                      // ── Loading spinner ───────────────────────────────────
                      SizedBox(
                        width: 26, height: 26,
                        child: CircularProgressIndicator(
                          strokeWidth:  2.5,
                          color:        _yellow.withOpacity(0.7),
                          backgroundColor: _yellow.withOpacity(0.15),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
