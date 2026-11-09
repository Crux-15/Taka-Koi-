import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/group_controller.dart';
import '../../controllers/notification_controller.dart';
import '../../utils/app_constants.dart';
import '../../utils/app_router.dart';
import '../../utils/app_colors.dart';
import '../../widgets/ui/ui.dart';

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
  static const Color _bgColor     = AppColors.splashBlack; // near-black
  static const Color _yellow      = AppColors.primary; // bold yellow
  static const Color _yellowLight = AppColors.yellowPale; // soft yellow for tagline

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
    _scaleIn = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic),
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

    if (auth.needsEmailVerification) {
      context.go(AppRoutes.verifyEmail);
      return;
    }
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
    final logo = (size.width * 0.42).clamp(120.0, 200.0);

    return Scaffold(
      backgroundColor: _bgColor,
      body: Stack(
        children: [
          // Soft gold glow behind the logo
          Center(
            child: Container(
              width: logo * 2.6, height: logo * 2.6,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [Color(0x33E2B044), Color(0x00E2B044)]),
              ),
            ),
          ),
          SafeArea(
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
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              gradient: AppColors.goldGradient,
                              borderRadius: BorderRadius.circular(logo * 0.26),
                              boxShadow: [
                                BoxShadow(color: AppColors.goldDeep.withValues(alpha: 0.35), blurRadius: 40, offset: const Offset(0, 16)),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(logo * 0.26 - 3),
                              child: Image.asset(
                                'assets/images/taka_koi_logo.jpg',
                                width: logo, height: logo, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => SizedBox(
                                  width: logo, height: logo,
                                  child: const Icon(Icons.account_balance_wallet_rounded, size: 72, color: _yellow),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 30),
                          const Text(
                            AppConstants.appName,
                            style: TextStyle(
                              fontFamily:    AppType.display,
                              color:         Color(0xFFF7F1E3),
                              fontSize:      34,
                              fontWeight:    FontWeight.w700,
                              letterSpacing: -0.8,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(AppConstants.appTagline.toUpperCase(), style: AppType.overline(_yellowLight.withValues(alpha: 0.75))),
                          const SizedBox(height: 44),
                          SizedBox(
                            width: 120,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(100),
                              child: LinearProgressIndicator(
                                minHeight:       3,
                                color:           _yellow,
                                backgroundColor: _yellow.withValues(alpha: 0.12),
                              ),
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
        ],
      ),
    );
  }
}
