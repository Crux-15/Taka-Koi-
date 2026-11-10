import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/debt_controller.dart';
import '../../models/debt_model.dart';
import '../../models/expense_model.dart';
import '../../models/group_model.dart';
import '../../models/payment_model.dart';
import '../../services/debt_service.dart';
import '../../services/expense_service.dart';
import '../../services/notification_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_constants.dart';
import '../../utils/app_exception.dart';
import '../../utils/app_log.dart';
import '../../utils/display_helpers.dart';
import '../../utils/money.dart';
import '../../utils/offline.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/avatar_widget.dart';
import '../../widgets/common/empty_state_widget.dart';
import '../../widgets/ui/ui.dart';

/// A tour that has ended: what was spent, who paid, and, most importantly,
/// settling up what's still owed (tours often end before everyone has paid).
class PastTourDetailView extends StatefulWidget {
  final GroupModel group;
  const PastTourDetailView({super.key, required this.group});

  @override
  State<PastTourDetailView> createState() => _PastTourDetailViewState();
}

class _PastTourDetailViewState extends State<PastTourDetailView> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);
  final _debtService = DebtService();

  List<ExpenseModel> _expenses = [];
  List<DebtModel>    _debts    = [];
  List<PaymentModel> _payments = [];
  bool    _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool quiet = false}) async {
    final gid = widget.group.groupId;
    if (!quiet) {
      setState(() {
        _loading = true;
        _error   = null;
      });
    }
    try {
      final results = await Future.wait([
        ExpenseService().fetchApprovedExpenses(gid),
        _debtService.fetchAllDebts(gid),
        _debtService.fetchAllPayments(gid),
      ]);
      if (!mounted) return;
      setState(() {
        _expenses = results[0] as List<ExpenseModel>;
        _debts    = results[1] as List<DebtModel>;
        _payments = results[2] as List<PaymentModel>;
        _loading  = false;
      });
    } catch (e, s) {
      logError('load past tour', e, s);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error   = friendlyError(e, 'Couldn\'t load this tour. Check your connection and try again.');
      });
    }
  }

  /// Cents I've logged against [debt] that are still waiting for confirmation.
  int _waitingCents(DebtModel debt, String myUid) => _payments
      .where((p) => p.debtId == debt.debtId && p.fromUserId == myUid && p.isPending)
      .fold(0, (s, p) => s + Money.toCents(p.amount));

  @override
  Widget build(BuildContext context) {
    final group  = widget.group;
    final symbol = group.currencySymbol;
    final myUid  = context.read<AuthController>().user?.uid ?? '';
    final p      = context.palette;
    final t      = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(group.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(
              group.inactivatedAt != null ? 'Ended ${DateFormat('d MMM y').format(group.inactivatedAt!)}' : 'Ended',
              style: t.bodySmall,
            ),
          ],
        ),
        bottom: PillTabBar(
          controller: _tabs,
          tabs: const [Tab(text: 'Overview'), Tab(text: 'Expenses'), Tab(text: 'Debts')],
        ),
      ),
      body: _loading
          ? const SkeletonList(count: 3, itemHeight: 110)
          : _error != null
              ? EmptyStateWidget(
                  icon:     Icons.cloud_off_rounded,
                  title:    'Couldn\'t load this tour',
                  subtitle: _error!,
                  action: SizedBox(
                    width: 180,
                    child: AppButton(label: 'Try again', icon: Icons.refresh_rounded, onPressed: _loadData),
                  ),
                )
              : TabBarView(
                  controller: _tabs,
                  children: [
                    RefreshIndicator(
                      onRefresh: () => _loadData(quiet: true),
                      child: _overview(context, myUid, symbol, p, t),
                    ),
                    _expensesTab(myUid, symbol),
                    _debtsTab(myUid, symbol, p),
                  ],
                ),
    );
  }

  // ── Overview: summary, your balance (settle up), who paid ──────────────────
  Widget _overview(BuildContext context, String myUid, String symbol, AppPalette p, TextTheme t) {
    final group      = widget.group;
    final totalSpent = _expenses.fold<double>(0, (s, e) => s + e.amount);
    final iOwe       = _debts.where((d) => d.fromUserId == myUid && d.isOpen).toList();
    final owedToMe   = _debts.where((d) => d.toUserId == myUid && d.isOpen).toList();
    final toConfirm  = _payments.where((x) => x.toUserId == myUid && x.isPending).toList();
    final iOweCents  = iOwe.fold<int>(0, (s, d) => s + d.remainingCents);
    final owedCents  = owedToMe.fold<int>(0, (s, d) => s + d.remainingCents);

    final totals = <String, double>{};
    for (final e in _expenses) {
      totals[e.loggedBy] = (totals[e.loggedBy] ?? 0) + e.amount;
    }
    final members = group.members.values.toList()
      ..sort((a, b) => (totals[b.userId] ?? 0).compareTo(totals[a.userId] ?? 0));

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(gradient: AppColors.heroGradient, borderRadius: BorderRadius.circular(24)),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('TOUR TOTAL', style: AppType.overline(const Color(0xFFB5AC97))),
                    const SizedBox(height: 6),
                    MoneyText(totalSpent, symbol: symbol, size: 30, color: const Color(0xFFF7F1E3)),
                    const SizedBox(height: 6),
                    Text(
                      '${_expenses.length} expenses · ${group.members.length} people · '
                      '${DateFormat('d MMM').format(group.createdAt)} – '
                      '${group.inactivatedAt != null ? DateFormat('d MMM').format(group.inactivatedAt!) : '?'}',
                      style: const TextStyle(fontFamily: AppType.body, fontSize: 12.5, color: Color(0xFFB5AC97)),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.flag_rounded, color: AppColors.primary, size: 30),
            ],
          ),
        ),

        const SizedBox(height: 24),
        const SectionHeader('Your balance'),
        if (iOwe.isEmpty && owedToMe.isEmpty && toConfirm.isEmpty)
          const InfoBanner('You\'re all settled in this tour.', icon: Icons.verified_rounded, tone: ChipTone.positive)
        else
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Column(
              children: [
                for (final pay in toConfirm) ...[
                  _ConfirmRow(payment: pay, symbol: symbol, groupId: group.groupId, onDone: () => _loadData(quiet: true)),
                  Divider(height: 1, color: p.hairline),
                ],
                for (final d in iOwe) ...[
                  _OweRow(
                    debt:        d,
                    symbol:      symbol,
                    avatarUrl:   group.members[d.toUserId]?.avatarUrl,
                    waitingCents: _waitingCents(d, myUid),
                    onPay:       () => _showPaySheet(d, symbol, _waitingCents(d, myUid)),
                  ),
                  Divider(height: 1, color: p.hairline),
                ],
                for (final d in owedToMe) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        AvatarWidget(name: d.fromUserName, uid: d.fromUserId, imageUrl: group.members[d.fromUserId]?.avatarUrl, size: 38),
                        const SizedBox(width: 12),
                        Expanded(child: Text('${firstName(d.fromUserName)} owes you', style: t.titleSmall)),
                        MoneyText(d.remainingAmount, symbol: symbol, size: 15, color: p.positive, compact: true),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: p.hairline),
                ],
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      Expanded(child: Text('In total', style: t.bodySmall)),
                      if (iOweCents > 0) ...[
                        Text('you owe ', style: t.bodySmall),
                        MoneyText(Money.fromCents(iOweCents), symbol: symbol, size: 13.5, color: p.negative, compact: true),
                      ],
                      if (iOweCents > 0 && owedCents > 0) Text('  ·  ', style: t.bodySmall),
                      if (owedCents > 0) ...[
                        Text('owed ', style: t.bodySmall),
                        MoneyText(Money.fromCents(owedCents), symbol: symbol, size: 13.5, color: p.positive, compact: true),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 24),
        const SectionHeader('Who paid'),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(
            children: [
              for (var i = 0; i < members.length; i++) ...[
                if (i > 0) Divider(height: 1, color: p.hairline),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      AvatarWidget(name: members[i].name, uid: members[i].userId, imageUrl: members[i].avatarUrl, size: 36),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(members[i].userId == myUid ? 'You' : members[i].name,
                            style: t.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                      ),
                      MoneyText(totals[members[i].userId] ?? 0, symbol: symbol, size: 15, compact: true),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _expensesTab(String myUid, String symbol) {
    if (_expenses.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.receipt_long_rounded, title: 'No expenses', subtitle: 'Nothing was approved in this tour.',
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(
            children: [
              for (var i = 0; i < _expenses.length; i++) ...[
                if (i > 0) Divider(height: 1, color: context.palette.hairline),
                ExpenseTile(expense: _expenses[i], symbol: symbol, myUid: myUid),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _debtsTab(String myUid, String symbol, AppPalette p) {
    if (_debts.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.handshake_rounded, title: 'No debts', subtitle: 'Nobody owed anyone in this tour.',
      );
    }
    final t = Theme.of(context).textTheme;
    final sorted = [..._debts]..sort((a, b) => (a.isOpen ? 0 : 1).compareTo(b.isOpen ? 0 : 1));
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(
            children: [
              for (var i = 0; i < sorted.length; i++) ...[
                if (i > 0) Divider(height: 1, color: p.hairline),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      IconTile(sorted[i].isOpen ? Icons.arrow_forward_rounded : Icons.done_all_rounded,
                          size: 38, radius: 12, color: sorted[i].isOpen ? p.pending : p.positive),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${sorted[i].fromUserId == myUid ? 'You' : firstName(sorted[i].fromUserName)} → '
                              '${sorted[i].toUserId == myUid ? 'you' : firstName(sorted[i].toUserName)}',
                              style: t.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 3),
                            sorted[i].isOpen
                                ? Text('${Money.displayCompact(sorted[i].remainingAmount, symbol)} still to pay', style: t.bodySmall)
                                : const StatusChip('Settled', tone: ChipTone.positive, icon: Icons.check_rounded, dense: true),
                          ],
                        ),
                      ),
                      MoneyText(sorted[i].originalAmount, symbol: symbol, size: 14.5, compact: true),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ── Pay what you owe after the tour ended ──────────────────────────────────
  Future<void> _showPaySheet(DebtModel debt, String symbol, int waitingCents) async {
    final available = debt.remainingCents - waitingCents;
    if (available <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Your payment is waiting for ${firstName(debt.toUserName)} to confirm.'),
      ));
      return;
    }
    final auth   = context.read<AuthController>();
    final amount = TextEditingController(text: Money.format(available));
    final paid   = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) => _PaySheet(
        debt: debt, symbol: symbol, availableCents: available, amountCtrl: amount,
        onPay: (cents) async {
          final me = auth.user!;
          final payment = PaymentModel(
            paymentId: '', groupId: widget.group.groupId, fromUserId: me.uid, fromUserName: me.name,
            toUserId: debt.toUserId, toUserName: debt.toUserName, debtId: debt.debtId,
            amount: Money.fromCents(cents), status: AppConstants.statusPending, loggedAt: DateTime.now(),
          );
          final saved = await _debtService.logPayment(widget.group.groupId, payment);
          inBackground(
            NotificationService().send(
              targetUserId: debt.toUserId,
              groupId:      widget.group.groupId,
              groupName:    widget.group.name,
              type:         AppConstants.notifPaymentPending,
              referenceId:  saved.id,
              message:      '${me.name} paid you ${Money.display(Money.fromCents(cents), symbol)} '
                  'for ${widget.group.name}. Please confirm.',
            ),
            'notify past-tour payment',
          );
        },
      ),
    );
    if (paid == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Payment logged. ${firstName(debt.toUserName)} will confirm it.'),
      ));
      _loadData(quiet: true);
    }
  }
}

