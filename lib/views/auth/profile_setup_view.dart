import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_controller.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_router.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_text_field.dart';

/// Profile setup screen shown after first registration.
class ProfileSetupView extends StatefulWidget {
  const ProfileSetupView({super.key});

  @override
  State<ProfileSetupView> createState() => _ProfileSetupViewState();
}

class _ProfileSetupViewState extends State<ProfileSetupView> {
  final _formKey     = GlobalKey<FormState>();
  final _nameCtrl    = TextEditingController();
  final _bkashCtrl   = TextEditingController();
  File?  _avatarFile;
  final  _picker     = ImagePicker();

  @override
  void initState() {
    super.initState();
    // Pre-fill name from Firebase Auth display name if available
    final fbUser = FirebaseAuth.instance.currentUser;
    if (fbUser?.displayName != null) _nameCtrl.text = fbUser!.displayName!;
  }

  Future<void> _pickAvatar() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 75, maxWidth: 512);
    if (picked != null) setState(() => _avatarFile = File(picked.path));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ctrl = context.read<AuthController>();
    final ok = await ctrl.completeProfileSetup(
      name:        _nameCtrl.text.trim(),
      bkashNumber: _bkashCtrl.text.trim(),
      avatarFile:  _avatarFile,
    );
    if (!mounted) return;
    if (ok) {
      context.go(AppRoutes.groupHub);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ctrl.errorMessage ?? 'Setup failed.'), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bkashCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth   = context.watch<AuthController>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                // Header
                Text('Set Up Your Profile',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text("Let your group mates know who you are",
                    style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14),
                    textAlign: TextAlign.center),
                const SizedBox(height: 36),

                // Avatar Picker
                Center(
                  child: Stack(
                    children: [
                      GestureDetector(
                        onTap: _pickAvatar,
                        child: Container(
                          width:  100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape:      BoxShape.circle,
                            gradient:   AppColors.primaryGradient,
                            boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 8))],
                          ),
                          child: _avatarFile != null
                              ? ClipOval(child: Image.file(_avatarFile!, fit: BoxFit.cover, width: 100, height: 100))
                              : const Icon(Icons.person_rounded, size: 52, color: Colors.white),
                        ),
                      ),
                      Positioned(
                        bottom: 0, right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color:       scheme.surface,
                            shape:       BoxShape.circle,
                            border: Border.all(color: scheme.outline, width: 1),
                          ),
                          child: Icon(Icons.camera_alt_rounded, size: 18, color: scheme.primary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton.icon(
                    onPressed: _pickAvatar,
                    icon: const Icon(Icons.photo_library_rounded, size: 16),
                    label: const Text('Choose Photo'),
                  ),
                ),
                const SizedBox(height: 24),

                // Name
                AppTextField(
                  label:          'Full Name',
                  hint:           'e.g. Rahim Khan',
                  controller:     _nameCtrl,
                  prefixIcon:     Icons.badge_rounded,
                  textInputAction: TextInputAction.next,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Name is required.';
                    if (v.trim().length < 2) return 'Enter at least 2 characters.';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Bkash (optional)
                AppTextField(
                  label:          'Bkash Number (Optional)',
                  hint:           '01XXXXXXXXX',
                  controller:     _bkashCtrl,
                  prefixIcon:     Icons.mobile_friendly_rounded,
                  keyboardType:   TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    'Your Bkash number lets group members send payments to you.',
                    style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 32),

                AppButton(
                  label:     "Let's Go!",
                  icon:      Icons.rocket_launch_rounded,
                  isLoading: auth.isLoading,
                  onPressed: _submit,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
