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
import '../../widgets/ui/ui.dart';
import '../../widgets/common/empty_state_widget.dart';
import '../../widgets/common/avatar_widget.dart';
import '../../utils/display_helpers.dart';
import '../../utils/app_log.dart';
import '../../utils/app_exception.dart';

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
  String? _loadError;
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
    try {
      final p = await _service.fetchPayment(gid, widget.paymentId);
      if (!mounted) return;
      setState(() { _payment = p; _loading = false; });
    } catch (e, s) {
      logError('load payment', e, s);
      if (!mounted) return;
      setState(() {
        _loading   = false;
        _loadError = friendlyError(e, 'Couldn\'t load this payment.');
      });
    }
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
    final debtCtrl = context.read<DebtController>();
    final ok = await debtCtrl.approvePayment(
      _groupId, _payment!, _symbol,
    );
    if (!mounted) return;
    setState(() => _working = false);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(doneMessage('Confirmed. Their debt went down.', queued: debtCtrl.savedOffline))),
      );
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(debtCtrl.lastError ?? 'Failed to approve. Try again.'), backgroundColor: AppColors.error),
      );
      // The payment may have changed (e.g. already approved elsewhere); reload it.
      _load();
    }
  }

  Future<void> _reject() async {
    if (_payment == null) return;
    final noteCtrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) => AlertDialog(
        title:   const Text('Reject this payment?'),
        content: TextField(
          controller: noteCtrl,
          decoration: const InputDecoration(
            hintText: 'Why? (optional, e.g. "I only got 400")',
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
    final myUid  = context.read<AuthController>().user?.uid ?? '';
    final symbol = _symbol;
    final p      = context.palette;
    final t      = Theme.of(context).textTheme;
    final pay    = _payment;

    if (_loading) return const Scaffold(body: Center(child: AppLoader()));
    if (pay == null) {
      return Scaffold(
        appBar: AppBar(),
        body: EmptyStateWidget(
          icon:     Icons.search_off_rounded,
          title:    'Payment not found',
          subtitle: _loadError ?? 'It may have been removed, or you\'re no longer in this tour.',
        ),
      );
    }

    final isReceiver = pay.toUserId == myUid;
    final isPayer    = pay.fromUserId == myUid;
    final (String headline, ChipTone tone) = switch (pay.status) {
      'approved' => ('Confirmed', ChipTone.positive),
      'rejected' => ('Rejected', ChipTone.negative),
      _          => ('Waiting for confirmation', ChipTone.pending),
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Payment'), centerTitle: true),
      bottomNavigationBar: isReceiver && pay.isPending
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: AppButton(label: 'Reject', icon: Icons.close_rounded, outlined: true, color: p.negative,
                          onPressed: _working ? null : _reject),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: AppButton(label: 'I got it', icon: Icons.check_rounded, color: p.positive,
                          isLoading: _working, onPressed: _approve),
                    ),
                  ],
                ),
              ),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          AppCard(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AvatarWidget(name: pay.fromUserName, uid: pay.fromUserId, size: 48),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Icon(Icons.arrow_forward_rounded, color: p.textFaint),
                    ),
                    AvatarWidget(name: pay.toUserName, uid: pay.toUserId, size: 48),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  '${isPayer ? 'You' : firstName(pay.fromUserName)} paid ${isReceiver ? 'you' : firstName(pay.toUserName)}',
                  style: t.bodyMedium?.copyWith(color: p.textMuted),
                ),
                const SizedBox(height: 4),
                MoneyText(pay.amount, symbol: symbol, size: 38),
                const SizedBox(height: 10),
                StatusChip(headline, tone: tone),
                const SizedBox(height: 16),
                Divider(height: 1, color: p.hairline),
                const SizedBox(height: 8),
                _Detail('Logged', DateFormat('EEE, d MMM · h:mm a').format(pay.loggedAt)),
                if (pay.approvedAt != null) _Detail('Confirmed', DateFormat('EEE, d MMM · h:mm a').format(pay.approvedAt!)),
                if (pay.bkashNumber != null && pay.bkashNumber!.isNotEmpty) _Detail('bKash', pay.bkashNumber!),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (pay.isPending && isReceiver)
            InfoBanner(
              'Only confirm if the money really reached you (check your bKash or cash). '
              'Confirming lowers what ${firstName(pay.fromUserName)} owes you.',
              icon: Icons.shield_rounded, tone: ChipTone.accent,
            )
          else if (pay.isPending && isPayer)
            InfoBanner('Waiting for ${firstName(pay.toUserName)} to confirm they got it.',
                icon: Icons.schedule_rounded, tone: ChipTone.pending)
          else if (pay.status == 'rejected')
            InfoBanner(
              (pay.rejectionNote ?? '').isNotEmpty
                  ? 'Reason: "${pay.rejectionNote}". ${isPayer ? 'You can log the right amount again from Balances.' : ''}'
                  : (isPayer ? 'You can log the right amount again from Balances.' : 'This payment was rejected.'),
              icon: Icons.info_outline_rounded, tone: ChipTone.negative,
            )
          else if (pay.status == 'approved')
            const InfoBanner('Done. The debt was lowered by this amount.', icon: Icons.verified_rounded, tone: ChipTone.positive),
        ],
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  final String label;
  final String value;
  const _Detail(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(label, style: t.bodySmall),
          const Spacer(),
          Text(value, style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