class _OweRow extends StatelessWidget {
  final DebtModel debt;
  final String symbol;
  final String? avatarUrl;
  final int waitingCents;
  final VoidCallback onPay;

  const _OweRow({required this.debt, required this.symbol, required this.avatarUrl, required this.waitingCents, required this.onPay});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          AvatarWidget(name: debt.toUserName, uid: debt.toUserId, imageUrl: avatarUrl, size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('You owe ${firstName(debt.toUserName)}', style: t.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                waitingCents > 0
                    ? Text('${Money.displayCompact(Money.fromCents(waitingCents), symbol)} waiting to be confirmed',
                        style: t.bodySmall?.copyWith(color: p.pending))
                    : MoneyText(debt.remainingAmount, symbol: symbol, size: 14, color: p.negative, compact: true),
              ],
            ),
          ),
          SizedBox(
            width: 92,
            child: AppButton(
              label: 'Pay', height: 40,
              onPressed: debt.remainingCents - waitingCents > 0 ? onPay : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfirmRow extends StatefulWidget {
  final PaymentModel payment;
  final String symbol;
  final String groupId;
  final VoidCallback onDone;
  const _ConfirmRow({required this.payment, required this.symbol, required this.groupId, required this.onDone});

  @override
  State<_ConfirmRow> createState() => _ConfirmRowState();
}

class _ConfirmRowState extends State<_ConfirmRow> {
  bool _busy = false;

  Future<void> _decide(bool approve) async {
    setState(() => _busy = true);
    final debts     = context.read<DebtController>();
    final messenger = ScaffoldMessenger.of(context);
    final ok = approve
        ? await debts.approvePayment(widget.groupId, widget.payment, widget.symbol)
        : await debts.rejectPayment(widget.groupId, widget.payment, '', widget.symbol);
    if (mounted) setState(() => _busy = false);
    messenger.showSnackBar(SnackBar(
      content: Text(ok
          ? (approve ? 'Payment confirmed.' : 'Payment rejected.')
          : (debts.lastError ?? 'Couldn\'t do that. Try again.')),
    ));
    if (ok) widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final p   = context.palette;
    final t   = Theme.of(context).textTheme;
    final pay = widget.payment;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          Row(
            children: [
              IconTile(Icons.payments_rounded, size: 38, radius: 12, color: p.positive),
              const SizedBox(width: 12),
              Expanded(
                child: Text('${firstName(pay.fromUserName)} says they paid you',
                    style: t.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              ),
              MoneyText(pay.amount, symbol: widget.symbol, size: 15, color: p.positive, compact: true),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: AppButton(label: 'Reject', outlined: true, height: 42, onPressed: _busy ? null : () => _decide(false))),
              const SizedBox(width: 8),
              Expanded(
                child: AppButton(label: 'Confirm', color: p.positive, height: 42, isLoading: _busy, onPressed: () => _decide(true)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PaySheet extends StatefulWidget {
  final DebtModel debt;
  final String symbol;
  final int availableCents;
  final TextEditingController amountCtrl;
  final Future<void> Function(int cents) onPay;

  const _PaySheet({required this.debt, required this.symbol, required this.availableCents, required this.amountCtrl, required this.onPay});

  @override
  State<_PaySheet> createState() => _PaySheetState();
}

class _PaySheetState extends State<_PaySheet> {
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    final cents = Money.parseCents(widget.amountCtrl.text) ?? 0;
    if (cents <= 0) return setState(() => _error = 'Enter an amount above zero.');
    if (cents > widget.availableCents) {
      return setState(() => _error = 'You can pay at most ${Money.display(Money.fromCents(widget.availableCents), widget.symbol)}.');
    }
    setState(() {
      _busy  = true;
      _error = null;
    });
    try {
      await widget.onPay(cents);
      if (mounted) Navigator.pop(context, true);
    } catch (e, s) {
      logError('past-tour payment', e, s);
      if (mounted) {
        setState(() {
        _busy  = false;
        _error = friendlyError(e, 'Couldn\'t log the payment. Try again.');
      });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Pay ${firstName(widget.debt.toUserName)}', textAlign: TextAlign.center,
              style: t.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Pay them by bKash or cash, then log it here so they can confirm.',
              textAlign: TextAlign.center, style: t.bodyMedium?.copyWith(color: p.textMuted)),
          const SizedBox(height: 18),
          TextField(
            controller:   widget.amountCtrl,
            autofocus:    true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            textAlign:    TextAlign.center,
            style:        AppType.money(30, color: p.text),
            decoration: InputDecoration(
              prefixText: '${widget.symbol} ',
              errorText:  _error,
              helperText: 'Up to ${Money.display(Money.fromCents(widget.availableCents), widget.symbol)}',
            ),
          ),
          const SizedBox(height: 18),
          AppButton(label: 'Log payment', icon: Icons.send_rounded, isLoading: _busy, onPressed: _submit),
        ],
      ),
    );
  }
}
