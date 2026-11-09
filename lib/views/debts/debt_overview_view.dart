import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/debt_controller.dart';
import '../../controllers/group_controller.dart';
import '../../models/debt_model.dart';
import '../../models/group_model.dart';
import '../../models/payment_model.dart';
import '../../utils/app_router.dart';
import '../../utils/display_helpers.dart';
import '../../utils/money.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/avatar_widget.dart';
import '../../widgets/common/empty_state_widget.dart';
import '../../widgets/common/loading_widget.dart';
import '../../widgets/ui/ui.dart';

/// Balances: who you owe, who owes you, and payments waiting for you.
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
      if (!mounted) return;
      final uid = context.read<AuthController>().user?.uid;
      final gid = context.read<GroupController>().activeGroup?.groupId;
      if (uid != null && gid != null) {
        context.read<DebtController>().listenToDebts(gid, uid);
        // Open on whichever side needs attention.
        final debts = context.read<DebtController>();
        if (debts.isLoaded && debts.iOwe.isEmpty && (debts.owedToMe.isNotEmpty || debts.pendingForMe.isNotEmpty)) {
          _tabs.index = 1;
        }
      }
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final debtCtrl = context.watch<DebtController>();
    final group    = context.watch<GroupController>().activeGroup;
    final p        = context.palette;
    final t        = Theme.of(context).textTheme;

    if (group == null) return const Scaffold(body: Center(child: AppLoader()));
    final symbol = group.currencySymbol;
    final toConfirm = debtCtrl.pendingForMe.length;

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverSafeArea(
            bottom: false,
            sliver: SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Balances', style: t.headlineMedium),
                    const SizedBox(height: 4),
                    Text('Pay what you owe and confirm what you receive.', style: t.bodyMedium?.copyWith(color: p.textMuted)),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: _SummaryTile(
                            label:   'You owe',
                            cents:   debtCtrl.iOweCents,
                            symbol:  symbol,
                            color:   p.negative,
                            icon:    Icons.north_east_rounded,
                            loaded:  debtCtrl.isLoaded,
                            onTap:   () => _tabs.animateTo(0),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _SummaryTile(
                            label:   'Owed to you',
                            cents:   debtCtrl.owedToMeCents,
                            symbol:  symbol,
                            color:   p.positive,
                            icon:    Icons.south_west_rounded,
                            loaded:  debtCtrl.isLoaded,
                            onTap:   () => _tabs.animateTo(1),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: PillTabBar(
              controller: _tabs,
              margin:     const EdgeInsets.fromLTRB(20, 18, 20, 4),
              tabs: [
                const Tab(text: 'You owe'),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Owed to you'),
                      if (toConfirm > 0) ...[
                        const SizedBox(width: 6),
                        StatusChip('$toConfirm', tone: ChipTone.positive, dense: true),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        body: !debtCtrl.isLoaded
            ? const SkeletonList(count: 3, itemHeight: 120)
            : TabBarView(
                controller: _tabs,
                children: [
                  _IOweTab(debtCtrl: debtCtrl, group: group),
                  _OwedToMeTab(debtCtrl: debtCtrl, group: group),
                ],
              ),
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final int cents;
  final String symbol;
  final Color color;
  final IconData icon;
  final bool loaded;
  final VoidCallback onTap;

  const _SummaryTile({
    required this.label,
    required this.cents,
    required this.symbol,
    required this.color,
    required this.icon,
    required this.loaded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AppCard(
      onTap:   onTap,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24, height: 24,
                decoration: BoxDecoration(color: p.soft(color), shape: BoxShape.circle),
                child: Icon(icon, size: 14, color: color),
              ),
              const SizedBox(width: 8),
              Text(label, style: Theme.of(context).textTheme.labelMedium),
            ],
          ),
          const SizedBox(height: 10),
          loaded
              ? MoneyText(Money.fromCents(cents), symbol: symbol, size: 21, color: cents == 0 ? p.textMuted : p.text)
              : const Skeleton(width: 90, height: 20),
        ],
      ),
    );
  }
}

// ── You owe ───────────────────────────────────────────────────────────────────
class _IOweTab extends StatelessWidget {
  final DebtController debtCtrl;
  final GroupModel group;
  const _IOweTab({required this.debtCtrl, required this.group});

  @override
  Widget build(BuildContext context) {
    final debts = debtCtrl.iOwe;
    if (debts.isEmpty) {
      return const EmptyStateWidget(
        icon:     Icons.verified_rounded,
        title:    'You\'re all clear',
        subtitle: 'You don\'t owe anyone in this tour right now.',
      );
    }
    final symbol  = group.currencySymbol;
    final grouped = <String, List<DebtModel>>{};
    for (final d in debts) {
      grouped.putIfAbsent(d.toUserId, () => []).add(d);
    }
    final people = grouped.keys.toList()
      ..sort((a, b) => _sum(grouped[b]!).compareTo(_sum(grouped[a]!)));

    return ListView.separated(
      padding:          const EdgeInsets.fromLTRB(20, 16, 20, 32),
      itemCount:        people.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, i) {
        final uid       = people[i];
        final list      = grouped[uid]!;
        final name      = list.first.toUserName;
        final owed      = _sum(list);
        final netCents  = Money.toCents(debtCtrl.netDebts[uid] ?? 0);
        final waiting   = list.fold<int>(0, (s, d) => s + debtCtrl.pendingCentsFor(d.debtId));
        // Each debt is paid on its own, so Pay is offered while any of them
        // still has room, even if they also owe you (else mutual debts never close).
        final payable   = list.where((d) => debtCtrl.availableCentsFor(d) > 0).firstOrNull;

        return _PersonCard(
          name:      name,
          avatarUrl: group.members[uid]?.avatarUrl,
          caption:   'You owe ${firstName(name)}',
          cents:     owed,
          symbol:    symbol,
          tone:      context.palette.negative,
          items:     list,
          notes: [
            if (waiting > 0)
              _Note(Icons.schedule_rounded, ChipTone.pending,
                  '${Money.displayCompact(Money.fromCents(waiting), symbol)} paid, waiting for ${firstName(name)} to confirm'),
            if (netCents != owed)
              _Note(Icons.swap_horiz_rounded, ChipTone.info,
                  netCents > 0
                      ? 'They owe you too. Net, you owe ${Money.displayCompact(Money.fromCents(netCents), symbol)}'
                      : netCents < 0
                          ? 'They owe you more. Net, they owe you ${Money.displayCompact(Money.fromCents(-netCents), symbol)}'
                          : 'They owe you the same amount, so overall you\'re even'),
          ],
          action: payable == null
              ? null
              : AppButton(
                  label:     'Pay ${firstName(name)}',
                  icon:      Icons.arrow_outward_rounded,
                  height:    48,
                  onPressed: () => context.push('${AppRoutes.logPayment}?debtId=${payable.debtId}'),
                ),
        );
      },
    );
  }

  static int _sum(List<DebtModel> l) => l.fold(0, (s, d) => s + d.remainingCents);
}

