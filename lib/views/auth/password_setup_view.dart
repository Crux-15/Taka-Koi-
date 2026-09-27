import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_controller.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_router.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/theme_switch_widget.dart';

/// Step 3 of 3 — user sets a password, account is created, redirected to login.
class PasswordSetupView extends StatefulWidget {
  final String name;
  final String email;
  const PasswordSetupView({super.key, required this.name, required this.email});

  @override
  State<PasswordSetupView> createState() => _PasswordSetupViewState();
}

class _PasswordSetupViewState extends State<PasswordSetupView> {
  final _formKey     = GlobalKey<FormState>();
  final _passCtrl    = TextEditingController();
  final _confirmCtrl = TextEditingController();

  @override
  void dispose() {
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _createAccount() async {
    if (!_formKey.currentState!.validate()) return;
    final ctrl = context.read<AuthController>();

    // Step 1: Create the Firebase Auth account
    final ok = await ctrl.register(widget.email, _passCtrl.text);
    if (!mounted) return;

    if (ok) {
      // Step 2: Set display name in Firebase Auth
      await ctrl.updateName(widget.name);
      if (!mounted) return;

      // Step 3: Create the Firestore user document.
      // This is critical — without it, the user exists in Firebase Auth
      // but has NO profile in Firestore, so create/join group features
      // fail silently (same doc that Google sign-in creates automatically).
      await ctrl.completeProfileSetup(name: widget.name);
      if (!mounted) return;

      // Step 4: Sign out so user logs in fresh (confirms they own the email)
      await ctrl.signOut();
      if (!mounted) return;

      // Step 5: Go to login with success message
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:         Text('🎉 Account created! Please sign in.'),
        backgroundColor: AppColors.success,
        duration:        Duration(seconds: 3),
      ));
      context.go(AppRoutes.login);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:         Text(ctrl.errorMessage ?? 'Failed to create account. Try again.'),
        backgroundColor: AppColors.error,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth   = context.watch<AuthController>();
    final scheme = Theme.of(context).colorScheme;
    final size   = MediaQuery.sizeOf(context);

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
                Positioned(top: 52, left: 12, child: BackButton(color: Colors.white)),
                Positioned(top: 52, right: 20, child: const ThemeSwitchWidget()),
                Positioned.fill(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.lock_rounded, size: 42, color: Colors.white),
                      ),
                      const SizedBox(height: 14),
                      const Text('Set Your Password',
                          style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(
                        widget.email,
                        style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // ── Step indicator ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
              child: Row(
                children: [
                  _StepDot(step: 1, label: 'Email',    active: false, done: true),
                  _StepLine(),
                  _StepDot(step: 2, label: 'Verify',   active: false, done: true),
                  _StepLine(),
                  _StepDot(step: 3, label: 'Password', active: true,  done: false),
                ],
              ),
            ),

            // ── Form ────────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Email display (non-editable)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color:        AppColors.success.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border:       Border.all(color: AppColors.success.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.verified_rounded, color: AppColors.success, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(widget.name,
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                Text(widget.email,
                                    style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color:        AppColors.success.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('Verified',
                                style: TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    AppTextField(
                      label:           'Password',
                      hint:            '••••••••',
                      controller:      _passCtrl,
                      prefixIcon:      Icons.lock_outline_rounded,
                      isPassword:      true,
                      textInputAction: TextInputAction.next,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Password is required.';
                        if (v.length < 6)           return 'Minimum 6 characters.';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      label:           'Confirm Password',
                      hint:            '••••••••',
                      controller:      _confirmCtrl,
                      prefixIcon:      Icons.lock_person_rounded,
                      isPassword:      true,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _createAccount(),
                      validator: (v) {
                        if (v != _passCtrl.text) return 'Passwords do not match.';
                        return null;
                      },
                    ),
                    const SizedBox(height: 28),
                    AppButton(
                      label:     'Create Account',
                      icon:      Icons.check_rounded,
                      isLoading: auth.isLoading,
                      onPressed: _createAccount,
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Step indicator helpers ────────────────────────────────────────────────────
class _StepDot extends StatelessWidget {
  final int step; final String label; final bool active; final bool done;
  const _StepDot({required this.step, required this.label, required this.active, required this.done});
  @override
  Widget build(BuildContext context) {
    final color = done || active ? AppColors.primary : Colors.grey.withOpacity(0.4);
    return Column(children: [
      Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color:  done || active ? AppColors.primary : Colors.transparent,
          shape:  BoxShape.circle,
          border: Border.all(color: color, width: 2),
        ),
        child: Center(child: done
            ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
            : Text('$step', style: TextStyle(color: active ? Colors.white : color, fontWeight: FontWeight.w700, fontSize: 13))),
      ),
      const SizedBox(height: 4),
      Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: active ? FontWeight.w600 : FontWeight.normal)),
    ]);
  }
}

class _StepLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(height: 2, margin: const EdgeInsets.only(bottom: 18), color: Colors.grey.withOpacity(0.3)),
  );
}
