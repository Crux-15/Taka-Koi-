import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/debt_controller.dart';
import '../../controllers/group_controller.dart';
import '../../utils/display_helpers.dart';
import '../../utils/money.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/avatar_widget.dart';
import '../../widgets/ui/ui.dart';
import '../expenses/home/bkash_section.dart';

/// Pay toward one debt: pay them (bKash or cash), then log it here so they
/// can confirm it.
class LogPaymentView extends StatefulWidget {
  final String debtId;
  const LogPaymentView({super.key, required this.debtId});

  @override
  State<LogPaymentView> createState() => _LogPaymentViewState();
}

class _LogPaymentViewState extends State<LogPaymentView> {
  final _amountCtrl = TextEditingController();
  bool    _submitting = false;
  String? _error;

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit(int availableCents, String symbol) async {
    final cents = Money.parseCents(_amountCtrl.text);
    if (cents == null || cents <= 0) {
      setState(() => _error = 'Enter how much you paid.');
      return;
    }
    if (cents > availableCents) {
      setState(() => _error = 'That\'s more than you owe. The most is ${Money.display(Money.fromCents(availableCents), symbol)}.');
      return;
    }
    setState(() {
      _submitting = true;
      _error      = null;
    });

    final auth     = context.read<AuthController>();
    final group    = context.read<GroupController>().activeGroup!;
    final debtCtrl = context.read<DebtController>();
    final user     = auth.user!;

    // Only ever pay the debt this screen was opened for, never a fallback.
    final debt = debtCtrl.openDebtById(widget.debtId);
    if (debt == null) {
      setState(() {
        _submitting = false;
        _error      = 'This debt is already settled or no longer exists.';
      });
      return;
    }

    final ok = await debtCtrl.logPayment(
      groupId:        group.groupId,
      fromUserId:     user.uid,
      fromUserName:   user.name,
      toUserId:       debt.toUserId,
      toUserName:     debt.toUserName,
      debtId:         debt.debtId,
      amount:         Money.fromCents(cents),
      currencySymbol: group.currencySymbol,
      bkashNumber:    null,
    );

    if (!mounted) return;
    setState(() => _submitting = false);
    if (ok) {
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(SnackBar(
        content: Text(debtCtrl.savedOffline
            ? 'Saved on this phone. It syncs once you\'re online, then ${firstName(debt.toUserName)} can confirm it.'
            : 'Logged. ${firstName(debt.toUserName)} will confirm they got it.'),
      ));
    } else {
      setState(() => _error = debtCtrl.lastError ?? 'Couldn\'t log the payment. Try again.');
    }
  }

  void _fill(int cents) {
    HapticFeedback.selectionClick();
    setState(() {
      _amountCtrl.text = Money.format(cents);
      _amountCtrl.selection = TextSelection.collapsed(offset: _amountCtrl.text.length);
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final debtCtrl  = context.watch<DebtController>();
    final groupCtrl = context.watch<GroupController>();
    final auth      = context.watch<AuthController>();
    final group     = groupCtrl.activeGroup;
    final symbol    = group?.currencySymbol ?? '৳';
    final p         = context.palette;
    final t         = Theme.of(context).textTheme;
    final debt      = debtCtrl.openDebtById(widget.debtId);

    if (debt == null || group == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: InfoBanner('This debt is already settled or no longer exists.',
                icon: Icons.verified_rounded, tone: ChipTone.positive),
          ),
        ),
      );
    }

    // What can still be logged: the debt minus payments already waiting for
    // the receiver to confirm, so the same money can't be paid twice.
    final pendingCents   = debtCtrl.pendingCentsFor(debt.debtId);
    final availableCents = debtCtrl.availableCentsFor(debt);
    final name           = firstName(debt.toUserName);

    return Scaffold(
      appBar: AppBar(title: Text('Pay $name'), centerTitle: true),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: AppButton(
            label:     'Log payment',
            icon:      Icons.check_rounded,
            isLoading: _submitting,
            onPressed: availableCents > 0 ? () => _submit(availableCents, symbol) : null,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          AppCard(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            child: Column(
              children: [
                AvatarWidget(name: debt.toUserName, imageUrl: group.members[debt.toUserId]?.avatarUrl, size: 56),
                const SizedBox(height: 10),
                Text('You owe $name', style: t.bodyMedium?.copyWith(color: p.textMuted)),
                const SizedBox(height: 2),
                MoneyText(debt.remainingAmount, symbol: symbol, size: 30, color: p.negative),
                if (debt.remainingCents < Money.toCents(debt.originalAmount))
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('of ${Money.display(debt.originalAmount, symbol)} · part already paid', style: t.bodySmall),
                  ),
                const SizedBox(height: 18),
                Divider(height: 1, color: p.hairline),
                const SizedBox(height: 14),
                Text('HOW MUCH DID YOU PAY?', style: AppType.overline(p.textMuted)),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(symbol, style: AppType.money(26, color: p.textMuted)),
                    const SizedBox(width: 6),
                    IntrinsicWidth(
                      child: TextField(
                        controller:      _amountCtrl,
                        autofocus:       true,
                        textAlign:       TextAlign.center,
                        keyboardType:    const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                        style:           AppType.money(40, color: p.text),
                        onChanged:       (_) => setState(() => _error = null),
                        decoration: InputDecoration(
                          hintText:       '0',
                          hintStyle:      AppType.money(40, color: p.textFaint),
                          filled:         false,
                          border:         InputBorder.none,
                          enabledBorder:  InputBorder.none,
                          focusedBorder:  InputBorder.none,
                          isDense:        true,
                          contentPadding: EdgeInsets.zero,
                          constraints:    const BoxConstraints(minWidth: 50),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, textAlign: TextAlign.center, style: t.bodySmall?.copyWith(color: p.negative)),
                ],
                const SizedBox(height: 14),
                if (availableCents > 0)
                  Wrap(
                    spacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      Pressable(
                        onTap: () => _fill(availableCents),
                        child: StatusChip('Pay it all · ${Money.displayCompact(Money.fromCents(availableCents), symbol)}',
                            tone: ChipTone.accent, icon: Icons.bolt_rounded),
                      ),
                      if (availableCents >= 200)
                        Pressable(
                          onTap: () => _fill(availableCents ~/ 2),
                          child: StatusChip('Half · ${Money.displayCompact(Money.fromCents(availableCents ~/ 2), symbol)}'),
                        ),
                    ],
                  ),
              ],
            ),
          ),
          if (pendingCents > 0) ...[
            const SizedBox(height: 12),
            InfoBanner(
              availableCents > 0
                  ? '${Money.displayCompact(Money.fromCents(pendingCents), symbol)} you logged earlier is waiting for $name to confirm, so you can log up to ${Money.displayCompact(Money.fromCents(availableCents), symbol)} more.'
                  : 'Your payments already cover this. Waiting for $name to confirm them.',
              icon: Icons.schedule_rounded,
              tone: ChipTone.pending,
            ),
          ],
          const SizedBox(height: 22),
          const SectionHeader('Paying by bKash?'),
          BkashSection(
            homeCtx:       context,
            requesterId:   auth.user?.uid ?? '',
            requesterName: auth.user?.name ?? '',
            targetId:      debt.toUserId,
            targetName:    debt.toUserName,
            groupCtrl:     groupCtrl,
          ),
          const SizedBox(height: 14),
          const InfoBanner(
            'Taka Koi doesn\'t move money. Pay by bKash or cash first, then log it here. '
            'The debt goes down once they confirm they got it.',
            icon: Icons.info_outline_rounded,
          ),
        ],
      ),
    );
  }
}
