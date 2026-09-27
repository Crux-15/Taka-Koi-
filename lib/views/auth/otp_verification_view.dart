import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/email_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/theme_switch_widget.dart';
import 'password_setup_view.dart';

/// Step 2 of 3 — user enters the 6-digit OTP sent to their email.
class OtpVerificationView extends StatefulWidget {
  final String name;
  final String email;
  final String otp;
  const OtpVerificationView({
    super.key,
    required this.name,
    required this.email,
    required this.otp,
  });

  @override
  State<OtpVerificationView> createState() => _OtpVerificationViewState();
}

class _OtpVerificationViewState extends State<OtpVerificationView> {
  // ── Single hidden controller captures all 6 digits ──────────────────────────
  final _otpController = TextEditingController();
  final _otpFocus      = FocusNode();

  String  _currentOtp     = '';
  bool    _verifying      = false;
  bool    _resending      = false;
  int     _resendCooldown = 60;
  Timer?  _timer;

  @override
  void initState() {
    super.initState();
    _currentOtp = widget.otp;
    _startCooldown();
    _otpFocus.addListener(() => setState(() {})); // refresh focus highlight
    WidgetsBinding.instance.addPostFrameCallback((_) => _otpFocus.requestFocus());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    _otpFocus.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _resendCooldown = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        if (_resendCooldown > 0) { _resendCooldown--; } else { t.cancel(); }
      });
    });
  }

  String get _enteredOtp => _otpController.text;

  void _onOtpChanged(String value) {
    setState(() {});
    if (value.length == 6) _verify();
  }

  Future<void> _verify() async {
    if (_enteredOtp.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please enter all 6 digits.'),
        backgroundColor: AppColors.error,
      ));
      return;
    }
    setState(() => _verifying = true);
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    setState(() => _verifying = false);

    if (_enteredOtp == _currentOtp) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => PasswordSetupView(name: widget.name, email: widget.email),
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:         Text('Incorrect code. Please try again.'),
        backgroundColor: AppColors.error,
        duration:        Duration(seconds: 3),
      ));
      _otpController.clear();
      setState(() {});
      _otpFocus.requestFocus();
    }
  }

  Future<void> _resendOtp() async {
    if (_resendCooldown > 0 || _resending) return;
    setState(() => _resending = true);
    final newOtp = EmailService.generateOtp();
    final error  = await EmailService.sendOtp(
      toEmail: widget.email,
      toName:  widget.name,
      otp:     newOtp,
    );
    if (!mounted) return;
    setState(() => _resending = false);
    if (error == null) {
      _currentOtp = newOtp;
      _otpController.clear();
      setState(() {});
      _startCooldown();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('New code sent! Check your email.'),
        backgroundColor: AppColors.success,
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error),
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 6),
      ));
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text == null) return;
    final digits = data!.text!.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No numbers found in clipboard.'),
        backgroundColor: AppColors.warning,
      ));
      return;
    }
    final code = digits.length > 6 ? digits.substring(0, 6) : digits;
    _otpController.text = code;
    setState(() {});
    if (code.length == 6) _verify();
  }

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final scheme  = Theme.of(context).colorScheme;
    final size    = MediaQuery.sizeOf(context);
    final otp     = _otpController.text;

    return Scaffold(
      body: GestureDetector(
        onTap: () => _otpFocus.requestFocus(), // tap anywhere → open keyboard
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Hero ────────────────────────────────────────────────────────
              Stack(
                children: [
                  Container(
                    height: size.height * 0.28,
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
                          child: const Icon(Icons.verified_outlined, size: 42, color: Colors.white),
                        ),
                        const SizedBox(height: 12),
                        const Text('Verify Your Email',
                            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text('Code sent to ${widget.email}',
                            style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),

              // ── Step indicator ─────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Row(
                  children: [
                    _StepDot(step: 1, label: 'Email',    active: false, done: true),
                    _StepLine(),
                    _StepDot(step: 2, label: 'Verify',   active: true,  done: false),
                    _StepLine(),
                    _StepDot(step: 3, label: 'Password', active: false, done: false),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                child: Column(
                  children: [
                    Text('Enter the 6-digit code',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: scheme.onSurface)),
                    const SizedBox(height: 6),
                    Text('Check your inbox (and spam folder)',
                        style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 28),

                    // ── Hidden TextField + Visual Boxes ──────────────────────
                    Stack(
                      children: [
                        // Invisible TextField — captures keyboard input.
                        // Opacity(0) = completely invisible but still focusable & interactive.
                        Opacity(
                          opacity: 0.0,
                          child: TextField(
                            controller:      _otpController,
                            focusNode:       _otpFocus,
                            keyboardType:    TextInputType.number,
                            maxLength:       6,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: const InputDecoration(
                              counterText:        '',
                              border:             InputBorder.none,
                              enabledBorder:      InputBorder.none,
                              focusedBorder:      InputBorder.none,
                              disabledBorder:     InputBorder.none,
                              errorBorder:        InputBorder.none,
                              focusedErrorBorder: InputBorder.none,
                              isDense:            true,
                              contentPadding:     EdgeInsets.zero,
                            ),
                            style:       const TextStyle(fontSize: 1, color: Colors.transparent),
                            cursorColor: Colors.transparent,
                            onChanged:   _onOtpChanged,
                          ),
                        ),

                        // Visual digit boxes drawn on top
                        GestureDetector(
                          onTap: () => _otpFocus.requestFocus(),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: List.generate(6, (i) {
                              final char      = i < otp.length ? otp[i] : '';
                              final isCurrent = _otpFocus.hasFocus &&
                                  i == (otp.length < 6 ? otp.length : 5);
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                width:  46,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white.withOpacity(char.isNotEmpty ? 0.12 : 0.06)
                                      : Colors.black.withOpacity(char.isNotEmpty ? 0.08 : 0.04),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isCurrent
                                        ? AppColors.primary
                                        : char.isNotEmpty
                                            ? AppColors.primary.withOpacity(0.5)
                                            : (isDark
                                                ? Colors.white.withOpacity(0.15)
                                                : Colors.black.withOpacity(0.12)),
                                    width: isCurrent ? 2.5 : 1.5,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    char,
                                    style: TextStyle(
                                      fontSize:   24,
                                      fontWeight: FontWeight.w900,
                                      color:      isDark ? Colors.white : Colors.black87,
                                      height:     1.0,
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── Paste button ─────────────────────────────────────────
                    OutlinedButton.icon(
                      onPressed: _pasteFromClipboard,
                      icon:  const Icon(Icons.content_paste_rounded, size: 16),
                      label: const Text('Paste OTP from Clipboard'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side:    const BorderSide(color: AppColors.primary, width: 1.5),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        shape:   RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Verify button ────────────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      child: AppButton(
                        label:     'Verify Code',
                        icon:      Icons.check_circle_outline_rounded,
                        isLoading: _verifying,
                        onPressed: _verify,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Resend ───────────────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("Didn't receive the code?",
                            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14)),
                        const SizedBox(width: 6),
                        _resendCooldown > 0
                            ? Text('Resend in ${_resendCooldown}s',
                                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14))
                            : GestureDetector(
                                onTap: _resendOtp,
                                child: Text(
                                  _resending ? 'Sending...' : 'Resend',
                                  style: const TextStyle(
                                    color:      AppColors.primary,
                                    fontSize:   14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                      ],
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Step indicator ────────────────────────────────────────────────────────────
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
            : Text('$step', style: TextStyle(
                color:      active ? Colors.white : color,
                fontWeight: FontWeight.w700, fontSize: 13))),
      ),
      const SizedBox(height: 4),
      Text(label, style: TextStyle(fontSize: 11, color: color,
          fontWeight: active ? FontWeight.w600 : FontWeight.normal)),
    ]);
  }
}

class _StepLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(height: 2, margin: const EdgeInsets.only(bottom: 18),
        color: Colors.grey.withOpacity(0.3)),
  );
}
