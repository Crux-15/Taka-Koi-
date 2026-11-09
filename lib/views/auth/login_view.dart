import 'package:flutter/foundation.dart' show kIsWeb;
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
import '../../widgets/common/install_hint.dart';
import '../../widgets/ui/ui.dart';
import 'widgets/auth_hero.dart';

/// Login screen — Google Sign-In + Email/Password.
class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

enum _Busy { none, email, google }

class _LoginViewState extends State<LoginView> with WidgetsBindingObserver {
  _Busy _busy = _Busy.none;
  final _formKey    = GlobalKey<FormState>();
  final _emailCtrl  = TextEditingController();
  final _passCtrl   = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  /// On the iPhone home-screen app the browser can't tell when the Google
  /// window is closed without signing in, so the button would stay busy.
  /// Back in the app, free the button after a moment (a sign-in that does
  /// finish still goes ahead).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!kIsWeb || state != AppLifecycleState.resumed || _busy != _Busy.google) return;
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _busy == _Busy.google) setState(() => _busy = _Busy.none);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _onLoginSuccess() {
    if (!mounted) return;
    if (context.read<AuthController>().needsEmailVerification) {
      context.go(AppRoutes.verifyEmail);
      return;
    }
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
    setState(() => _busy = _Busy.email);
    final ok   = await ctrl.signInWithEmail(_emailCtrl.text.trim(), _passCtrl.text);
    if (!mounted) return;
    setState(() => _busy = _Busy.none);
    if (ok) {
      _onLoginSuccess();
    } else {
      _showError(ctrl.errorMessage ?? 'Login failed.');
    }
  }

  Future<void> _loginWithGoogle() async {
    final ctrl = context.read<AuthController>();
    setState(() => _busy = _Busy.google);
    final ok   = await ctrl.signInWithGoogle();
    if (!mounted) return;
    setState(() => _busy = _Busy.none);
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
    final p = context.palette;
    final t = Theme.of(context).textTheme;

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AuthHero(
              title:    'Welcome back',
              subtitle: 'Sign in to split, approve and settle up with your travel crew.',
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: Form(
                key: _formKey,
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const InstallHint(),
                      TextFormField(
                        controller:      _emailCtrl,
                        keyboardType:    TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints:   const [AutofillHints.email],
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Email is required.';
                          if (!v.contains('@')) return 'Enter a valid email.';
                          return null;
                        },
                        decoration: const InputDecoration(
                          labelText:  'Email',
                          hintText:   'you@example.com',
                          prefixIcon: Icon(Icons.alternate_email_rounded, size: 20),
                        ),
                      ),
                      const SizedBox(height: 12),
                      AppTextField(
                        label:            'Password',
                        controller:       _passCtrl,
                        prefixIcon:       Icons.lock_outline_rounded,
                        isPassword:       true,
                        textInputAction:  TextInputAction.done,
                        onFieldSubmitted: (_) => _loginWithEmail(),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Password is required.';
                          if (v.length < 6) return 'Password must be at least 6 characters.';
                          return null;
                        },
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _showForgotPasswordDialog,
                          child: const Text('Forgot password?'),
                        ),
                      ),
                      const SizedBox(height: 6),
                      AppButton(
                        label:     'Sign in',
                        icon:      Icons.arrow_forward_rounded,
                        isLoading: _busy == _Busy.email,
                        onPressed: _busy == _Busy.none ? _loginWithEmail : null,
                      ),
                      const SizedBox(height: 22),
                      Row(children: [
                        Expanded(child: Divider(color: p.hairline)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text('or', style: t.bodySmall),
                        ),
                        Expanded(child: Divider(color: p.hairline)),
                      ]),
                      const SizedBox(height: 22),
                      _GoogleSignInButton(
                        isLoading: _busy == _Busy.google,
                        onPressed: _busy == _Busy.none ? _loginWithGoogle : null,
                      ),
                      const SizedBox(height: 26),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('New to Taka Koi?', style: t.bodyMedium?.copyWith(color: p.textMuted)),
                          TextButton(
                            onPressed: () => context.push(AppRoutes.register),
                            child: const Text('Create an account'),
                          ),
                        ],
                      ),
                    ],
                  ),
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
        title: const Text('Reset your password'),
        content: TextFormField(
          controller:   emailCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Email',
            hintText:  'you@example.com',
            prefixIcon: Icon(Icons.alternate_email_rounded, size: 20),
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
              foregroundColor: isDark ? AppColors.goldBright : AppColors.poshGold,
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
  final VoidCallback? onPressed;
  const _GoogleSignInButton({required this.isLoading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Pressable(
      onTap: onPressed,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          color:        p.surface,
          borderRadius: BorderRadius.circular(16),
          border:       Border.all(color: p.hairline, width: 1.2),
          boxShadow:    p.cardShadow,
        ),
        alignment: Alignment.center,
        child: isLoading
            ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: p.text))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/icons/gmail.png', width: 22, height: 22, fit: BoxFit.contain),
                  const SizedBox(width: 12),
                  Text('Continue with Google',
                      style: TextStyle(fontFamily: AppType.display, fontWeight: FontWeight.w600, fontSize: 15, color: p.text)),
                ],
              ),
      ),
    );
  }
}
