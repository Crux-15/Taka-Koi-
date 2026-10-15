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

    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final accentGold = isDark ? const Color(0xFFE5B83B) : const Color(0xFF9E6E00);

    return Scaffold(
      appBar: AppBar(title: const Text('Log Payment')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Midnight Obsidian & Burnished Gold Debt Summary Card ────────
              _DebtSummaryCard(
                toUserName:      debt.toUserName,
                originalAmount:  debt.originalAmount,
                remainingAmount: debt.remainingAmount,
                symbol:          symbol,
                isDark:          isDark,
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
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _amountCtrl.text = debt.remainingAmount.toStringAsFixed(2);
                      _formKey.currentState?.validate();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: accentGold.withOpacity(isDark ? 0.12 : 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: accentGold.withOpacity(isDark ? 0.32 : 0.25),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.bolt_rounded, size: 18, color: accentGold),
                          const SizedBox(width: 6),
                          Text(
                            '1-Tap Settle Full: ',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            '$symbol${debt.remainingAmount.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: accentGold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),

              AppButton(
                label:     'Submit Payment',
                icon:      Icons.send_rounded,
                isLoading: _submitting,
                gradient:  isDark
                    ? const LinearGradient(
                        colors: [Color(0xFFE5B83B), Color(0xFFC5951A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : const LinearGradient(
                        colors: [Color(0xFF1C1917), Color(0xFF2C2724)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                textColor: isDark ? const Color(0xFF14120E) : Colors.white,
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

class _DebtSummaryCard extends StatelessWidget {
  final String toUserName;
  final double originalAmount;
  final double remainingAmount;
  final String symbol;
  final bool isDark;

  const _DebtSummaryCard({
    required this.toUserName,
    required this.originalAmount,
    required this.remainingAmount,
    required this.symbol,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F1D19) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark
              ? const Color(0xFFD4A017).withOpacity(0.26)
              : const Color(0xFFE2DBCB),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.40) : Colors.black.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'PAYING TO',
                style: TextStyle(
                  color: isDark ? const Color(0xFFB0A880) : const Color(0xFF7A7468),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFFD4A017).withOpacity(0.14)
                      : const Color(0xFF9E6E00).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: 13,
                      color: isDark ? const Color(0xFFE5B83B) : const Color(0xFF9E6E00),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Debt Settlement',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFFE5B83B) : const Color(0xFF9E6E00),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            toUserName,
            style: TextStyle(
              color: isDark ? const Color(0xFFF5F0DC) : const Color(0xFF1C1917),
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _InfoChip(
                  label: 'Original Debt',
                  value: '$symbol${originalAmount.toStringAsFixed(2)}',
                  isHighlight: false,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _InfoChip(
                  label: 'Remaining Debt',
                  value: '$symbol${remainingAmount.toStringAsFixed(2)}',
                  isHighlight: true,
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;
  final bool isHighlight;
  final bool isDark;

  const _InfoChip({
    required this.label,
    required this.value,
    this.isHighlight = false,
    this.isDark = true,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark
        ? (isHighlight ? const Color(0xFF2C281F) : const Color(0xFF24221C))
        : (isHighlight ? const Color(0xFFF7F3E8) : const Color(0xFFF5F2EB));

    final borderColor = isDark
        ? (isHighlight ? const Color(0xFFD4A017).withOpacity(0.32) : Colors.white.withOpacity(0.08))
        : (isHighlight ? const Color(0xFFC59B27).withOpacity(0.38) : const Color(0xFFE2DBCB));

    final valueColor = isHighlight
        ? (isDark ? const Color(0xFFFFD700) : const Color(0xFF9E6E00))
        : (isDark ? const Color(0xFFDCD6C2) : const Color(0xFF1C1917));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isDark ? const Color(0xFF9E9675) : const Color(0xFF7A7468),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}
