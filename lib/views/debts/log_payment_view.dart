import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/debt_controller.dart';
import '../../controllers/group_controller.dart';
import '../../utils/app_colors.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/loading_widget.dart';

/// Log a payment toward a specific debt.
class LogPaymentView extends StatefulWidget {
  final String debtId;
  const LogPaymentView({super.key, required this.debtId});

  @override
  State<LogPaymentView> createState() => _LogPaymentViewState();
}

class _LogPaymentViewState extends State<LogPaymentView> {
  final _formKey    = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  bool _submitting  = false;

  @override
  void dispose() { _amountCtrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    final auth       = context.read<AuthController>();
    final groupCtrl  = context.read<GroupController>();
    final debtCtrl   = context.read<DebtController>();
    final group      = groupCtrl.activeGroup!;
    final user       = auth.user!;

    // Find the debt
    final debt = debtCtrl.iOwe.firstWhere(
      (d) => d.debtId == widget.debtId,
      orElse: () => debtCtrl.iOwe.first,
    );

    final ok = await debtCtrl.logPayment(
      groupId:        group.groupId,
      fromUserId:     user.uid,
      fromUserName:   user.name,
      toUserId:       debt.toUserId,
      toUserName:     debt.toUserName,
      debtId:         debt.debtId,
      amount:         double.tryParse(_amountCtrl.text.trim()) ?? 0,
      currencySymbol: group.currencySymbol,
      bkashNumber:    null,
    );

    setState(() => _submitting = false);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment logged! Waiting for receiver to confirm.'), backgroundColor: AppColors.success),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to log payment.'), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final debtCtrl  = context.watch<DebtController>();
    final groupCtrl = context.watch<GroupController>();
    final group     = groupCtrl.activeGroup;
    final symbol    = group?.currencySymbol ?? '৳';

    final debt = debtCtrl.iOwe.where((d) => d.debtId == widget.debtId).firstOrNull
               ?? debtCtrl.iOwe.firstOrNull;

    if (debt == null) return Scaffold(appBar: AppBar(title: const Text('Log Payment')), body: const Center(child: AppLoader()));

    return Scaffold(
      appBar: AppBar(title: const Text('Log Payment')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Debt summary card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient:     AppColors.cardGradient,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Paying to', style: TextStyle(color: Colors.white70, fontSize: 13)),
                    Text(debt.toUserName, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _InfoChip(label: 'Original', value: '$symbol${debt.originalAmount.toStringAsFixed(2)}'),
                        const SizedBox(width: 12),
                        _InfoChip(label: 'Remaining', value: '$symbol${debt.remainingAmount.toStringAsFixed(2)}'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Amount field
              AppTextField(
                label:        'Payment Amount',
                hint:         '0.00',
                controller:   _amountCtrl,
                prefixIcon:   Icons.payments_rounded,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  final val = double.tryParse(v ?? '');
                  if (val == null || val <= 0) return 'Enter a valid amount.';
                  if (val > debt.remainingAmount) return 'Cannot exceed remaining debt ($symbol${debt.remainingAmount.toStringAsFixed(2)}).';
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => _amountCtrl.text = debt.remainingAmount.toStringAsFixed(2),
                icon:  const Icon(Icons.done_all_rounded, size: 16),
                label: Text('Pay full amount ($symbol${debt.remainingAmount.toStringAsFixed(2)})'),
              ),
              const SizedBox(height: 28),

              AppButton(
                label:     'Submit Payment',
                icon:      Icons.send_rounded,
                isLoading: _submitting,
                onPressed: _submit,
              ),
              const SizedBox(height: 12),
              Text(
                'The receiver must approve this payment to mark your debt as reduced.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;
  const _InfoChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
        ],
      ),
    );
  }
}
