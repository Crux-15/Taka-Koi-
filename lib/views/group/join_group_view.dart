import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/group_controller.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_router.dart';
import '../../widgets/common/app_button.dart';

/// Enter 6-char group code to join a group instantly (no approval needed).
class JoinGroupView extends StatefulWidget {
  const JoinGroupView({super.key});
  @override
  State<JoinGroupView> createState() => _JoinGroupViewState();
}

class _JoinGroupViewState extends State<JoinGroupView> {
  final _codeCtrl = TextEditingController();

  Future<void> _join() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 6-character code.'), backgroundColor: AppColors.error),
      );
      return;
    }
    final user  = context.read<AuthController>().user!;
    final group = context.read<GroupController>();

    final success = await group.joinGroup(
      code:      code,
      userId:    user.uid,
      userName:  user.name,
      avatarUrl: user.avatarUrl,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 Joined group successfully!'),
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 2),
        ),
      );
      context.go(AppRoutes.home);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(group.errorMessage ?? 'Failed to join group.'), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  void dispose() { _codeCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final group  = context.watch<GroupController>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Join a Group')),
      resizeToAvoidBottomInset: true,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            Center(
              child: Container(
                width: 80, height: 80,
                decoration: BoxDecoration(gradient: AppColors.mintGradient, borderRadius: BorderRadius.circular(24)),
                child: const Icon(Icons.qr_code_rounded, size: 44, color: Colors.white),
              ),
            ),
            const SizedBox(height: 20),
            Text('Enter Group Code', style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'Ask your group creator for the 6-character code.',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 36),
            TextFormField(
              controller:  _codeCtrl,
              textAlign:   TextAlign.center,
              maxLength:   6,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                _UpperCaseFormatter(),
              ],
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: 8),
              decoration: InputDecoration(
                hintText:    'XXXXXX',
                hintStyle:   TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: 8, color: scheme.outline),
                counterText: '',
                contentPadding: const EdgeInsets.symmetric(vertical: 20),
              ),
              keyboardType: TextInputType.visiblePassword,
              onChanged:   (_) => setState(() {}),
            ),
            const SizedBox(height: 32),
            AppButton(
              label:     'Join Group',
              icon:      Icons.group_add_rounded,
              isLoading: group.isLoading,
              onPressed: _codeCtrl.text.trim().length == 6 ? _join : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}


