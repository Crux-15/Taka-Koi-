import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/debt_controller.dart';
import '../../controllers/group_controller.dart';
import '../../models/debt_model.dart';
import '../../models/payment_model.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_router.dart';
import '../../widgets/common/empty_state_widget.dart';
import '../../widgets/common/loading_widget.dart';

/// Debt overview screen with I Owe / Owed to Me tabs.
class DebtOverviewView extends StatefulWidget {
  const DebtOverviewView({super.key});
  @override
  State<DebtOverviewView> createState() => _DebtOverviewViewState();
}

class _DebtOverviewViewState extends State<DebtOverviewView> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = context.read<AuthController>().user?.uid;
      final gid = context.read<GroupController>().activeGroup?.groupId;
      if (uid != null && gid != null) {
        context.read<DebtController>().listenToDebts(gid, uid);
      }
    });
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final debtCtrl  = context.watch<DebtController>();
    final groupCtrl = context.watch<GroupController>();
    final group     = groupCtrl.activeGroup;
    final symbol    = group?.currencySymbol ?? '৳';

    // Compute totals for tab labels
    final totalIOwe    = debtCtrl.iOwe.fold<double>(0, (s, d) => s + d.remainingAmount);
    final totalOwedMe  = debtCtrl.owedToMe.fold<double>(0, (s, d) => s + d.remainingAmount);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Debt Settlement'),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: 'I Owe ($symbol${totalIOwe.toStringAsFixed(0)})'),
            Tab(text: 'Owed to Me ($symbol${totalOwedMe.toStringAsFixed(0)})'),
          ],
        ),
      ),
      body: group == null
          ? const Center(child: AppLoader())
          : TabBarView(
              controller: _tabs,
              children: [
                _IOweTab(debts: debtCtrl.iOwe, netDebts: debtCtrl.netDebts, symbol: symbol, groupId: group.groupId),
                _OwedToMeTab(debts: debtCtrl.owedToMe, pendingPayments: debtCtrl.pendingForMe, symbol: symbol, groupId: group.groupId),
              ],
            ),
    );
  }
}

// ── I Owe Tab ─────────────────────────────────────────────────────────────────
class _IOweTab extends StatelessWidget {
  final List<DebtModel>   debts;
  final Map<String, double> netDebts;
  final String            symbol;
  final String            groupId;
  const _IOweTab({required this.debts, required this.netDebts, required this.symbol, required this.groupId});

  @override
  Widget build(BuildContext context) {
    if (debts.isEmpty) {
      return const EmptyStateWidget(
        icon:     Icons.sentiment_very_satisfied_rounded,
        title:    'All Settled!',
        subtitle: 'You don\'t owe anyone right now.',
      );
    }

    // Group debts by toUserId
    final grouped = <String, List<DebtModel>>{};
    for (final d in debts) {
      grouped.putIfAbsent(d.toUserId, () => []).add(d);
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount:     grouped.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final uid   = grouped.keys.elementAt(i);
        final dList = grouped[uid]!;
        final net   = netDebts[uid] ?? 0;
        final personName = dList.first.toUserName;
        return _DebtPersonCard(
          personName: personName,
          debts:      dList,
          netAmount:  net,
          symbol:     symbol,
          isIOwe:     true,
          onPayTap:   net > 0 ? () => context.push('${AppRoutes.logPayment}?debtId=${dList.first.debtId}') : null,
        );
      },
    );
  }
}

// ── Owed to Me Tab ────────────────────────────────────────────────────────────
class _OwedToMeTab extends StatelessWidget {
  final List<DebtModel>    debts;
  final List<PaymentModel> pendingPayments;
  final String             symbol;
  final String             groupId;
  const _OwedToMeTab({required this.debts, required this.pendingPayments, required this.symbol, required this.groupId});

  @override
  Widget build(BuildContext context) {
    final debtCtrl = context.read<DebtController>();
    if (debts.isEmpty && pendingPayments.isEmpty) {
      return const EmptyStateWidget(
        icon:     Icons.account_balance_wallet_outlined,
        title:    'Nothing Owed to You',
        subtitle: 'When someone owes you money, it appears here.',
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Pending payments awaiting my approval
        if (pendingPayments.isNotEmpty) ...[
          Text('Pending Approvals', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          ...pendingPayments.map((p) => _PendingPaymentCard(
            payment: p,
            symbol:  symbol,
            onApprove: () => debtCtrl.approvePayment(groupId, p, symbol),
            onReject:  (note) => debtCtrl.rejectPayment(groupId, p, note, symbol),
          )),
          const SizedBox(height: 16),
        ],
        // Active debts owed to me
        if (debts.isNotEmpty) ...[
          Text('Active Debts', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          ...debts.map((d) => Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              title:    Text(d.fromUserName, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('From expense • $symbol${d.originalAmount.toStringAsFixed(2)} original'),
              trailing: Text('$symbol${d.remainingAmount.toStringAsFixed(2)}',
                  style: const TextStyle(color: AppColors.owedToMe, fontWeight: FontWeight.w700, fontSize: 16)),
            ),
          )),
        ],
      ],
    );
  }
}

class _DebtPersonCard extends StatelessWidget {
  final String          personName;
  final List<DebtModel> debts;
  final double          netAmount;
  final String          symbol;
  final bool            isIOwe;
  final VoidCallback?   onPayTap;
  const _DebtPersonCard({required this.personName, required this.debts, required this.netAmount, required this.symbol, required this.isIOwe, this.onPayTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(personName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Net payable', style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                    Text('$symbol${netAmount.abs().toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize:   20,
                          fontWeight: FontWeight.w800,
                          color:      netAmount > 0 ? AppColors.iOwe : AppColors.owedToMe,
                        )),
                  ],
                ),
              ],
            ),
            const Divider(height: 16),
            ...debts.map((d) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Remaining', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                  Text('$symbol${d.remainingAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            )),
            if (onPayTap != null) ...[
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: onPayTap,
                icon:      const Icon(Icons.payments_rounded, size: 16),
                label:     const Text('Log Payment'),
                style:     ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 44)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PendingPaymentCard extends StatelessWidget {
  final PaymentModel      payment;
  final String            symbol;
  final VoidCallback      onApprove;
  final void Function(String) onReject;
  const _PendingPaymentCard({required this.payment, required this.symbol, required this.onApprove, required this.onReject});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MMM d • h:mm a');
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${payment.fromUserName} paid you', style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(fmt.format(payment.loggedAt), style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                Text('$symbol${payment.amount.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.owedToMe)),
              ],
            ),
            if (payment.bkashNumber != null) ...[
              const SizedBox(height: 6),
              Text('Via Bkash: ${payment.bkashNumber}', style: const TextStyle(fontSize: 12)),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _showRejectDialog(context),
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.error, side: const BorderSide(color: AppColors.error), minimumSize: const Size(0, 40)),
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onApprove,
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, minimumSize: const Size(0, 40)),
                    child: const Text('Confirm'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showRejectDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title:   const Text('Reject Payment?'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: 'Reason (optional)'), maxLines: 2),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () { Navigator.pop(context); onReject(ctrl.text.trim()); },
            child: const Text('Reject', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}
