import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_controller.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_router.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/theme_switch_widget.dart';

/// Step 2 of 3 — user sets a password and the account is created. Firebase
/// then emails a verification link and the app moves to the verify screen.
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

    // Creates the account and profile and sends the verification email. The
    // controller does it all, so it completes even if this screen goes away.
    final ok = await ctrl.register(
      name:     widget.name,
      email:    widget.email,
      password: _passCtrl.text,
    );
    if (!mounted) return;

    if (ok) {
      context.go(AppRoutes.verifyEmail);
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
                const Positioned(top: 52, left: 12, child: BackButton(color: Colors.white)),
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
                        child: const Icon(Icons.lock_rounded, size: 42, color: Colors.white),
                      ),
                      const SizedBox(height: 14),
                      const Text('Set Your Password',
                          style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(
                        widget.email,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 13),
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
                  const _StepDot(step: 1, label: 'Details',  active: false, done: true),
                  _StepLine(),
                  const _StepDot(step: 2, label: 'Password', active: true,  done: false),
                  _StepLine(),
                  const _StepDot(step: 3, label: 'Verify',   active: false, done: false),
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
                        color:        AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border:       Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.person_rounded, color: AppColors.primary, size: 18),
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
    final color = done || active ? AppColors.primary : Colors.grey.withValues(alpha: 0.4);
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
    child: Container(height: 2, margin: const EdgeInsets.only(bottom: 18), color: Colors.grey.withValues(alpha: 0.3)),
  );
}
