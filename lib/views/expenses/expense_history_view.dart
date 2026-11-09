import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/expense_controller.dart';
import '../../controllers/group_controller.dart';
import '../../models/expense_model.dart';
import '../../models/group_model.dart';
import '../../utils/app_router.dart';
import '../../utils/display_helpers.dart';
import '../../utils/money.dart';
import '../../widgets/common/empty_state_widget.dart';
import '../../widgets/ui/ui.dart';

/// Expenses you logged: waiting for approval first, then approved by day.
class ExpenseHistoryView extends StatelessWidget {
  const ExpenseHistoryView({super.key});

  @override
  Widget build(BuildContext context) {
    final expCtrl   = context.watch<ExpenseController>();
    final groupCtrl = context.watch<GroupController>();
    final auth      = context.watch<AuthController>();
    final group     = groupCtrl.activeGroup;
    final uid       = auth.user?.uid ?? '';
    final p         = context.palette;
    final t         = Theme.of(context).textTheme;
    final symbol    = group?.currencySymbol ?? '৳';

    final pending  = expCtrl.myExpenses.where((e) => e.isPending).toList();
    final approved = expCtrl.myExpenses.where((e) => e.isApproved).toList();
    final paid     = approved.fold<double>(0, (s, e) => s + e.amount);

    final byDay = <DateTime, List<ExpenseModel>>{};
    for (final e in approved) {
      byDay.putIfAbsent(DateTime(e.createdAt.year, e.createdAt.month, e.createdAt.day), () => []).add(e);
    }
    final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));

    void open(ExpenseModel e) =>
        context.push('${AppRoutes.expenseDetail}?expenseId=${e.expenseId}&groupId=${group?.groupId ?? ''}');

    Widget tile(ExpenseModel e) => Row(
          children: [
            Expanded(child: ExpenseTile(expense: e, symbol: symbol, myUid: uid, showStatus: true, onTap: () => open(e))),
            if (group != null)
              IconButton(
                tooltip:   'More',
                icon:      Icon(Icons.more_vert_rounded, color: p.textFaint, size: 20),
                onPressed: () => _showActions(context, e, group, uid, auth.user?.name ?? '', open),
              ),
          ],
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Your expenses'), centerTitle: true),
      body: expCtrl.myExpenses.isEmpty
          ? EmptyStateWidget(
              icon:     Icons.receipt_long_rounded,
              title:    'Nothing logged yet',
              subtitle: 'Expenses you add for the tour show up here.',
              action: SizedBox(
                width: 200,
                child: FilledButton.icon(
                  onPressed: () => context.push(AppRoutes.logExpense),
                  icon:  const Icon(Icons.add_rounded),
                  label: const Text('Add expense'),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                AppCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('YOU PAID FOR THE GROUP', style: AppType.overline(p.textMuted)),
                            const SizedBox(height: 6),
                            MoneyText(paid, symbol: symbol, size: 26),
                            const SizedBox(height: 4),
                            Text(
                              '${approved.length} approved'
                              '${pending.isEmpty ? '' : ' · ${pending.length} waiting'}',
                              style: t.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const IconTile(Icons.receipt_long_rounded, size: 50),
                    ],
                  ),
                ),
                if (pending.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  SectionHeader('Waiting for approval',
                      trailing: StatusChip('${pending.length}', tone: ChipTone.pending, dense: true)),
                  AppCard(
                    padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
                    child: Column(
                      children: [
                        for (var i = 0; i < pending.length; i++) ...[
                          if (i > 0) Divider(height: 1, color: p.hairline),
                          tile(pending[i]),
                          _ApprovalProgress(expense: pending[i]),
                        ],
                      ],
                    ),
                  ),
                ],
                for (final day in days) ...[
                  const SizedBox(height: 24),
                  SectionHeader(
                    dayLabel(day),
                    trailing: Text(
                      Money.displayCompact(byDay[day]!.fold<double>(0, (s, e) => s + e.amount), symbol),
                      style: AppType.money(13.5, weight: FontWeight.w600, color: p.textMuted),
                    ),
                  ),
                  AppCard(
                    padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
                    child: Column(
                      children: [
                        for (var i = 0; i < byDay[day]!.length; i++) ...[
                          if (i > 0) Divider(height: 1, color: p.hairline),
                          tile(byDay[day]![i]),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  void _showActions(
    BuildContext context,
    ExpenseModel e,
    GroupModel group,
    String uid,
    String userName,
    void Function(ExpenseModel) open,
  ) {
    final isAdmin = group.adminId == uid;
    showModalBottomSheet(
      context: context,
      builder: (sheetCtx) {
        final p = sheetCtx.palette;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.open_in_new_rounded),
                  title:   const Text('View details'),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    open(e);
                  },
                ),
                ListTile(
                  leading:  Icon(Icons.delete_outline_rounded, color: p.negative),
                  title:    Text(isAdmin ? 'Delete expense' : 'Ask the admin to delete it',
                      style: TextStyle(color: p.negative)),
                  subtitle: Text(isAdmin
                      ? 'Removes it and its unpaid debts'
                      : 'The admin decides'),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    isAdmin
                        ? _confirmDirectDelete(context, e, group)
                        : _requestDeleteApproval(context, e, group, userName);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmDirectDelete(BuildContext context, ExpenseModel e, GroupModel group) {
    final expCtrl = context.read<ExpenseController>();
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title:   const Text('Delete this expense?'),
        content: const Text('It and its unpaid debts are removed for everyone. This can\'t be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(dialogCtx);
              final ok = await expCtrl.deleteExpense(group.groupId, e.expenseId);
              messenger.showSnackBar(SnackBar(
                content: Text(ok ? 'Expense deleted.' : (expCtrl.errorMessage ?? 'Couldn\'t delete it.')),
              ));
            },
            child: Text('Delete', style: TextStyle(color: dialogCtx.palette.negative)),
          ),
        ],
      ),
    );
  }

  void _requestDeleteApproval(BuildContext context, ExpenseModel e, GroupModel group, String userName) {
    final expCtrl = context.read<ExpenseController>();
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title:   const Text('Ask to delete it?'),
        content: Text(
          'We\'ll ask the admin to delete ${Money.displayCompact(e.amount, group.currencySymbol)}'
          '${e.comment.isNotEmpty ? ' (${e.comment})' : ''}.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(dialogCtx);
              final ok = await expCtrl.requestDeleteExpense(
                groupId:        group.groupId,
                groupName:      group.name,
                expenseId:      e.expenseId,
                adminId:        group.adminId,
                memberName:     userName,
                currencySymbol: group.currencySymbol,
                amount:         e.amount,
              );
              messenger.showSnackBar(SnackBar(
                content: Text(ok ? 'Request sent to the admin.' : (expCtrl.errorMessage ?? 'Couldn\'t send it. Try again.')),
              ));
            },
            child: const Text('Send request'),
          ),
        ],
      ),
    );
  }
}

/// "2 of 3 approved" bar under a pending expense.
class _ApprovalProgress extends StatelessWidget {
  final ExpenseModel expense;
  const _ApprovalProgress({required this.expense});

  @override
  Widget build(BuildContext context) {
    final p     = context.palette;
    final total = expense.approvals.length;
    final done  = expense.approvals.values.where((v) => v == 'approved').length;
    final waiting = expense.approvals.entries
        .where((e) => e.value == 'pending')
        .map((e) => firstName(expense.splits[e.key]?.name ?? ''))
        .where((n) => n.isNotEmpty)
        .toList();
    if (total == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(58, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: LinearProgressIndicator(
              value: done / total, minHeight: 5, color: p.positive, backgroundColor: p.surfaceSunken,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            waiting.isEmpty ? '$done of $total approved' : '$done of $total approved · waiting for ${waiting.join(', ')}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}
