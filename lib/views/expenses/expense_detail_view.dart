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
import '../../utils/money.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/loading_widget.dart';
import '../../utils/display_helpers.dart';
import '../../widgets/common/avatar_widget.dart';
import '../../widgets/ui/ui.dart';

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
        appBar: AppBar(title: const Text('Expense')),
        body: Center(child: Text(_error ?? 'Expense not found.')),
      );
    }

    final expense   = _expense!;
    final isLogger  = expense.loggedBy == uid;
    final myStatus  = expense.approvals[uid];

    return Scaffold(
      appBar: AppBar(title: const Text('Expense'), centerTitle: true),
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
        SnackBar(content: Text(doneMessage('Approved.', queued: expCtrl.savedOffline))),
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
        SnackBar(content: Text(doneMessage('Rejected.', queued: expCtrl.savedOffline))),
      );
      context.pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(expCtrl.errorMessage ?? 'Failed to reject expense.'), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _handleRequestAgain(String targetUserId) async {
    final expCtrl   = context.read<ExpenseController>();
    final groupCtrl = context.read<GroupController>();
    final auth      = context.read<AuthController>();
    final group     = groupCtrl.activeGroup;
    final expense   = _expense!;

    final ok = await expCtrl.requestAgain(
      groupId:       widget.groupId,
      expenseId:     widget.expenseId,
      targetUserId:  targetUserId,
      loggedByName:  auth.user!.name,
      currencySymbol:group?.currencySymbol ?? '৳',
      memberAmount:  expense.splits[targetUserId]?.amount ?? 0,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      ok
          ? SnackBar(content: Text(doneMessage('Asked again.', queued: expCtrl.savedOffline)))
          : SnackBar(content: Text(expCtrl.errorMessage ?? 'Failed to send request.'), backgroundColor: AppColors.error),
    );
  }

  Future<void> _handleEditAndRequest(String targetUserId) async {
    final groupCtrl = context.read<GroupController>();
    final symbol    = groupCtrl.activeGroup?.currencySymbol ?? '৳';
    final expense   = _expense!;

    final newCents = Money.parseCents(_editAmountCtrl.text);
    if (newCents == null || newCents <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount.'), backgroundColor: AppColors.error),
      );
      return;
    }

    // The change comes out of the logger's own share, so the most this member
    // can be asked for is their current share plus the logger's share.
    final currentCents = Money.toCents(expense.splits[targetUserId]?.amount ?? 0);
    final loggerCents  = Money.toCents(expense.splits[expense.loggedBy]?.amount ?? 0);
    final maxCents     = currentCents + loggerCents;
    if (newCents > maxCents) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Shares can\'t add up to more than the total. The most you can ask for is $symbol${Money.format(maxCents)}.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final expCtrl = context.read<ExpenseController>();
    final auth    = context.read<AuthController>();

    final ok = await expCtrl.editAndRequestAgain(
      groupId:       widget.groupId,
      expenseId:     widget.expenseId,
      targetUserId:  targetUserId,
      newAmount:     Money.fromCents(newCents),
      loggedByName:  auth.user!.name,
      currencySymbol:symbol,
    );
    if (!mounted) return;
    if (ok) setState(() => _editingUserId = null);
    ScaffoldMessenger.of(context).showSnackBar(
      ok
          ? SnackBar(content: Text(doneMessage('Share changed and asked again.', queued: expCtrl.savedOffline)))
          : SnackBar(content: Text(expCtrl.errorMessage ?? 'Failed to update and re-request.'), backgroundColor: AppColors.error),
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
    final p      = context.palette;
    final t      = Theme.of(context).textTheme;
    final fmt    = DateFormat('EEE, d MMM · h:mm a');
    final group  = context.read<GroupController>().activeGroup;
    final symbol = group?.currencySymbol ?? '৳';
    final title  = expense.comment.trim().isEmpty ? 'Expense' : expense.comment.trim();

    return AppCard(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
      child: Column(
        children: [
          IconTile(expenseIcon(title), size: 56, radius: 18),
          const SizedBox(height: 12),
          Text(title, textAlign: TextAlign.center, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          MoneyText(expense.amount, symbol: symbol, size: 38),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              StatusChip.status(expense.status),
              StatusChip('Paid by ${firstName(expense.loggedByName)}', icon: Icons.person_rounded),
              StatusChip(expense.splitType == AppConstants.splitCustom ? 'Custom split' : 'Split equally',
                  icon: Icons.call_split_rounded),
            ],
          ),
          const SizedBox(height: 14),
          Text(fmt.format(expense.createdAt), style: t.bodySmall),
          if (expense.location?.address != null) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.place_rounded, size: 14, color: p.textFaint),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(expense.location!.address!, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodySmall),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          // Dashed "receipt" edge
          Row(
            children: List.generate(
              30,
              (i) => Expanded(
                child: Container(height: 1.2, color: i.isEven ? p.hairline : Colors.transparent),
              ),
            ),
          ),
          const SizedBox(height: 6),
          for (final entry in expense.splits.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  AvatarWidget(name: entry.value.name, imageUrl: group?.members[entry.key]?.avatarUrl, size: 30),
                  const SizedBox(width: 10),
                  Expanded(child: Text(entry.value.name, style: t.bodyMedium)),
                  if (entry.key != expense.loggedBy && expense.approvals[entry.key] != null) ...[
                    _ApprovalDot(status: expense.approvals[entry.key]!),
                    const SizedBox(width: 10),
                  ],
                  MoneyText(entry.value.amount, symbol: symbol, size: 14.5, weight: FontWeight.w600, compact: true),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ApprovalDot extends StatelessWidget {
  final String status;
  const _ApprovalDot({required this.status});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final (IconData icon, Color c) = switch (status) {
      AppConstants.statusApproved => (Icons.check_circle_rounded, p.positive),
      AppConstants.statusRejected => (Icons.cancel_rounded, p.negative),
      _                           => (Icons.schedule_rounded, p.pending),
    };
    return Icon(icon, size: 17, color: c);
  }
}

/// Logger's view: each member's approval, with request-again / edit actions.
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
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    if (expense.approvals.isEmpty) {
      return const InfoBanner('Only you are in this one, so it didn\'t need anyone\'s approval.',
          icon: Icons.person_rounded, tone: ChipTone.accent);
    }

    final group    = context.read<GroupController>().activeGroup;
    final symbol   = group?.currencySymbol ?? '৳';
    final approved = expense.approvals.values.where((v) => v == AppConstants.statusApproved).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader('Approvals', trailing: Text('$approved of ${expense.approvals.length}', style: t.bodySmall)),
        ClipRRect(
          borderRadius: BorderRadius.circular(100),
          child: LinearProgressIndicator(
            value: expense.approvals.isEmpty ? 0 : approved / expense.approvals.length,
            minHeight: 6,
            color: p.positive,
            backgroundColor: p.surfaceSunken,
          ),
        ),
        const SizedBox(height: 14),
        ...expense.approvals.entries.map((entry) {
          final uid       = entry.key;
          final status    = entry.value;
          final name      = expense.splits[uid]?.name ?? uid;
          final amount    = expense.splits[uid]?.amount ?? 0;
          final reason    = expense.rejectionReasons[uid];
          final isEditing = editingUserId == uid;
          final isCustom  = expense.splitType == AppConstants.splitCustom;

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              padding: const EdgeInsets.all(14),
              borderColor: status == AppConstants.statusRejected ? p.negative.withValues(alpha: 0.35) : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    AvatarWidget(name: name, imageUrl: group?.members[uid]?.avatarUrl, size: 38),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          StatusChip.status(status),
                        ],
                      ),
                    ),
                    MoneyText(amount, symbol: symbol, size: 16, compact: true),
                  ]),
                  if (reason != null && reason.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    InfoBanner('"$reason"', icon: Icons.format_quote_rounded, tone: ChipTone.negative),
                  ],
                  if (status == AppConstants.statusRejected) ...[
                    const SizedBox(height: 12),
                    if (!isEditing)
                      Row(children: [
                        Expanded(
                          child: AppButton(
                            label: 'Ask again', icon: Icons.refresh_rounded, outlined: true, height: 44,
                            onPressed: () => onRequestAgain(uid),
                          ),
                        ),
                        if (isCustom) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: AppButton(
                              label: 'Change share', icon: Icons.edit_rounded, height: 44,
                              onPressed: () => onStartEdit(uid),
                            ),
                          ),
                        ],
                      ])
                    else ...[
                      TextField(
                        controller:   editAmountCtrl,
                        autofocus:    true,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText:  'New share for ${firstName(name)}',
                          prefixText: '$symbol ',
                          helperText: 'Your own share changes by the difference.',
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(
                          child: AppButton(
                            label: 'Update & ask again', icon: Icons.send_rounded, height: 46,
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

/// Approver's view: your share, and Approve / Reject.
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
    final p        = context.palette;
    final t        = Theme.of(context).textTheme;
    final group    = context.read<GroupController>().activeGroup;
    final symbol   = group?.currencySymbol ?? '৳';
    final myAmount = expense.splits[myUid]?.amount ?? 0;
    final expCtrl  = context.watch<ExpenseController>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          borderColor: p.pending.withValues(alpha: 0.4),
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('YOUR SHARE', style: AppType.overline(p.textMuted)),
                    const SizedBox(height: 6),
                    MoneyText(myAmount, symbol: symbol, size: 28),
                    const SizedBox(height: 4),
                    Text('Approve it and you\'ll owe ${firstName(expense.loggedByName)} this amount.',
                        style: t.bodySmall),
                  ],
                ),
              ),
              IconTile(Icons.fact_check_rounded, color: p.pending, size: 48),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label:     'Reject',
                icon:      Icons.close_rounded,
                outlined:  true,
                color:     p.negative,
                onPressed: expCtrl.isLoading ? null : onReject,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: AppButton(
                label:     'Approve',
                icon:      Icons.check_rounded,
                color:     p.positive,
                isLoading: expCtrl.isLoading,
                onPressed: onApprove,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Shown when you're in the split and have already decided.
class _StatusBanner extends StatelessWidget {
  final String      status;
  final ColorScheme scheme;
  const _StatusBanner({required this.status, required this.scheme});

  @override
  Widget build(BuildContext context) {
    final isApproved = status == AppConstants.statusApproved;
    return InfoBanner(
      isApproved ? 'You approved your share of this expense.' : 'You rejected your share of this expense.',
      icon: isApproved ? Icons.check_circle_rounded : Icons.cancel_rounded,
      tone: isApproved ? ChipTone.positive : ChipTone.negative,
    );
  }
}
