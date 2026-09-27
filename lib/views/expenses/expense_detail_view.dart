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
import '../../widgets/common/app_button.dart';
import '../../widgets/common/loading_widget.dart';

/// Expense detail screen — shows full expense info and action buttons.
///
/// **Logger view** (currentUser == expense.loggedBy):
///   - Shows per-member approval status
///   - For each rejected member: "Request Again" + "Edit" (custom split only)
///
/// **Approver view** (currentUser is a split member with pending approval):
///   - Shows the expense details and their own share
///   - Approve / Reject buttons
class ExpenseDetailView extends StatefulWidget {
  final String expenseId;
  final String groupId;

  const ExpenseDetailView({
    super.key,
    required this.expenseId,
    required this.groupId,
  });

  @override
  State<ExpenseDetailView> createState() => _ExpenseDetailViewState();
}

class _ExpenseDetailViewState extends State<ExpenseDetailView> {
  ExpenseModel? _expense;
  bool _loading = true;
  String? _error;

  // State for the edit-amount field (one member at a time)
  String? _editingUserId;
  final TextEditingController _editAmountCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadExpense();
  }

  @override
  void dispose() {
    _editAmountCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadExpense() async {
    setState(() { _loading = true; _error = null; });
    try {
      context.read<ExpenseController>()
          .expenseStream(widget.groupId, widget.expenseId)
          .listen((exp) {
        if (mounted) setState(() { _expense = exp; _loading = false; });
      }, onError: (e) {
        if (mounted) setState(() { _loading = false; _error = 'Failed to load expense.'; });
      });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = 'Failed to load expense.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth    = context.read<AuthController>();
    final uid     = auth.user!.uid;
    final scheme  = Theme.of(context).colorScheme;

    if (_loading) {
      return const Scaffold(body: Center(child: AppLoader()));
    }
    if (_error != null || _expense == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Expense Detail')),
        body: Center(child: Text(_error ?? 'Expense not found.')),
      );
    }

    final expense   = _expense!;
    final isLogger  = expense.loggedBy == uid;
    final myStatus  = expense.approvals[uid];

    return Scaffold(
      appBar: AppBar(title: const Text('Expense Detail')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ExpenseSummaryCard(expense: expense, scheme: scheme),
            const SizedBox(height: 20),

            if (isLogger) ...[
              _ApprovalStatusSection(
                expense:        expense,
                scheme:         scheme,
                editingUserId:  _editingUserId,
                editAmountCtrl: _editAmountCtrl,
                onStartEdit:    (uid) => setState(() {
                  _editingUserId = uid;
                  _editAmountCtrl.text =
                      expense.splits[uid]?.amount.toStringAsFixed(2) ?? '';
                }),
                onCancelEdit: () => setState(() => _editingUserId = null),
                onRequestAgain: _handleRequestAgain,
                onEditAndRequest: _handleEditAndRequest,
              ),
            ] else if (myStatus == AppConstants.statusPending) ...[
              _ApproverActionsSection(
                expense:    expense,
                myUid:      uid,
                scheme:     scheme,
                onApprove:  _handleApprove,
                onReject:   _handleReject,
              ),
            ] else ...[
              _StatusBanner(
                status: myStatus ?? AppConstants.statusApproved,
                scheme: scheme,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Action handlers ────────────────────────────────────────────────────────

  Future<void> _handleApprove() async {
    final expCtrl   = context.read<ExpenseController>();
    final groupCtrl = context.read<GroupController>();
    final auth      = context.read<AuthController>();
    final group     = groupCtrl.activeGroup;
    final expense   = _expense!;

    final ok = await expCtrl.approveExpense(
      groupId:        widget.groupId,
      expenseId:      widget.expenseId,
      approverId:     auth.user!.uid,
      approverName:   auth.user!.name,
      loggedBy:       expense.loggedBy,
      expenseTitle:   expense.comment.isNotEmpty ? expense.comment : 'Expense',
      currencySymbol: group?.currencySymbol ?? '৳',
      totalAmount:    expense.amount,
    );
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expense approved!'), backgroundColor: AppColors.success),
      );
      context.pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(expCtrl.errorMessage ?? 'Error'), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _handleReject() async {
    final reasonCtrl = TextEditingController();
    final confirmed  = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reject Expense?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('You can optionally provide a reason:'),
            const SizedBox(height: 12),
            TextField(
              controller:  reasonCtrl,
              maxLength:   120,
              maxLines:    3,
              decoration:  const InputDecoration(
                hintText:    'Reason (optional)',
                border:      OutlineInputBorder(),
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reject', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final expCtrl   = context.read<ExpenseController>();
    final groupCtrl = context.read<GroupController>();
    final auth      = context.read<AuthController>();
    final group     = groupCtrl.activeGroup;
    final expense   = _expense!;

    final ok = await expCtrl.rejectExpense(
      groupId:        widget.groupId,
      expenseId:      widget.expenseId,
      rejecterId:     auth.user!.uid,
      rejecterName:   auth.user!.name,
      loggedBy:       expense.loggedBy,
      currencySymbol: group?.currencySymbol ?? '৳',
      totalAmount:    expense.amount,
      reason:         reasonCtrl.text,
    );
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expense rejected.'), backgroundColor: AppColors.error),
      );
      context.pop();
    }
  }

  Future<void> _handleRequestAgain(String targetUserId) async {
    final expCtrl   = context.read<ExpenseController>();
    final groupCtrl = context.read<GroupController>();
    final auth      = context.read<AuthController>();
    final group     = groupCtrl.activeGroup;
    final expense   = _expense!;

    await expCtrl.requestAgain(
      groupId:       widget.groupId,
      expenseId:     widget.expenseId,
      targetUserId:  targetUserId,
      loggedByName:  auth.user!.name,
      currencySymbol:group?.currencySymbol ?? '৳',
      memberAmount:  expense.splits[targetUserId]?.amount ?? 0,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Approval request sent again.'), backgroundColor: AppColors.success),
    );
  }

  Future<void> _handleEditAndRequest(String targetUserId) async {
    final newAmount = double.tryParse(_editAmountCtrl.text.trim());
    if (newAmount == null || newAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount.'), backgroundColor: AppColors.error),
      );
      return;
    }

    final expCtrl   = context.read<ExpenseController>();
    final groupCtrl = context.read<GroupController>();
    final auth      = context.read<AuthController>();
    final group     = groupCtrl.activeGroup;

    await expCtrl.editAndRequestAgain(
      groupId:       widget.groupId,
      expenseId:     widget.expenseId,
      targetUserId:  targetUserId,
      newAmount:     newAmount,
      loggedByName:  auth.user!.name,
      currencySymbol:group?.currencySymbol ?? '৳',
    );
    if (!mounted) return;
    setState(() => _editingUserId = null);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Amount updated and request sent again.'), backgroundColor: AppColors.success),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _ExpenseSummaryCard extends StatelessWidget {
  final ExpenseModel expense;
  final ColorScheme  scheme;
  const _ExpenseSummaryCard({required this.expense, required this.scheme});

  @override
  Widget build(BuildContext context) {
    final fmt    = DateFormat('MMM d, y • h:mm a');
    final group  = context.read<GroupController>().activeGroup;
    final symbol = group?.currencySymbol ?? '৳';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$symbol${expense.amount.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: scheme.primary)),
            if (expense.comment.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(expense.comment, style: const TextStyle(fontSize: 15)),
            ],
            const SizedBox(height: 8),
            Row(children: [
              Icon(Icons.person_rounded, size: 14, color: scheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Text('By ${expense.loggedByName}', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              Icon(Icons.access_time_rounded, size: 14, color: scheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(fmt.format(expense.createdAt), style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
            ]),
            if (expense.location?.address != null) ...[
              const SizedBox(height: 4),
              Row(children: [
                Icon(Icons.location_on_rounded, size: 14, color: AppColors.secondary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(expense.location!.address!,
                      style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                ),
              ]),
            ],
            const Divider(height: 20),
            Text('Split (${expense.splitType == AppConstants.splitCustom ? 'Custom' : 'Equal'})',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...expense.splits.values.map((s) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(children: [
                Expanded(child: Text(s.name, style: const TextStyle(fontSize: 14))),
                Text('$symbol${s.amount.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ]),
            )),
          ],
        ),
      ),
    );
  }
}

/// Logger's view: shows per-member approval status with action buttons.
class _ApprovalStatusSection extends StatelessWidget {
  final ExpenseModel              expense;
  final ColorScheme               scheme;
  final String?                   editingUserId;
  final TextEditingController     editAmountCtrl;
  final void Function(String uid) onStartEdit;
  final VoidCallback              onCancelEdit;
  final Future<void> Function(String uid) onRequestAgain;
  final Future<void> Function(String uid) onEditAndRequest;

  const _ApprovalStatusSection({
    required this.expense,
    required this.scheme,
    required this.editingUserId,
    required this.editAmountCtrl,
    required this.onStartEdit,
    required this.onCancelEdit,
    required this.onRequestAgain,
    required this.onEditAndRequest,
  });

  @override
  Widget build(BuildContext context) {
    if (expense.approvals.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('This is a solo expense — no approvals needed.'),
        ),
      );
    }

    final group  = context.read<GroupController>().activeGroup;
    final symbol = group?.currencySymbol ?? '৳';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Approval Status', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: scheme.onSurface)),
        const SizedBox(height: 10),
        ...expense.approvals.entries.map((entry) {
          final uid       = entry.key;
          final status    = entry.value;
          final name      = expense.splits[uid]?.name ?? uid;
          final amount    = expense.splits[uid]?.amount ?? 0;
          final reason    = expense.rejectionReasons[uid];
          final isEditing = editingUserId == uid;
          final isCustom  = expense.splitType == AppConstants.splitCustom;

          Color statusColor;
          IconData statusIcon;
          String statusText;
          switch (status) {
            case AppConstants.statusApproved:
              statusColor = AppColors.success;
              statusIcon  = Icons.check_circle_rounded;
              statusText  = 'Approved';
            case AppConstants.statusRejected:
              statusColor = AppColors.error;
              statusIcon  = Icons.cancel_rounded;
              statusText  = 'Rejected';
            default:
              statusColor = Colors.orange;
              statusIcon  = Icons.hourglass_top_rounded;
              statusText  = 'Pending';
          }

          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(statusIcon, color: statusColor, size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15))),
                    Text('$symbol${amount.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ]),
                  const SizedBox(height: 4),
                  Text(statusText, style: TextStyle(fontSize: 12, color: statusColor, fontWeight: FontWeight.w500)),
                  if (reason != null && reason.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text('Reason: "$reason"',
                        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant, fontStyle: FontStyle.italic)),
                  ],
                  if (status == AppConstants.statusRejected) ...[
                    const SizedBox(height: 12),
                    if (!isEditing) ...[
                      Row(children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => onRequestAgain(uid),
                            icon:  const Icon(Icons.send_rounded, size: 16),
                            label: const Text('Request Again'),
                          ),
                        ),
                        if (isCustom) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => onStartEdit(uid),
                              icon:  const Icon(Icons.edit_rounded, size: 16),
                              label: const Text('Edit'),
                              style: OutlinedButton.styleFrom(foregroundColor: AppColors.secondary),
                            ),
                          ),
                        ],
                      ]),
                    ] else ...[
                      // Inline edit amount field
                      TextField(
                        controller:  editAmountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText:   'New amount for $name',
                          prefixText:  symbol,
                          border: const OutlineInputBorder(),
                          suffixText:  'of ${symbol}${expense.amount.toStringAsFixed(2)} total',
                          suffixStyle: const TextStyle(fontSize: 11),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(
                          child: AppButton(
                            label:     'Update & Request',
                            icon:      Icons.send_rounded,
                            onPressed: () => onEditAndRequest(uid),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton(onPressed: onCancelEdit, child: const Text('Cancel')),
                      ]),
                    ],
                  ],
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

/// Approver's view: Approve / Reject buttons + their share info.
class _ApproverActionsSection extends StatelessWidget {
  final ExpenseModel expense;
  final String       myUid;
  final ColorScheme  scheme;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _ApproverActionsSection({
    required this.expense,
    required this.myUid,
    required this.scheme,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final group    = context.read<GroupController>().activeGroup;
    final symbol   = group?.currencySymbol ?? '৳';
    final myAmount = expense.splits[myUid]?.amount ?? 0;
    final expCtrl  = context.watch<ExpenseController>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          color: scheme.primaryContainer.withOpacity(0.4),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text('Your share of this expense:', style: TextStyle(fontSize: 14)),
                const SizedBox(height: 4),
                Text('$symbol${myAmount.toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: scheme.primary)),
                Text('out of $symbol${expense.amount.toStringAsFixed(2)} total',
                    style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        AppButton(
          label:     'Approve',
          icon:      Icons.check_circle_rounded,
          isLoading: expCtrl.isLoading,
          onPressed: onApprove,
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: expCtrl.isLoading ? null : onReject,
          icon:      const Icon(Icons.cancel_rounded, color: AppColors.error),
          label:     const Text('Reject', style: TextStyle(color: AppColors.error)),
          style:     OutlinedButton.styleFrom(
            side:    const BorderSide(color: AppColors.error),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ],
    );
  }
}

/// Shown when user is not the logger and their approval is already resolved.
class _StatusBanner extends StatelessWidget {
  final String      status;
  final ColorScheme scheme;
  const _StatusBanner({required this.status, required this.scheme});

  @override
  Widget build(BuildContext context) {
    final isApproved = status == AppConstants.statusApproved;
    return Card(
      color: (isApproved ? AppColors.success : AppColors.error).withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Icon(
            isApproved ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: isApproved ? AppColors.success : AppColors.error,
          ),
          const SizedBox(width: 12),
          Text(
            isApproved ? 'You approved this expense.' : 'You rejected this expense.',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isApproved ? AppColors.success : AppColors.error,
            ),
          ),
        ]),
      ),
    );
  }
}
