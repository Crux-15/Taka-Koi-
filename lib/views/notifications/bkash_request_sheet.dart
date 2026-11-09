import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/group_controller.dart';
import '../../models/notification_model.dart';
import '../../utils/app_colors.dart';
import '../../utils/display_helpers.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/ui/ui.dart';

/// Someone asked for your bKash number: share it (adding it first if you
/// haven't saved one) or decline.
void showBkashRequestSheet(BuildContext ctx, NotificationModel notif, String groupId) {
  final groupCtrl     = ctx.read<GroupController>();
  final authCtrl      = ctx.read<AuthController>();
  final requesterId   = notif.referenceId;
  final requesterName = notif.message.split(' is requesting').first.trim();
  final targetId      = authCtrl.user?.uid  ?? '';
  final targetName    = authCtrl.user?.name ?? '';
  final saved         = (authCtrl.user?.bkashNumber ?? '').trim();
  final numberCtrl    = TextEditingController(text: saved);
  final formKey       = GlobalKey<FormState>();

  showModalBottomSheet(
    context: ctx,
    isScrollControlled: true,
    builder: (sheetCtx) {
      var busy = false;
      return StatefulBuilder(
        builder: (sCtx, setSt) {
          final p = sCtx.palette;
          final t = Theme.of(sCtx).textTheme;

          Future<void> share() async {
            if (!formKey.currentState!.validate()) return;
            setSt(() => busy = true);
            final number = numberCtrl.text.trim();
            final messenger = ScaffoldMessenger.of(ctx);
            // Save it to your profile first if it's new, so it stays in step.
            if (number != saved) {
              final ok = await authCtrl.updateProfile(name: targetName, bkashNumber: number);
              if (!ok) {
                setSt(() => busy = false);
                messenger.showSnackBar(SnackBar(content: Text(authCtrl.errorMessage ?? 'Couldn\'t save your number.')));
                return;
              }
            }
            final ok = await groupCtrl.acceptBkashRequest(
              groupId:       groupId,
              requesterId:   requesterId,
              requesterName: requesterName,
              targetId:      targetId,
              targetName:    targetName,
              groupName:     notif.groupName,
              myBkashNumber: number,
            );
            if (sheetCtx.mounted) Navigator.pop(sheetCtx);
            messenger.showSnackBar(SnackBar(
              content: Text(ok ? 'Shared your bKash number with ${firstName(requesterName)}.' : 'Couldn\'t share it. Try again.'),
            ));
          }

          Future<void> decline() async {
            setSt(() => busy = true);
            final messenger = ScaffoldMessenger.of(ctx);
            await groupCtrl.declineBkashRequest(groupId: groupId, requesterId: requesterId, targetId: targetId);
            if (sheetCtx.mounted) Navigator.pop(sheetCtx);
            messenger.showSnackBar(const SnackBar(content: Text('Request declined.')));
          }

          return Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, 20 + MediaQuery.viewInsetsOf(sCtx).bottom),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: IconTile(Icons.account_balance_wallet_rounded, size: 56, radius: 18, color: AppColors.bkashPink)),
                  const SizedBox(height: 14),
                  Text('Share your bKash number?', textAlign: TextAlign.center,
                      style: t.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text('$requesterName wants to pay you by bKash. Only they will see your number.',
                      textAlign: TextAlign.center, style: t.bodyMedium?.copyWith(color: p.textMuted)),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller:   numberCtrl,
                    keyboardType: TextInputType.phone,
                    autofocus:    saved.isEmpty,
                    decoration: InputDecoration(
                      labelText:  'Your bKash number',
                      hintText:   '01XXXXXXXXX',
                      prefixIcon: const Icon(Icons.phone_iphone_rounded, size: 20),
                      helperText: saved.isEmpty ? 'We\'ll also save it to your profile.' : null,
                    ),
                    validator: (v) => RegExp(r'^01[3-9]\d{8}$').hasMatch((v ?? '').trim())
                        ? null
                        : 'Enter an 11-digit number like 017XXXXXXXX',
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: AppButton(label: 'Decline', outlined: true, onPressed: busy ? null : decline),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: AppButton(
                          label: 'Share number', icon: Icons.lock_open_rounded, color: p.positive,
                          isLoading: busy, onPressed: share,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
