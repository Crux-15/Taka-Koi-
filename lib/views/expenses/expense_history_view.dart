import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/expense_controller.dart';
import '../../controllers/group_controller.dart';
import '../../models/expense_model.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_constants.dart';
import '../../utils/app_router.dart';
import '../../widgets/common/empty_state_widget.dart';

/// Detailed expense history for the current user.
/// Shows both PENDING (awaiting approval) and APPROVED expenses.
/// Tap any card to open the detail screen.
class ExpenseHistoryView extends StatelessWidget {
  const ExpenseHistoryView({super.key});

  @override
  Widget build(BuildContext context) {
    final expCtrl   = context.watch<ExpenseController>();
    final groupCtrl = context.watch<GroupController>();
    final auth      = context.watch<AuthController>();
    final group     = groupCtrl.activeGroup;
    final isAdmin   = group?.adminId == auth.user?.uid;
    final uid       = auth.user?.uid ?? '';
    final userName  = auth.user?.name ?? '';

    final pending  = expCtrl.myExpenses.where((e) => e.isPending).toList();
    final approved = expCtrl.myExpenses.where((e) => e.isApproved).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('My Expenses')),
      body: expCtrl.myExpenses.isEmpty
          ? const EmptyStateWidget(
              icon:     Icons.receipt_long_outlined,
              title:    'No Expenses Yet',
              subtitle: 'Your logged expenses will appear here.',
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Pending section ──────────────────────────────────────
                if (pending.isNotEmpty) ...[
                  _SectionHeader(
                    title: 'Awaiting Approval',
                    count: pending.length,
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 8),
                  ...pending.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ExpenseCard(
                      expense:         e,
                      symbol:          group?.currencySymbol ?? '৳',
                      expCtrl:         expCtrl,
                      groupId:         group?.groupId ?? '',
                      groupName:       group?.name ?? '',
                      adminId:         group?.adminId ?? '',
                      currentUid:      uid,
                      currentUserName: userName,
                      isAdmin:         isAdmin,
                    ),
                  )),
                  const SizedBox(height: 8),
                ],

                // ── Approved section ─────────────────────────────────────
                if (approved.isNotEmpty) ...[
                  _SectionHeader(
                    title: 'Approved',
                    count: approved.length,
                    color: AppColors.success,
                  ),
                  const SizedBox(height: 8),
                  ...approved.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ExpenseCard(
                      expense:         e,
                      symbol:          group?.currencySymbol ?? '৳',
                      expCtrl:         expCtrl,
                      groupId:         group?.groupId ?? '',
                      groupName:       group?.name ?? '',
                      adminId:         group?.adminId ?? '',
                      currentUid:      uid,
                      currentUserName: userName,
                      isAdmin:         isAdmin,
                    ),
                  )),
                ],
              ],
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int    count;
  final Color  color;
  const _SectionHeader({required this.title, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(width: 4, height: 18, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Text('$title ($count)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
    ]);
  }
}

class _ExpenseCard extends StatelessWidget {
  final ExpenseModel      expense;
  final String            symbol;
  final ExpenseController expCtrl;
  final String            groupId;
  final String            groupName;
  final String            adminId;
  final String            currentUid;
  final String            currentUserName;
  final bool              isAdmin;

  const _ExpenseCard({
    required this.expense,
    required this.symbol,
    required this.expCtrl,
    required this.groupId,
    required this.groupName,
    required this.adminId,
    required this.currentUid,
    required this.currentUserName,
    required this.isAdmin,
  });