// ── Owed to you ───────────────────────────────────────────────────────────────
class _OwedToMeTab extends StatelessWidget {
  final DebtController debtCtrl;
  final GroupModel group;
  const _OwedToMeTab({required this.debtCtrl, required this.group});

  @override
  Widget build(BuildContext context) {
    final debts   = debtCtrl.owedToMe;
    final pending = debtCtrl.pendingForMe;
    final symbol  = group.currencySymbol;
    if (debts.isEmpty && pending.isEmpty) {
      return const EmptyStateWidget(
        icon:     Icons.savings_rounded,
        title:    'Nobody owes you',
        subtitle: 'When someone owes you for an expense you paid, it shows up here.',
      );
    }
    final grouped = <String, List<DebtModel>>{};
    for (final d in debts) {
      grouped.putIfAbsent(d.fromUserId, () => []).add(d);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        if (pending.isNotEmpty) ...[
          const SectionHeader('Confirm these payments'),
          for (final pay in pending)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _PendingPaymentCard(payment: pay, group: group, debtCtrl: debtCtrl),
            ),
          const SizedBox(height: 14),
        ],
        if (grouped.isNotEmpty) ...[
          const SectionHeader('Still to pay you'),
          for (final uid in grouped.keys)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _PersonCard(
                name:      grouped[uid]!.first.fromUserName,
                avatarUrl: group.members[uid]?.avatarUrl,
                caption:   '${firstName(grouped[uid]!.first.fromUserName)} owes you',
                cents:     grouped[uid]!.fold(0, (s, d) => s + d.remainingCents),
                symbol:    symbol,
                tone:      context.palette.positive,
                items:     grouped[uid]!,
              ),
            ),
        ],
      ],
    );
  }
}

class _Note {
  final IconData icon;
  final ChipTone tone;
  final String text;
  const _Note(this.icon, this.tone, this.text);
}

