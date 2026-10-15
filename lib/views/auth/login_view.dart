import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/group_controller.dart';
import '../../controllers/notification_controller.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_router.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/theme_switch_widget.dart';

/// Login screen — Google Sign-In + Email/Password.
class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _formKey    = GlobalKey<FormState>();
  final _emailCtrl  = TextEditingController();
  final _passCtrl   = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _onLoginSuccess() {
    if (!mounted) return;
    final uid = context.read<AuthController>().user?.uid;
    if (uid != null) {
      // Start notification stream immediately on login
      context.read<NotificationController>().listenToNotifications(uid);
      // Restore group stream if user has an active group
      final activeGroupId = context.read<AuthController>().user?.activeGroupId;
      if (activeGroupId != null && activeGroupId.isNotEmpty) {
        context.read<GroupController>().listenToGroup(activeGroupId, currentUserId: uid);
      }
    }
    context.go(AppRoutes.groupHub);
  }

  Future<void> _loginWithEmail() async {
    if (!_formKey.currentState!.validate()) return;
    final ctrl = context.read<AuthController>();
    final ok   = await ctrl.signInWithEmail(_emailCtrl.text.trim(), _passCtrl.text);
    if (!mounted) return;
    if (ok) {
      _onLoginSuccess();
    } else {
      _showError(ctrl.errorMessage ?? 'Login failed.');
    }
  }

  Future<void> _loginWithGoogle() async {
    final ctrl = context.read<AuthController>();
    final ok   = await ctrl.signInWithGoogle();
    if (!mounted) return;
    if (ok) {
      _onLoginSuccess();
    } else if (ctrl.errorMessage != null) {
      _showError(ctrl.errorMessage!);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth    = context.watch<AuthController>();
    final scheme  = Theme.of(context).colorScheme;
    final size    = MediaQuery.sizeOf(context);
    final isDark  = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Hero Header (Smart Posh Midnight Obsidian & Gold) ─────────
            Stack(
              children: [
                Container(
                  height: size.height * 0.34,
                  decoration: BoxDecoration(
                    gradient: isDark
                        ? const LinearGradient(
                            colors: [Color(0xFF26221A), Color(0xFF161411)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          )
                        : const LinearGradient(
                            colors: [Color(0xFF1C1917), Color(0xFF2D2722)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                    borderRadius: const BorderRadius.only(
                      bottomLeft:  Radius.circular(40),
                      bottomRight: Radius.circular(40),
                    ),
                  ),
                ),
                Positioned(
                  top: 52, right: 20,
                  child: const ThemeSwitchWidget(),
                ),
                Positioned.fill(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFFD4A017).withOpacity(0.14)
                              : Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark ? const Color(0xFFD4A017).withOpacity(0.35) : Colors.white30,
                            width: 1.2,
                          ),
                        ),
                        child: Icon(
                          Icons.travel_explore_rounded,
                          size: 44,
                          color: isDark ? const Color(0xFFFFD700) : Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Welcome Back!',
                        style: TextStyle(
                          color: isDark ? const Color(0xFFF5F0DC) : Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Sign in to your account',
                        style: TextStyle(
                          color: isDark ? const Color(0xFFB0A880) : Colors.white.withOpacity(0.75),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // ── Form ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Google Sign-In
                    _GoogleSignInButton(
                      isLoading: auth.isLoading,
                      onPressed: _loginWithGoogle,
                    ),
                    const SizedBox(height: 24),

                    // Divider
                    Row(children: [
                      Expanded(child: Divider(color: scheme.outlineVariant)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text('or', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
                      ),
                      Expanded(child: Divider(color: scheme.outlineVariant)),
                    ]),
                    const SizedBox(height: 24),

                    // Email with Authentic Gmail Logo
                    TextFormField(
                      controller:      _emailCtrl,
                      keyboardType:    TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Email is required.';
                        if (!v.contains('@')) return 'Enter a valid email.';
                        return null;
                      },
                      decoration: InputDecoration(
                        labelText: 'Email',
                        hintText:  'you@example.com',
                        prefixIcon: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          child: Image.asset(
                            'assets/icons/gmail.png',
                            width: 20,
                            height: 20,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Password
                    AppTextField(
                      label:          'Password',
                      hint:           '••••••••',
                      controller:     _passCtrl,
                      prefixIcon:     Icons.lock_outline_rounded,
                      isPassword:     true,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _loginWithEmail(),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Password is required.';
                        if (v.length < 6) return 'Password must be at least 6 characters.';
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),

                    // Forgot password
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => _showForgotPasswordDialog(),
                        style: TextButton.styleFrom(
                          foregroundColor: isDark ? const Color(0xFFE5B83B) : AppColors.poshGold,
                        ),
                        child: const Text('Forgot Password?'),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Login button (Smart Posh Burnished Gold / Midnight Obsidian)
                    AppButton(
                      label:     'Sign In',
                      icon:      Icons.login_rounded,
                      isLoading: auth.isLoading,
                      gradient: isDark
                          ? const LinearGradient(
                              colors: [Color(0xFFE5B83B), Color(0xFFC5951A)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : const LinearGradient(
                              colors: [Color(0xFF1C1917), Color(0xFF2C2724)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                      textColor: isDark ? const Color(0xFF14120E) : Colors.white,
                      onPressed: _loginWithEmail,
                    ),
                    const SizedBox(height: 24),

                    // Register link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("Don't have an account?",
                            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14)),
                        TextButton(
                          onPressed: () => context.push(AppRoutes.register),
                          style: TextButton.styleFrom(
                            foregroundColor: isDark ? const Color(0xFFE5B83B) : AppColors.poshGold,
                          ),
                          child: const Text('Register', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showForgotPasswordDialog() {
    final emailCtrl = TextEditingController();
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reset Password'),
        content: TextFormField(
          controller:   emailCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: 'Email',
            hintText:  'you@example.com',
            prefixIcon: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Image.asset(
                'assets/icons/gmail.png',
                width: 20,
                height: 20,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: scheme.onSurfaceVariant)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final ok = await context.read<AuthController>().sendPasswordReset(emailCtrl.text.trim());
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(ok ? 'Reset email sent!' : 'Failed to send reset email.'),
                  backgroundColor: ok ? AppColors.success : AppColors.error,
                ));
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: isDark ? const Color(0xFFE5B83B) : AppColors.poshGold,
            ),
            child: const Text('Send', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _GoogleSignInButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onPressed;
  const _GoogleSignInButton({required this.isLoading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return OutlinedButton(
      onPressed: isLoading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.onSurface,
        side:        BorderSide(color: scheme.outline, width: 1.2),
        padding:     const EdgeInsets.symmetric(vertical: 14),
        shape:       RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        minimumSize: const Size(double.infinity, 54),
      ),
      child: isLoading
          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Google G logo using text (no SVG needed)
                Container(
                  width: 22, height: 22,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                  child: const Center(
                    child: Text('G', style: TextStyle(color: Color(0xFF4285F4), fontWeight: FontWeight.w900, fontSize: 14)),
                  ),
                ),
                const SizedBox(width: 12),
                const Text('Continue with Google', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              ],
            ),
    );
  }
}