  @override
  Widget build(BuildContext context) {
    final scheme    = Theme.of(context).colorScheme;
    final fmt       = DateFormat('MMM d, y • h:mm a');
    final canDelete = expense.loggedBy == currentUid || isAdmin;
    final isPending = expense.isPending;

    // Approval summary for pending expenses
    String? approvalSummary;
    if (isPending && expense.approvals.isNotEmpty) {
      final approved = expense.approvals.values.where((v) => v == AppConstants.statusApproved).length;
      final rejected = expense.approvals.values.where((v) => v == AppConstants.statusRejected).length;
      final total    = expense.approvals.length;
      if (rejected > 0) {
        approvalSummary = '$rejected rejected · $approved/$total approved';
      } else {
        approvalSummary = '$approved/$total approved';
      }
    }

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push(
          '${AppRoutes.expenseDetail}?expenseId=${expense.expenseId}&groupId=$groupId',
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: amount + status badge + delete
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$symbol${expense.amount.toStringAsFixed(2)}',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: scheme.primary)),
                        if (approvalSummary != null) ...[
                          const SizedBox(height: 2),
                          Text(approvalSummary,
                              style: TextStyle(
                                fontSize: 11,
                                color: expense.hasRejection ? AppColors.error : Colors.orange,
                                fontWeight: FontWeight.w600,
                              )),
                        ],
                      ],
                    ),
                  ),
                  // Status chip
                  _StatusChip(expense: expense),
                  if (canDelete) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      icon:    Icon(isAdmin
                          ? Icons.delete_outline_rounded
                          : Icons.delete_forever_outlined),
                      color:   AppColors.error,
                      tooltip: isAdmin ? 'Delete expense' : 'Request deletion',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => isAdmin
                          ? _confirmDirectDelete(context)
                          : _requestDeleteApproval(context),
                    ),
                  ],
                ],
              ),

              if (expense.comment.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(expense.comment, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              ],

              const SizedBox(height: 8),
              Row(children: [
                Icon(Icons.access_time_rounded, size: 13, color: scheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(fmt.format(expense.createdAt), style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
              ]),

              if (expense.location?.address != null) ...[
                const SizedBox(height: 4),
                Row(children: [
                  Icon(Icons.location_on_rounded, size: 13, color: AppColors.secondary),
                  const SizedBox(width: 4),
                  Expanded(child: Text(expense.location!.address!,
                      style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
                ]),
              ],

              if (expense.splits.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6, runSpacing: 4,
                  children: expense.splits.values.map((s) {
                    final memberStatus = expense.approvals[s.userId];
                    Color? chipColor;
                    if (memberStatus == AppConstants.statusApproved) chipColor = AppColors.success.withOpacity(0.15);
                    if (memberStatus == AppConstants.statusRejected)  chipColor = AppColors.error.withOpacity(0.15);
                    return Chip(
                      label:         Text(s.name, style: const TextStyle(fontSize: 10)),
                      padding:       EdgeInsets.zero,
                      avatar:        const Icon(Icons.person_rounded, size: 12),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: chipColor,
                    );
                  }).toList(),
                ),
              ],

              // Tap hint
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('Tap for details', style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                  const SizedBox(width: 2),
                  Icon(Icons.chevron_right_rounded, size: 14, color: scheme.onSurfaceVariant),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Admin: direct delete ──────────────────────────────────────────────────
  void _confirmDirectDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title:   const Text('Delete Expense?'),
        content: const Text('This expense and all associated debts will be permanently removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () { Navigator.pop(context); expCtrl.deleteExpense(groupId, expense.expenseId); },
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  // ── Member: request deletion approval from admin ──────────────────────────
  void _requestDeleteApproval(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.delete_forever_outlined, color: AppColors.error, size: 22),
          SizedBox(width: 8),
          Text('Request Deletion'),
        ]),
        content: Text(
          'Send a deletion request to the group admin?\n\n'
          'Amount: $symbol${expense.amount.toStringAsFixed(2)}'
          '${expense.comment.isNotEmpty ? "\nNote: ${expense.comment}" : ""}',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              Navigator.pop(context);
              final ok = await expCtrl.requestDeleteExpense(
                groupId:        groupId,
                groupName:      groupName,
                expenseId:      expense.expenseId,
                adminId:        adminId,
                memberName:     currentUserName,
                currencySymbol: symbol,
                amount:         expense.amount,
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(ok
                      ? 'Deletion request sent to admin.'
                      : 'Failed to send request. Try again.'),
                  backgroundColor: ok ? AppColors.success : AppColors.error,
                ));
              }
            },
            child: const Text('Send Request', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final ExpenseModel expense;
  const _StatusChip({required this.expense});

  @override
  Widget build(BuildContext context) {
    String label;
    Color  color;
    if (expense.isApproved) {
      label = 'Approved';
      color = AppColors.success;
    } else if (expense.hasRejection) {
      label = 'Has Rejection';
      color = AppColors.error;
    } else {
      label = 'Pending';
      color = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color:        color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border:       Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700)),
    );
  }
}
