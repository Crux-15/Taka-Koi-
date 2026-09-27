import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/debt_controller.dart';
import '../../controllers/group_controller.dart';
import '../../models/payment_model.dart';
import '../../services/debt_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/loading_widget.dart';

/// Screen opened when a payment notification is tapped.
/// If the current user is the receiver (toUserId), they can approve or reject.
class PaymentReviewView extends StatefulWidget {
  final String paymentId;
  final String groupId;
  const PaymentReviewView({super.key, required this.paymentId, required this.groupId});

  @override
  State<PaymentReviewView> createState() => _PaymentReviewViewState();
}

class _PaymentReviewViewState extends State<PaymentReviewView> {
  final DebtService _service = DebtService();
  PaymentModel? _payment;
  bool _loading = true;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final gid = widget.groupId.isNotEmpty
        ? widget.groupId
        : context.read<GroupController>().activeGroup?.groupId ?? '';
    final p = await _service.fetchPayment(gid, widget.paymentId);
    if (!mounted) return;
    setState(() { _payment = p; _loading = false; });
  }

  String get _groupId =>
      widget.groupId.isNotEmpty
          ? widget.groupId
          : context.read<GroupController>().activeGroup?.groupId ?? '';

  String get _symbol =>
      context.read<GroupController>().activeGroup?.currencySymbol ?? '৳';

  Future<void> _approve() async {
    if (_payment == null) return;
    setState(() => _working = true);
    final ok = await context.read<DebtController>().approvePayment(
      _groupId, _payment!, _symbol,
    );
    if (!mounted) return;
    setState(() => _working = false);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment approved! Debt updated.'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to approve. Try again.'), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _reject() async {
    if (_payment == null) return;
    final noteCtrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) => AlertDialog(
        title:   const Text('Reject Payment?'),
        content: TextField(
          controller: noteCtrl,
          decoration: const InputDecoration(
            hintText: 'Reason (optional)',
            border:   OutlineInputBorder(),
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(null),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(noteCtrl.text.trim()),
            child: const Text('Reject', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    noteCtrl.dispose();
    if (reason == null || !mounted) return;

    setState(() => _working = true);
    final ok = await context.read<DebtController>().rejectPayment(
      _groupId, _payment!, reason, _symbol,
    );
    if (!mounted) return;
    setState(() => _working = false);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment rejected.'), backgroundColor: AppColors.error),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final myUid  = context.read<AuthController>().user?.uid ?? '';
    final symbol = _symbol;

    return Scaffold(
      appBar: AppBar(title: const Text('Payment Review')),
      body: _loading
          ? const Center(child: AppLoader())
          : _payment == null
              ? const Center(child: Text('Payment not found.'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _StatusBanner(payment: _payment!),
                      const SizedBox(height: 20),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Payment Details',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                              const Divider(height: 20),
                              _DetailRow(label: 'From',   value: _payment!.fromUserName),
                              _DetailRow(label: 'To',     value: _payment!.toUserName),
                              _DetailRow(
                                label: 'Amount',
                                value: '$symbol${_payment!.amount.toStringAsFixed(2)}',
                                valueColor: AppColors.primary,
                                bold: true,
                              ),
                              _DetailRow(
                                label: 'Date',
                                value: DateFormat('MMM d, y • h:mm a').format(_payment!.loggedAt),
                              ),
                              if (_payment!.bkashNumber != null && _payment!.bkashNumber!.isNotEmpty)
                                _DetailRow(label: 'bKash', value: _payment!.bkashNumber!),
                              if (_payment!.rejectionNote != null && _payment!.rejectionNote!.isNotEmpty)
                                _DetailRow(
                                  label: 'Rejection Note',
                                  value: _payment!.rejectionNote!,
                                  valueColor: AppColors.error,
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Action Buttons — only for receiver when pending
                      if (_payment!.isPending && _payment!.toUserId == myUid) ...[
                        if (_working)
                          const Center(child: AppLoader())
                        else ...[
                          AppButton(
                            label:     'Approve Payment',
                            isLoading: false,
                            onPressed: _approve,
                            color:     AppColors.success,
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              icon:    const Icon(Icons.cancel_outlined, color: AppColors.error),
                              label:   const Text('Reject', style: TextStyle(color: AppColors.error)),
                              style:   OutlinedButton.styleFrom(
                                side:    const BorderSide(color: AppColors.error),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape:   RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: _reject,
                            ),
                          ),
                        ],
                      ],

                      if (!_payment!.isPending)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              _payment!.isApproved
                                  ? 'This payment was approved. Debt has been settled.'
                                  : 'This payment was rejected.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _payment!.isApproved ? AppColors.success : AppColors.error,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final PaymentModel payment;
  const _StatusBanner({required this.payment});

  @override
  Widget build(BuildContext context) {
    final color  = payment.isPending  ? Colors.orange
                 : payment.isApproved ? AppColors.success
                 :                      AppColors.error;
    final icon   = payment.isPending  ? Icons.pending_actions_rounded
                 : payment.isApproved ? Icons.check_circle_rounded
                 :                      Icons.cancel_rounded;
    final label  = payment.isPending  ? 'Pending Review'
                 : payment.isApproved ? 'Approved'
                 :                      'Rejected';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 16)),
          Text('${payment.fromUserName} paid ${payment.toUserName}',
              style: TextStyle(fontSize: 13, color: color.withOpacity(0.8))),
        ]),
      ]),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool   bold;
  const _DetailRow({required this.label, required this.value, this.valueColor, this.bold = false});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 120,
          child: Text(label, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14)),
        ),
        Expanded(
          child: Text(value, style: TextStyle(
            fontSize:   14,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            color:      valueColor ?? scheme.onSurface,
          )),
        ),
      ]),
    );
  }
}
