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

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Hero Header ───────────────────────────────────────────────
            Stack(
              children: [
                Container(
                  height: size.height * 0.34,
                  decoration: const BoxDecoration(
                    gradient: AppColors.heroGradient,
                    borderRadius: BorderRadius.only(
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
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white30),
                        ),
                        child: const Icon(Icons.travel_explore_rounded, size: 44, color: Colors.white),
                      ),
                      const SizedBox(height: 16),
                      const Text('Welcome Back!',
                          style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text('Sign in to your account',
                          style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 14)),
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

                    // Email
                    AppTextField(
                      label:          'Email',
                      hint:           'you@example.com',
                      controller:     _emailCtrl,
                      prefixIcon:     Icons.email_outlined,
                      keyboardType:   TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Email is required.';
                        if (!v.contains('@')) return 'Enter a valid email.';
                        return null;
                      },
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
                        child: const Text('Forgot Password?'),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Login button
                    AppButton(
                      label:     'Sign In',
                      icon:      Icons.login_rounded,
                      isLoading: auth.isLoading,
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
                          child: const Text('Register'),
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
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reset Password'),
        content: AppTextField(
          label:        'Email',
          controller:   emailCtrl,
          keyboardType: TextInputType.emailAddress,
          prefixIcon:   Icons.email_outlined,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
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
            child: const Text('Send'),
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
