import 'package:flutter/material.dart';
import '../../models/expense_model.dart';
import '../../utils/display_helpers.dart';
import '../../utils/app_palette.dart';
import '../../utils/money.dart';
import 'money_text.dart';
import 'surfaces.dart';

/// One expense in a list: category icon, note, who paid and when, amount,
/// and what it means for the signed-in member ("your share ৳600").
class ExpenseTile extends StatelessWidget {
  final ExpenseModel expense;
  final String symbol;
  final String myUid;
  final VoidCallback? onTap;
  final bool showStatus;

  const ExpenseTile({
    super.key,
    required this.expense,
    required this.symbol,
    required this.myUid,
    this.onTap,
    this.showStatus = false,
  });

  @override
  Widget build(BuildContext context) {
    final p       = context.palette;
    final t       = Theme.of(context).textTheme;
    final iPaid   = expense.loggedBy == myUid;
    final myShare = expense.splits[myUid]?.amount;
    final title   = expense.comment.trim().isEmpty ? 'Expense' : expense.comment.trim();
    final payer   = iPaid ? 'You paid' : '${firstName(expense.loggedByName)} paid';

    return Pressable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            IconTile(expenseIcon(title), size: 44, color: iPaid ? p.accent : p.textMuted),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: t.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Text('$payer · ${timeAgo(expense.createdAt)}',
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodySmall),
                  if (showStatus && expense.status != 'approved') ...[
                    const SizedBox(height: 6),
                    StatusChip.status(expense.status, dense: true),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                MoneyText(expense.amount, symbol: symbol, size: 15.5, compact: true),
                if (myShare != null && myShare > 0) ...[
                  const SizedBox(height: 3),
                  Text(
                    iPaid ? 'your part ${_short(myShare)}' : 'your share ${_short(myShare)}',
                    style: t.bodySmall?.copyWith(color: iPaid ? p.textMuted : p.negative, fontSize: 11.5),
                  ),
                ] else if (iPaid) ...[
                  const SizedBox(height: 3),
                  Text('you\'re not in it', style: t.bodySmall?.copyWith(fontSize: 11.5)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _short(double v) => Money.displayCompact(v, symbol);
}
