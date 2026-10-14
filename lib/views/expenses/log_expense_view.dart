import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  double get _totalAmount => double.tryParse(_amountCtrl.text.trim()) ?? 0.0;

  double get _othersAllocated {
    final selected = _selectedMembers.entries.where((e) => e.value).map((e) => e.key).toList();
    double sum = 0.0;
    for (final uid in selected) {
      final amt = double.tryParse(_customAmounts[uid]?.text.trim() ?? '') ?? 0.0;
      sum += amt;
    }
    return sum;
  }

  double get _remainingBalance {
    final total = _totalAmount;
    final allocated = _othersAllocated;
    return total - allocated;
  }

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

    final total = _totalAmount;
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

    // Custom Split Validation Guard
    if (_splitType == AppConstants.splitCustom) {
      final total = _totalAmount;
      final othersTotal = _othersAllocated;

      if (_loggerIncluded) {
        if (othersTotal > total + 0.01) {
          final over = (othersTotal - total).toStringAsFixed(2);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Custom shares exceed total by ${group.currencySymbol}$over. Please adjust amounts.'),
              backgroundColor: AppColors.error,
            ),
          );
          return;
        }
      } else {
        final diff = (othersTotal - total).abs();
        if (diff > 0.01) {
          final msg = othersTotal > total
              ? 'Custom shares exceed total by ${group.currencySymbol}${(othersTotal - total).toStringAsFixed(2)}.'
              : 'Please allocate remaining ${group.currencySymbol}${(total - othersTotal).toStringAsFixed(2)} to members.';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), backgroundColor: AppColors.error),
          );
          return;
        }
      }
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

            // Live Custom Split Tracker (shown when Custom split is active)
            if (_splitType == AppConstants.splitCustom) ...[
              _LiveSplitTracker(
                total:           _totalAmount,
                othersAllocated: _othersAllocated,
                remaining:       _remainingBalance,
                loggerIncluded:  _loggerIncluded,
                userName:        user.name,
                symbol:          group.currencySymbol,
              ),
              const SizedBox(height: 12),
            ],

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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppTextField(
                          label:        '${m.name}\'s share',
                          hint:         '0.00',
                          controller:   _customAmounts[m.userId]!,
                          prefixIcon:   Icons.person_rounded,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged:    (_) => setState(() {}),
                        ),
                        if (_remainingBalance > 0.01 &&
                            (double.tryParse(_customAmounts[m.userId]!.text.trim()) ?? 0.0) == 0.0)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () {
                                HapticFeedback.lightImpact();
                                _customAmounts[m.userId]!.text = _remainingBalance.toStringAsFixed(2);
                                setState(() {});
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: scheme.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: scheme.primary.withOpacity(0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.bolt_rounded, size: 14, color: scheme.primary),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Auto-fill remaining: ${group.currencySymbol}${_remainingBalance.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: scheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.outlineDark : AppColors.outlineLight,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.pie_chart_rounded, size: 16, color: scheme.primary),
              const SizedBox(width: 8),
              Text(
                'Split Preview (${splits.length} ${splits.length == 1 ? "member" : "members"})',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: scheme.primary,
                  fontSize: 13,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...splits.entries.map((e) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  e.value.name,
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '$symbol${e.value.amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}

/// Live Remaining Balance Tracker during custom splits.
/// Provides real-time calculation, prevents mental math, and enforces split balance.
class _LiveSplitTracker extends StatelessWidget {
  final double total;
  final double othersAllocated;
  final double remaining;
  final bool   loggerIncluded;
  final String userName;
  final String symbol;

  const _LiveSplitTracker({
    required this.total,
    required this.othersAllocated,
    required this.remaining,
    required this.loggerIncluded,
    required this.userName,
    required this.symbol,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    if (total <= 0) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariantLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDark ? AppColors.outlineDark : AppColors.outlineLight),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded, size: 18, color: isDark ? AppColors.onSurfaceVariantDark : AppColors.poshGold),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Enter total amount above to track live split balance.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: isDark ? AppColors.onSurfaceVariantDark : AppColors.onSurfaceVariantLight,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final isOverAllocated = remaining < -0.01;
    final isPerfectZero   = remaining.abs() <= 0.01;

    // Status styling
    Color statusBg;
    Color statusBorder;
    Color statusColor;
    String statusTitle;
    IconData statusIcon;

    if (isOverAllocated) {
      statusBg     = isDark ? const Color(0x28FF4757) : const Color(0xFFFFF0F0);
      statusBorder = isDark ? const Color(0x55FF4757) : const Color(0xFFFFCDD2);
      statusColor  = isDark ? const Color(0xFFFF6B78) : const Color(0xFFD32F2F);
      statusTitle  = 'Over-allocated by $symbol${(-remaining).toStringAsFixed(2)}';
      statusIcon   = Icons.warning_amber_rounded;
    } else if (loggerIncluded) {
      // In logger included mode: remaining is user's auto-balanced share
      if (isPerfectZero) {
        statusBg     = isDark ? const Color(0x2800C896) : const Color(0xFFE8F8F3);
        statusBorder = isDark ? const Color(0x5500C896) : const Color(0xFFA7E8D4);
        statusColor  = isDark ? AppColors.success : const Color(0xFF007A5A);
        statusTitle  = 'All $symbol${total.toStringAsFixed(2)} allocated to others (Your share: $symbol 0.00)';
        statusIcon   = Icons.check_circle_rounded;
      } else {
        statusBg     = isDark ? const Color(0x28FFD700) : const Color(0xFFFDF8EE);
        statusBorder = isDark ? const Color(0x55FFD700) : const Color(0xFFEADBBE);
        statusColor  = isDark ? AppColors.primaryLight : AppColors.poshGold;
        statusTitle  = 'Your Share: $symbol${remaining.toStringAsFixed(2)} (auto-balanced)';
        statusIcon   = Icons.balance_rounded;
      }
    } else {
      // In logger NOT included mode: all must be allocated to others
      if (isPerfectZero) {
        statusBg     = isDark ? const Color(0x2800C896) : const Color(0xFFE8F8F3);
        statusBorder = isDark ? const Color(0x5500C896) : const Color(0xFFA7E8D4);
        statusColor  = isDark ? AppColors.success : const Color(0xFF007A5A);
        statusTitle  = '100% Split Balanced ($symbol${total.toStringAsFixed(2)})';
        statusIcon   = Icons.check_circle_rounded;
      } else {
        statusBg     = isDark ? const Color(0x28FF9100) : const Color(0xFFFFF8EC);
        statusBorder = isDark ? const Color(0x55FF9100) : const Color(0xFFFFE0B2);
        statusColor  = isDark ? AppColors.warning : const Color(0xFFC76A00);
        statusTitle  = '$symbol${remaining.toStringAsFixed(2)} remaining to assign to members';
        statusIcon   = Icons.timelapse_rounded;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Status Badge
          Row(
            children: [
              Icon(statusIcon, size: 18, color: statusColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  statusTitle,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, thickness: 0.8, color: statusBorder.withOpacity(0.5)),
          const SizedBox(height: 12),

          // 3-Metric Summary Row
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: 'Total',
                  value: '$symbol${total.toStringAsFixed(2)}',
                  textColor: scheme.onSurface,
                ),
              ),
              Container(width: 1, height: 32, color: statusBorder.withOpacity(0.5)),
              Expanded(
                child: _MetricTile(
                  label: 'Others',
                  value: '$symbol${othersAllocated.toStringAsFixed(2)}',
                  textColor: scheme.onSurface,
                ),
              ),
              Container(width: 1, height: 32, color: statusBorder.withOpacity(0.5)),
              Expanded(
                child: _MetricTile(
                  label: loggerIncluded ? 'Your Share' : 'Remaining',
                  value: '$symbol${(isOverAllocated ? 0.0 : remaining).toStringAsFixed(2)}',
                  textColor: statusColor,
                  isBold: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final Color textColor;
  final bool isBold;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.textColor,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isBold ? FontWeight.w800 : FontWeight.w700,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
