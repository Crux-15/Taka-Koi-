import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../controllers/expense_controller.dart';
import '../../controllers/group_controller.dart';
import '../../models/expense_model.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_constants.dart';
import '../../widgets/common/app_button.dart';

/// Admin-only screen to review a member's expense deletion request.
/// Loaded when admin taps a [notifDeleteExpenseRequest] notification.
/// Route: /expense-delete-review?expenseId=...&groupId=...&memberName=...
class ExpenseDeleteReviewView extends StatefulWidget {
  final String expenseId;
  final String groupId;
  final String memberName;

  const ExpenseDeleteReviewView({
    super.key,
    required this.expenseId,
    required this.groupId,
    required this.memberName,
  });

  @override
  State<ExpenseDeleteReviewView> createState() => _ExpenseDeleteReviewViewState();
}

class _ExpenseDeleteReviewViewState extends State<ExpenseDeleteReviewView> {
  bool _loading = false;

  Future<void> _approve(ExpenseModel expense, ExpenseController expCtrl, String groupName, String symbol) async {
    setState(() => _loading = true);
    final ok = await expCtrl.approveDeleteExpense(
      groupId:        widget.groupId,
      groupName:      groupName,
      expenseId:      widget.expenseId,
      memberId:       expense.loggedBy,       // from the expense doc itself
      memberName:     widget.memberName,
      currencySymbol: symbol,
      amount:         expense.amount,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:         Text(ok ? 'Expense deleted successfully.' : 'Failed. Try again.'),
      backgroundColor: ok ? AppColors.success : AppColors.error,
    ));
    if (ok) Navigator.of(context).pop();
  }

  Future<void> _reject(ExpenseModel expense, ExpenseController expCtrl, String groupName, String symbol) async {
    setState(() => _loading = true);
    final ok = await expCtrl.rejectDeleteExpense(
      groupId:        widget.groupId,
      groupName:      groupName,
      expenseId:      widget.expenseId,
      memberId:       expense.loggedBy,       // from the expense doc itself
      memberName:     widget.memberName,
      currencySymbol: symbol,
      amount:         expense.amount,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:         Text(ok ? 'Rejection sent to ${widget.memberName}.' : 'Failed. Try again.'),
      backgroundColor: ok ? AppColors.warning : AppColors.error,
    ));
    if (ok) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final expCtrl   = context.read<ExpenseController>();
    final groupCtrl = context.read<GroupController>();
    final group     = groupCtrl.activeGroup;
    final groupName = group?.name ?? '';
    final symbol    = group?.currencySymbol ?? '৳';
    final scheme    = Theme.of(context).colorScheme;
    final fmt       = DateFormat('MMM d, y • h:mm a');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Delete Request Review'),
        centerTitle: true,
      ),
      body: StreamBuilder<ExpenseModel>(
        stream: expCtrl.expenseStream(widget.groupId, widget.expenseId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.hasData) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline_rounded, size: 56, color: scheme.onSurfaceVariant),
                  const SizedBox(height: 12),
                  Text(
                    'This expense no longer exists\n(may have already been deleted).',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            );
          }

          final expense = snap.data!;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Request banner ───────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color:        AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                    border:       Border.all(color: AppColors.error.withOpacity(0.3)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.delete_forever_outlined, color: AppColors.error, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Deletion Request',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.error)),
                          const SizedBox(height: 2),
                          Text('${widget.memberName} wants to delete this expense.',
                              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 20),

                // ── Expense details card ─────────────────────────────────
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Expense Details',
                            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 12),
                        _DetailRow(
                          icon:  Icons.attach_money_rounded,
                          label: 'Amount',
                          value: '$symbol${expense.amount.toStringAsFixed(2)}',
                          valueColor: scheme.primary,
                          valueBold:  true,
                        ),
                        if (expense.comment.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          _DetailRow(
                            icon:  Icons.notes_rounded,
                            label: 'Note',
                            value: expense.comment,
                          ),
                        ],
                        const SizedBox(height: 10),
                        _DetailRow(
                          icon:  Icons.person_rounded,
                          label: 'Logged By',
                          value: expense.loggedByName,
                        ),
                        const SizedBox(height: 10),
                        _DetailRow(
                          icon:  Icons.access_time_rounded,
                          label: 'Date',
                          value: fmt.format(expense.createdAt),
                        ),
                        if (expense.location?.address != null) ...[
                          const SizedBox(height: 10),
                          _DetailRow(
                            icon:  Icons.location_on_rounded,
                            label: 'Location',
                            value: expense.location!.address!,
                          ),
                        ],
                        if (expense.splits.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text('Split Members',
                              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8, runSpacing: 6,
                            children: expense.splits.values.map((s) {
                              final status = expense.approvals[s.userId];
                              Color? chipColor;
                              if (status == AppConstants.statusApproved) chipColor = AppColors.success.withOpacity(0.15);
                              if (status == AppConstants.statusRejected)  chipColor = AppColors.error.withOpacity(0.15);
                              return Chip(
                                label:           Text('${s.name} · $symbol${s.amount.toStringAsFixed(2)}',
                                    style: const TextStyle(fontSize: 11)),
                                avatar:          const Icon(Icons.person_rounded, size: 14),
                                backgroundColor: chipColor,
                                visualDensity:   VisualDensity.compact,
                                padding:         EdgeInsets.zero,
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // ── Warning note ─────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:        AppColors.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border:       Border.all(color: AppColors.warning.withOpacity(0.3)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 18),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Approving will permanently delete this expense and all associated debts.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 24),

                // ── Approve / Reject buttons ─────────────────────────────
                if (_loading)
                  const Center(child: CircularProgressIndicator())
                else ...[
                  // Reject button
                  OutlinedButton.icon(
                    icon:  const Icon(Icons.close_rounded),
                    label: const Text('Reject Deletion'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side:    const BorderSide(color: AppColors.error, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape:   RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => _reject(expense, expCtrl, groupName, symbol),
                  ),
                  const SizedBox(height: 12),
                  // Approve button
                  AppButton(
                    label:     'Approve & Delete',
                    icon:      Icons.check_circle_outline_rounded,
                    onPressed: () => _approve(expense, expCtrl, groupName, symbol),
                    isLoading: false,
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   value;
  final Color?   valueColor;
  final bool     valueBold;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.valueBold = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: scheme.onSurfaceVariant),
        const SizedBox(width: 8),
        SizedBox(width: 70,
          child: Text(label,
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant))),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize:   13,
              fontWeight: valueBold ? FontWeight.w700 : FontWeight.w500,
              color:      valueColor ?? scheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}
