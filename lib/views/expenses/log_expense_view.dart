import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/expense_controller.dart';
import '../../controllers/group_controller.dart';
import '../../models/expense_model.dart';
import '../../models/group_model.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_constants.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/loading_widget.dart';

/// Screen for logging a new expense with GPS capture and split configuration.
class LogExpenseView extends StatefulWidget {
  const LogExpenseView({super.key});
  @override
  State<LogExpenseView> createState() => _LogExpenseViewState();
}

class _LogExpenseViewState extends State<LogExpenseView> {
  final _formKey     = GlobalKey<FormState>();
  final _amountCtrl  = TextEditingController();
  final _commentCtrl = TextEditingController();

  String _splitType = AppConstants.splitEqual;
  bool   _loggerIncluded = true;
  final Map<String, bool>   _selectedMembers = {};
  final Map<String, TextEditingController> _customAmounts = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ExpenseController>().captureGps();
    });
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _commentCtrl.dispose();
    for (final c in _customAmounts.values) { c.dispose(); }
    super.dispose();
  }

  List<GroupMember> _getOtherMembers(GroupModel group, String myUid) {
    return group.members.values.where((m) => m.userId != myUid).toList();
  }

  Map<String, SplitEntry> _buildSplits(GroupModel group, String myUid) {
    final selected = _selectedMembers.entries.where((e) => e.value).map((e) => e.key).toList();
    final members  = <String>[];
    if (_loggerIncluded) members.add(myUid);
    members.addAll(selected);

    if (members.isEmpty) return {};

    final total = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    final splits = <String, SplitEntry>{};

    if (_splitType == AppConstants.splitEqual) {
      final perPerson = members.isEmpty ? 0.0 : total / members.length;
      for (final uid in members) {
        final name = uid == myUid ? context.read<AuthController>().user!.name : group.members[uid]!.name;
        splits[uid] = SplitEntry(userId: uid, name: name, amount: perPerson);
      }
    } else {
      // Custom split — each selected member has an explicit amount
      double othersTotal = 0;
      for (final uid in selected) {
        final ctrl = _customAmounts[uid];
        final amt  = double.tryParse(ctrl?.text.trim() ?? '') ?? 0;
        splits[uid] = SplitEntry(userId: uid, name: group.members[uid]!.name, amount: amt);
        othersTotal += amt;
      }
      // Self gets the remainder: total - others
      if (_loggerIncluded) {
        final user      = context.read<AuthController>().user!;
        final selfShare = (total - othersTotal).clamp(0.0, double.infinity);
        splits[myUid]   = SplitEntry(userId: myUid, name: user.name, amount: selfShare);
      }
    }
    return splits;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth       = context.read<AuthController>();
    final groupCtrl  = context.read<GroupController>();
    final expCtrl    = context.read<ExpenseController>();
    final group      = groupCtrl.activeGroup!;
    final user       = auth.user!;

    final splits = _buildSplits(group, user.uid);
    if (splits.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one member to split with.'), backgroundColor: AppColors.error),
      );
      return;
    }

    final ok = await expCtrl.logExpense(
      groupId:       group.groupId,
      loggedBy:      user.uid,
      loggedByName:  user.name,
      amount:        double.tryParse(_amountCtrl.text.trim()) ?? 0,
      comment:       _commentCtrl.text.trim(),
      splitType:     _splitType,
      splits:        splits,
      loggerIncluded: _loggerIncluded,
      group:         group,
    );
    if (!mounted) return;
    if (ok) {
      context.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Expense submitted! Split members will be notified for approval.'),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(expCtrl.errorMessage ?? 'Failed to log expense. Please try again.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth      = context.watch<AuthController>();
    final expCtrl   = context.watch<ExpenseController>();
    final groupCtrl = context.watch<GroupController>();
    final group     = groupCtrl.activeGroup;
    final user      = auth.user!;
    final scheme    = Theme.of(context).colorScheme;

    if (group == null) return const Scaffold(body: Center(child: AppLoader()));

    final others = _getOtherMembers(group, user.uid);
    for (final m in others) {
      _selectedMembers.putIfAbsent(m.userId, () => false);
      _customAmounts.putIfAbsent(m.userId, () => TextEditingController());
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Log Expense')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Amount
            AppTextField(
              label:        'Amount',
              hint:         '0.00',
              controller:   _amountCtrl,
              prefixIcon:   Icons.attach_money_rounded,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.next,
              onChanged:    (_) => setState(() {}),
              validator: (v) {
                final val = double.tryParse(v ?? '');
                if (val == null || val <= 0) return 'Enter a valid amount.';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Comment
            AppTextField(
              label:      'Comment',
              hint:       'What was this for?',
              controller: _commentCtrl,
              prefixIcon: Icons.comment_rounded,
              maxLines:   2,
              maxLength:  AppConstants.maxCommentLength,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),

            // GPS Location
            _LocationTile(expCtrl: expCtrl),
            const SizedBox(height: 20),

            // Split Type Toggle
            Text('Split Type', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: AppConstants.splitEqual,  label: Text('Equal'),  icon: Icon(Icons.balance_rounded)),
                ButtonSegment(value: AppConstants.splitCustom, label: Text('Custom'), icon: Icon(Icons.tune_rounded)),
              ],
              selected: {_splitType},
              onSelectionChanged: (s) => setState(() => _splitType = s.first),
            ),
            const SizedBox(height: 20),

            // Include myself toggle — wrapped in Material to satisfy ListTile ink assertion
            Material(
              color: Colors.transparent,
              child: SwitchListTile.adaptive(
                value:    _loggerIncluded,
                onChanged: (v) => setState(() => _loggerIncluded = v),
                title:    const Text('Include myself in split'),
                subtitle: Text('You (${user.name})'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const Divider(),
            const SizedBox(height: 8),

            // Member Selection
            Text('Split With', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            if (others.isEmpty)
              Text('No other members in this group.', style: TextStyle(color: scheme.onSurfaceVariant)),
            ...others.map((m) => Column(
              children: [
                CheckboxListTile(
                  value:     _selectedMembers[m.userId] ?? false,
                  onChanged: (v) => setState(() => _selectedMembers[m.userId] = v!),
                  title:     Text(m.name),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                if (_splitType == AppConstants.splitCustom && (_selectedMembers[m.userId] ?? false))
                  Padding(
                    padding: const EdgeInsets.only(left: 40, bottom: 8),
                    child: AppTextField(
                      label:        '${m.name}\'s share',
                      hint:         '0.00',
                      controller:   _customAmounts[m.userId]!,
                      prefixIcon:   Icons.person_rounded,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged:    (_) => setState(() {}),
                    ),
                  ),
              ],
            )),
            const SizedBox(height: 12),

            // Split Preview
            if (_amountCtrl.text.isNotEmpty && double.tryParse(_amountCtrl.text) != null) ...[
              _SplitPreview(
                splits:  _buildSplits(group, user.uid),
                symbol:  group.currencySymbol,
              ),
              const SizedBox(height: 16),
            ],

            AppButton(
              label:     'Submit for Approval',
              icon:      Icons.send_rounded,
              isLoading: expCtrl.isLoading,
              onPressed: _submit,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _LocationTile extends StatelessWidget {
  final ExpenseController expCtrl;
  const _LocationTile({required this.expCtrl});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.location_on_rounded, color: expCtrl.capturedLocation != null ? AppColors.secondary : scheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: expCtrl.capturingGps
                ? const Text('Capturing location…')
                : expCtrl.capturedLocation != null
                    ? Text(expCtrl.capturedLocation!.displayAddress, style: const TextStyle(fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis)
                    : Text('Location not captured', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
          ),
          if (expCtrl.capturingGps)
            const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
          else
            TextButton(onPressed: expCtrl.captureGps, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _SplitPreview extends StatelessWidget {
  final Map<String, SplitEntry> splits;
  final String symbol;
  const _SplitPreview({required this.splits, required this.symbol});

  @override
  Widget build(BuildContext context) {
    if (splits.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Split Preview', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary, fontSize: 13)),
          const SizedBox(height: 8),
          ...splits.entries.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(e.value.name, style: const TextStyle(fontSize: 13)),
                Text('$symbol${e.value.amount.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
          )),
        ],
      ),
    );
  }
}
