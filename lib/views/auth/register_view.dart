import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../utils/app_colors.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_text_field.dart';
import 'password_setup_view.dart';
import 'widgets/auth_hero.dart';

/// Step 1 of 3 — user enters name + email. Step 2 sets a password and creates
/// the account; step 3 confirms the email through a link Firebase sends.
class RegisterView extends StatefulWidget {
  const RegisterView({super.key});

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  final _formKey   = GlobalKey<FormState>();
  final _nameCtrl  = TextEditingController();
  final _emailCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  void _continue() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PasswordSetupView(
        name:  _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AuthHero(
              title:        'Create your account',
              subtitle:     'Two quick steps, then we email you a link to confirm it\'s you.',
              showBack:     true,
              heightFactor: 0.32,
            ),

            // ── Step indicator ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
              child: Row(
                children: [
                  const _StepDot(step: 1, label: 'Details',  active: true,  done: false),
                  _StepLine(),
                  const _StepDot(step: 2, label: 'Password', active: false, done: false),
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
                    AppTextField(
                      label:           'Full name',
                      hint:            'Your name',
                      controller:      _nameCtrl,
                      prefixIcon:      Icons.person_outline_rounded,
                      textInputAction: TextInputAction.next,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Name is required.';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller:      _emailCtrl,
                      keyboardType:    TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _continue(),
                      validator: (v) {
                        if (v == null || v.isEmpty)    return 'Email is required.';
                        if (!v.contains('@') || !v.contains('.')) return 'Enter a valid email.';
                        return null;
                      },
                      decoration: const InputDecoration(
                        labelText:  'Email',
                        hintText:   'you@example.com',
                        prefixIcon: Icon(Icons.alternate_email_rounded, size: 20),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Info card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color:        AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border:       Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Next you\'ll choose a password. Then we\'ll email you a link: '
                              'open it to confirm the address and start using the app.',
                              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    AppButton(
                      label:     'Continue',
                      icon:      Icons.arrow_forward_rounded,
                      onPressed: _continue,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Already have an account?',
                            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14)),
                        TextButton(
                          onPressed: () => context.pop(),
                          child: const Text('Sign in'),
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
}

// ── Step indicator helpers ────────────────────────────────────────────────────
class _StepDot extends StatelessWidget {
  final int    step;
  final String label;
  final bool   active;
  final bool   done;
  const _StepDot({required this.step, required this.label, required this.active, required this.done});

  @override
  Widget build(BuildContext context) {
    final color = done || active ? AppColors.primary : Colors.grey.withValues(alpha: 0.4);
    return Column(
      children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color:  done || active ? AppColors.primary : Colors.transparent,
            shape:  BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
          child: Center(
            child: done
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                : Text('$step',
                    style: TextStyle(
                      color:      active ? Colors.white : color,
                      fontWeight: FontWeight.w700,
                      fontSize:   13,
                    )),
          ),
        ),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(fontSize: 11, color: color, fontWeight: active ? FontWeight.w600 : FontWeight.normal)),
      ],
    );
  }
}

class _StepLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          height: 2,
          margin: const EdgeInsets.only(bottom: 18),
          color: Colors.grey.withValues(alpha: 0.3),
        ),
      );
}
