import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/group_controller.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_constants.dart';
import '../../utils/app_router.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_text_field.dart';

/// Create group form — name + currency selection.
class CreateGroupView extends StatefulWidget {
  const CreateGroupView({super.key});
  @override
  State<CreateGroupView> createState() => _CreateGroupViewState();
}

class _CreateGroupViewState extends State<CreateGroupView> {
  final _formKey   = GlobalKey<FormState>();
  final _nameCtrl  = TextEditingController();
  Map<String, String> _selectedCurrency = AppConstants.currencies.first;

  @override
  void dispose() { _nameCtrl.dispose(); super.dispose(); }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    final auth  = context.read<AuthController>();
    final group = context.read<GroupController>();
    final user  = auth.user!;
    final result = await group.createGroup(
      adminId:        user.uid,
      adminName:      user.name,
      adminAvatar:    user.avatarUrl,
      groupName:      _nameCtrl.text.trim(),
      currency:       _selectedCurrency['code']!,
      currencySymbol: _selectedCurrency['symbol']!,
    );
    if (!mounted) return;
    if (result != null) {
      context.go(AppRoutes.home);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(group.errorMessage ?? 'Failed to create group.'), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final group  = context.watch<GroupController>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Create Tour Group')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Illustration
              Center(
                child: Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(Icons.group_rounded, size: 44, color: Colors.white),
                ),
              ),
              const SizedBox(height: 16),
              Text('Set Up Your Tour Group', style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text('Give it a name and select your group currency.', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14), textAlign: TextAlign.center),
              const SizedBox(height: 32),

              AppTextField(
                label:     'Group Name',
                hint:      'e.g. Bandarban 2026',
                controller: _nameCtrl,
                prefixIcon: Icons.badge_rounded,
                textInputAction: TextInputAction.next,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Group name is required.';
                  if (v.trim().length < 3) return 'Minimum 3 characters.';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Currency Dropdown
              DropdownButtonFormField<Map<String, String>>(
                value:      _selectedCurrency,
                decoration: InputDecoration(
                  labelText:   'Currency',
                  prefixIcon:  const Icon(Icons.currency_exchange_rounded),
                  filled:      true,
                  fillColor:   scheme.surfaceContainerHighest,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                ),
                items: AppConstants.currencies.map((c) => DropdownMenuItem(
                  value: c,
                  child: Text('${c['symbol']} ${c['code']} — ${c['name']}'),
                )).toList(),
                onChanged: (v) => setState(() => _selectedCurrency = v!),
              ),
              const SizedBox(height: 32),

              AppButton(
                label:     'Create Group',
                icon:      Icons.rocket_launch_rounded,
                isLoading: group.isLoading,
                onPressed: _create,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