/// One person's debts with you: total, the expenses behind it, notes, action.
class _PersonCard extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final String caption;
  final int cents;
  final String symbol;
  final Color tone;
  final List<DebtModel> items;
  final List<_Note> notes;
  final Widget? action;

  const _PersonCard({
    required this.name,
    required this.avatarUrl,
    required this.caption,
    required this.cents,
    required this.symbol,
    required this.tone,
    required this.items,
    this.notes = const [],
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AvatarWidget(name: name, imageUrl: avatarUrl, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: t.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(caption, style: t.bodySmall),
                  ],
                ),
              ),
              MoneyText(Money.fromCents(cents), symbol: symbol, size: 20, color: tone),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(color: p.surfaceRaised, borderRadius: BorderRadius.circular(14)),
            child: Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: p.hairline),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    child: Row(
                      children: [
                        Icon(Icons.receipt_rounded, size: 15, color: p.textFaint),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            items[i].remainingCents < Money.toCents(items[i].originalAmount)
                                ? 'Share from ${timeAgo(items[i].createdAt)} · part paid'
                                : 'Share from ${timeAgo(items[i].createdAt)}',
                            style: t.bodySmall?.copyWith(color: p.textMuted),
                          ),
                        ),
                        if (items[i].remainingCents < Money.toCents(items[i].originalAmount)) ...[
                          Text(Money.displayCompact(items[i].originalAmount, symbol),
                              style: t.bodySmall?.copyWith(decoration: TextDecoration.lineThrough, color: p.textFaint)),
                          const SizedBox(width: 6),
                        ],
                        MoneyText(items[i].remainingAmount, symbol: symbol, size: 13.5, weight: FontWeight.w600, compact: true),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          for (final n in notes) ...[
            const SizedBox(height: 10),
            InfoBanner(n.text, icon: n.icon, tone: n.tone),
          ],
          if (action != null) ...[
            const SizedBox(height: 14),
            action!,
          ],
        ],
      ),
    );
  }
}

class _PendingPaymentCard extends StatefulWidget {
  final PaymentModel payment;
  final GroupModel group;
  final DebtController debtCtrl;
  const _PendingPaymentCard({required this.payment, required this.group, required this.debtCtrl});

  @override
  State<_PendingPaymentCard> createState() => _PendingPaymentCardState();
}

class _PendingPaymentCardState extends State<_PendingPaymentCard> {
  bool _busy = false;

  Future<void> _approve() async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await widget.debtCtrl.approvePayment(widget.group.groupId, widget.payment, widget.group.currencySymbol);
    if (mounted) setState(() => _busy = false);
    messenger.showSnackBar(SnackBar(
      content: Text(ok ? doneMessage('Payment confirmed.', queued: widget.debtCtrl.savedOffline) : (widget.debtCtrl.lastError ?? 'Couldn\'t confirm. Try again.')),
    ));
  }

  Future<void> _reject() async {
    final ctrl = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title:   const Text('Reject this payment?'),
        content: TextField(
          controller: ctrl,
          autofocus:  true,
          maxLines:   2,
          decoration: const InputDecoration(hintText: 'Why? (optional, e.g. "only got ৳400")'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, ctrl.text.trim()),
            child: Text('Reject', style: TextStyle(color: dialogCtx.palette.negative)),
          ),
        ],
      ),
    );
    if (note == null || !mounted) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await widget.debtCtrl.rejectPayment(widget.group.groupId, widget.payment, note, widget.group.currencySymbol);
    if (mounted) setState(() => _busy = false);
    messenger.showSnackBar(SnackBar(
      content: Text(ok ? 'Payment rejected. They can log the right amount.' : (widget.debtCtrl.lastError ?? 'Couldn\'t reject. Try again.')),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final p   = context.palette;
    final t   = Theme.of(context).textTheme;
    final pay = widget.payment;
    return AppCard(
      borderColor: p.positive.withValues(alpha: 0.35),
      child: Column(
        children: [
          Row(
            children: [
              AvatarWidget(name: pay.fromUserName, imageUrl: widget.group.members[pay.fromUserId]?.avatarUrl, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${firstName(pay.fromUserName)} says they paid you',
                        style: t.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(
                      pay.bkashNumber != null ? 'Via bKash ${pay.bkashNumber} · ${timeAgo(pay.loggedAt)}' : timeAgo(pay.loggedAt),
                      style: t.bodySmall,
                    ),
                  ],
                ),
              ),
              MoneyText(pay.amount, symbol: widget.group.currencySymbol, size: 20, color: p.positive),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: AppButton(label: 'Reject', outlined: true, height: 46, onPressed: _busy ? null : _reject),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppButton(
                  label:     'Confirm',
                  icon:      Icons.check_rounded,
                  color:     p.positive,
                  height:    46,
                  isLoading: _busy,
                  onPressed: _approve,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
