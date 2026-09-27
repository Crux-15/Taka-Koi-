import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/email_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/theme_switch_widget.dart';
import 'otp_verification_view.dart';

/// Step 1 of 3 — user enters name + email, app sends an OTP to that email.
class RegisterView extends StatefulWidget {
  const RegisterView({super.key});

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  final _formKey   = GlobalKey<FormState>();
  final _nameCtrl  = TextEditingController();
  final _emailCtrl = TextEditingController();
  bool _sending    = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _sending = true);

    final otp   = EmailService.generateOtp();
    final error = await EmailService.sendOtp(
      toEmail: _emailCtrl.text.trim(),
      toName:  _nameCtrl.text.trim(),
      otp:     otp,
    );

    if (!mounted) return;
    setState(() => _sending = false);

    if (error == null) {
      // Success — navigate to OTP verification
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => OtpVerificationView(
          name:  _nameCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          otp:   otp,
        ),
      ));
    } else {
      // Show the actual error so we know exactly what failed
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:         Text(error),
        backgroundColor: AppColors.error,
        duration:        const Duration(seconds: 6),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final size   = MediaQuery.sizeOf(context);

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Hero Header ─────────────────────────────────────────────────
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
                Positioned(top: 52, left: 12, child: BackButton(color: Colors.white, onPressed: () => context.pop())),
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
                        child: const Icon(Icons.mark_email_unread_rounded, size: 42, color: Colors.white),
                      ),
                      const SizedBox(height: 14),
                      const Text('Create Account',
                          style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text('We\'ll verify your email first',
                          style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 13)),
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
                  _StepDot(step: 1, label: 'Email',    active: true,  done: false),
                  _StepLine(),
                  _StepDot(step: 2, label: 'Verify',   active: false, done: false),
                  _StepLine(),
                  _StepDot(step: 3, label: 'Password', active: false, done: false),
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
                      label:           'Full Name',
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
                    AppTextField(
                      label:           'Email Address',
                      hint:            'you@example.com',
                      controller:      _emailCtrl,
                      prefixIcon:      Icons.email_outlined,
                      keyboardType:    TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _sendOtp(),
                      validator: (v) {
                        if (v == null || v.isEmpty)    return 'Email is required.';
                        if (!v.contains('@') || !v.contains('.')) return 'Enter a valid email.';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    // Info card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color:        AppColors.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border:       Border.all(color: AppColors.primary.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'A 6-digit code will be sent to your email. It expires in 10 minutes.',
                              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    AppButton(
                      label:     'Send Verification Code',
                      icon:      Icons.send_rounded,
                      isLoading: _sending,
                      onPressed: _sendOtp,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Already have an account?',
                            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14)),
                        TextButton(
                          onPressed: () => context.pop(),
                          child: const Text('Sign In'),
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
    final color = done || active ? AppColors.primary : Colors.grey.withOpacity(0.4);
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
          color: Colors.grey.withOpacity(0.3),
        ),
      );
}
