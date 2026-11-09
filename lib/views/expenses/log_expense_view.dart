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
import '../../utils/money.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/loading_widget.dart';
import '../../utils/split_calculator.dart';
import '../../utils/display_helpers.dart';
import '../../widgets/common/avatar_widget.dart';
import '../../widgets/ui/ui.dart';

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

  // All split math is done in whole cents so shares always add up exactly.
  int get _totalCents => Money.parseCents(_amountCtrl.text) ?? 0;

  /// Cents typed into a selected member's custom-share field (0 if empty).
  int _customCents(String uid) => Money.parseCents(_customAmounts[uid]?.text) ?? 0;

  int get _othersAllocatedCents => _selectedMembers.entries
      .where((e) => e.value)
      .fold<int>(0, (sum, e) => sum + _customCents(e.key));

  double get _totalAmount      => Money.fromCents(_totalCents);
  double get _othersAllocated  => Money.fromCents(_othersAllocatedCents);
  double get _remainingBalance => Money.fromCents(_totalCents - _othersAllocatedCents);

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
    return SplitCalculator.build(
      splitType:      _splitType,
      totalCents:     _totalCents,
      loggerId:       myUid,
      loggerName:     context.read<AuthController>().user!.name,
      loggerIncluded: _loggerIncluded,
      selected:       selected,
      names:          {for (final m in group.members.values) m.userId: m.name},
      customCents:    {for (final uid in selected) uid: _customCents(uid)},
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth       = context.read<AuthController>();
    final groupCtrl  = context.read<GroupController>();
    final expCtrl    = context.read<ExpenseController>();
    final group      = groupCtrl.activeGroup!;
    final user       = auth.user!;

    final splits = _buildSplits(group, user.uid);
    // Compared in whole cents, no tolerance.
    final error = SplitCalculator.validate(
      splitType:      _splitType,
      totalCents:     _totalCents,
      loggerId:       user.uid,
      loggerIncluded: _loggerIncluded,
      splits:         splits,
      symbol:         group.currencySymbol,
    );
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppColors.error),
      );
      return;
    }

    final ok = await expCtrl.logExpense(
      groupId:       group.groupId,
      loggedBy:      user.uid,
      loggedByName:  user.name,
      amount:        Money.fromCents(_totalCents),
      comment:       _commentCtrl.text.trim(),
      splitType:     _splitType,
      splits:        splits,
      loggerIncluded: _loggerIncluded,
      group:         group,
    );
    if (!mounted) return;
    if (ok) {
      final messenger = ScaffoldMessenger.of(context);
      context.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(expCtrl.savedOffline
              ? 'Saved on this phone. It will sync and notify the split members once you\'re back online.'
              : 'Expense submitted! Split members will be notified for approval.'),
          backgroundColor: expCtrl.savedOffline ? AppColors.warning : AppColors.success,
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

    if (group == null) return const Scaffold(body: Center(child: AppLoader()));

    final others = _getOtherMembers(group, user.uid);
    for (final m in others) {
      _selectedMembers.putIfAbsent(m.userId, () => false);
      _customAmounts.putIfAbsent(m.userId, () => TextEditingController());
    }

    final p        = context.palette;
    final t        = Theme.of(context).textTheme;
    final symbol   = group.currencySymbol;
    final preview  = _totalCents > 0 ? _buildSplits(group, user.uid) : const <String, SplitEntry>{};
    final people   = preview.length;
    final selected = _selectedMembers.values.where((v) => v).length + (_loggerIncluded ? 1 : 0);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Cancel',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('New expense'),
        centerTitle: true,
      ),
      bottomNavigationBar: _SubmitBar(
        summary: _totalCents <= 0
            ? 'Enter an amount to see the split'
            : selected == 0
                ? 'Choose who\'s in'
                : _splitType == AppConstants.splitEqual
                    ? '$people ${people == 1 ? 'person' : 'people'} · about ${Money.displayCompact(Money.fromCents(_totalCents ~/ (people == 0 ? 1 : people)), symbol)} each'
                    : 'Custom split · ${Money.displayCompact(_remainingBalance < 0 ? 0 : _remainingBalance, symbol)} left to assign',
        isLoading: expCtrl.isLoading,
        onSubmit:  _submit,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            // ── Amount ─────────────────────────────────────────────────────
            AppCard(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
              child: Column(
                children: [
                  Text('TOTAL AMOUNT', style: AppType.overline(p.textMuted)),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(symbol, style: AppType.money(30, color: p.textMuted)),
                      const SizedBox(width: 6),
                      IntrinsicWidth(
                        child: TextFormField(
                          controller:   _amountCtrl,
                          autofocus:    true,
                          textAlign:    TextAlign.center,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                          style:        AppType.money(46, color: p.text),
                          cursorColor:  p.accent,
                          onChanged:    (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText:       '0',
                            hintStyle:      AppType.money(46, color: p.textFaint),
                            filled:         false,
                            border:         InputBorder.none,
                            enabledBorder:  InputBorder.none,
                            focusedBorder:  InputBorder.none,
                            errorBorder:    InputBorder.none,
                            focusedErrorBorder: InputBorder.none,
                            isDense:        true,
                            contentPadding: EdgeInsets.zero,
                            constraints:    const BoxConstraints(minWidth: 60),
                          ),
                          validator: (v) {
                            final cents = Money.parseCents(v);
                            if (cents == null || cents <= 0) return 'Enter an amount';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Divider(height: 1, color: p.hairline),
                  const SizedBox(height: 4),
                  TextFormField(
                    controller: _commentCtrl,
                    maxLength:  AppConstants.maxCommentLength,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.done,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText:   'What was it for?',
                      filled:     false,
                      border:     InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      counterText: '',
                      prefixIcon: Icon(expenseIcon(_commentCtrl.text), size: 20, color: p.accent),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final s in const ['Food', 'Transport', 'Hotel', 'Tickets', 'Snacks', 'Activity', 'Shopping'])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Pressable(
                        onTap: () => setState(() {
                          _commentCtrl.text = s;
                          _commentCtrl.selection = TextSelection.collapsed(offset: s.length);
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color:        _commentCtrl.text == s ? p.soft(p.accent) : p.surface,
                            borderRadius: BorderRadius.circular(100),
                            border:       Border.all(color: _commentCtrl.text == s ? p.accent.withValues(alpha: 0.4) : p.hairline),
                          ),
                          child: Row(
                            children: [
                              Icon(expenseIcon(s), size: 15, color: p.accent),
                              const SizedBox(width: 6),
                              Text(s, style: t.labelMedium?.copyWith(color: p.text, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _LocationTile(expCtrl: expCtrl),

            // ── Split ──────────────────────────────────────────────────────
            const SizedBox(height: 26),
            const SectionHeader('How to split'),
            _SplitTypeToggle(
              value:     _splitType,
              onChanged: (v) => setState(() => _splitType = v),
            ),
            if (_splitType == AppConstants.splitCustom) ...[
              const SizedBox(height: 12),
              _LiveSplitTracker(
                total:           _totalAmount,
                othersAllocated: _othersAllocated,
                remaining:       _remainingBalance,
                loggerIncluded:  _loggerIncluded,
                userName:        user.name,
                symbol:          symbol,
              ),
            ],

            const SizedBox(height: 26),
            SectionHeader('Who\'s in?',
                trailing: Text('$selected selected', style: t.bodySmall)),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Column(
                children: [
                  _MemberPick(
                    name:     'You',
                    subtitle: _splitType == AppConstants.splitCustom ? 'You pay whatever is left' : user.name,
                    avatarName: user.name,
                    avatarUrl:  user.avatarUrl,
                    selected: _loggerIncluded,
                    share:    preview[user.uid]?.amount,
                    symbol:   symbol,
                    onTap:    () => setState(() => _loggerIncluded = !_loggerIncluded),
                  ),
                  for (final m in others) ...[
                    Divider(height: 1, color: p.hairline),
                    _MemberPick(
                      name:       m.name,
                      avatarName: m.name,
                      avatarUrl:  m.avatarUrl,
                      selected:   _selectedMembers[m.userId] ?? false,
                      share:      _splitType == AppConstants.splitEqual ? preview[m.userId]?.amount : null,
                      symbol:     symbol,
                      onTap: () => setState(() => _selectedMembers[m.userId] = !(_selectedMembers[m.userId] ?? false)),
                    ),
                    if (_splitType == AppConstants.splitCustom && (_selectedMembers[m.userId] ?? false))
                      Padding(
                        padding: const EdgeInsets.fromLTRB(52, 0, 0, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppTextField(
                              label:        '${firstName(m.name)}\'s share',
                              hint:         '0',
                              controller:   _customAmounts[m.userId]!,
                              prefixIcon:   Icons.payments_outlined,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              onChanged:    (_) => setState(() {}),
                            ),
                            if (_remainingBalance > 0.01 && _customCents(m.userId) == 0)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Pressable(
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    _customAmounts[m.userId]!.text = _remainingBalance.toStringAsFixed(2);
                                    setState(() {});
                                  },
                                  child: StatusChip(
                                    'Use what\'s left: ${Money.displayCompact(_remainingBalance, symbol)}',
                                    tone: ChipTone.accent,
                                    icon: Icons.bolt_rounded,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                  if (others.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Text('Nobody else is in this tour yet. Invite people from Home.', style: t.bodySmall),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            InfoBanner(
              _splitType == AppConstants.splitEqual
                  ? 'Everyone in the split approves their own share before it counts as a debt.'
                  : 'Set each person\'s share. Everyone approves theirs before it counts.',
              icon: Icons.verified_user_rounded,
              tone: ChipTone.accent,
            ),
          ],
        ),
      ),
    );
  }
}

/// Equal / Custom segmented toggle.
class _SplitTypeToggle extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _SplitTypeToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    Widget seg(String v, IconData icon, String label, String hint) {
      final on = value == v;
      return Expanded(
        child: Pressable(
          onTap: () => onChanged(v),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            decoration: BoxDecoration(
              color:        on ? (p.isDark ? p.surfaceSunken : p.surface) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              boxShadow:    on && !p.isDark ? p.cardShadow : null,
            ),
            child: Row(
              children: [
                Icon(icon, size: 19, color: on ? p.accent : p.textFaint),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: TextStyle(fontFamily: AppType.display, fontWeight: FontWeight.w600, fontSize: 14, color: on ? p.text : p.textMuted)),
                      Text(hint, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11.5)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color:        p.surfaceRaised,
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: p.hairline),
      ),
      child: Row(
        children: [
          seg(AppConstants.splitEqual, Icons.balance_rounded, 'Equally', 'Same for everyone'),
          seg(AppConstants.splitCustom, Icons.tune_rounded, 'Custom', 'You set the amounts'),
        ],
      ),
    );
  }
}

/// A selectable member row with their share.
class _MemberPick extends StatelessWidget {
  final String name;
  final String? subtitle;
  final String avatarName;
  final String? avatarUrl;
  final bool selected;
  final double? share;
  final String symbol;
  final VoidCallback onTap;

  const _MemberPick({
    required this.name,
    required this.avatarName,
    required this.selected,
    required this.symbol,
    required this.onTap,
    this.subtitle,
    this.avatarUrl,
    this.share,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    return Pressable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: selected ? 1 : 0.45,
              child: AvatarWidget(name: avatarName, imageUrl: avatarUrl, size: 40),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: selected ? p.text : p.textMuted)),
                  if (subtitle != null) Text(subtitle!, style: t.bodySmall),
                ],
              ),
            ),
            if (selected && share != null) ...[
              MoneyText(share!, symbol: symbol, size: 14.5, compact: true, color: p.textMuted),
              const SizedBox(width: 12),
            ],
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 26, height: 26,
              decoration: BoxDecoration(
                shape:  BoxShape.circle,
                color:  selected ? p.accent : Colors.transparent,
                border: Border.all(color: selected ? p.accent : p.textFaint, width: 1.6),
              ),
              child: selected ? Icon(Icons.check_rounded, size: 17, color: p.onAccent) : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// Sticky bottom bar: what the split comes to, and Submit.
class _SubmitBar extends StatelessWidget {
  final String summary;
  final bool isLoading;
  final VoidCallback onSubmit;
  const _SubmitBar({required this.summary, required this.isLoading, required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      decoration: BoxDecoration(
        color:  p.background,
        border: Border(top: BorderSide(color: p.hairline)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(summary, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
              const SizedBox(height: 10),
              AppButton(
                label:     'Send for approval',
                icon:      Icons.send_rounded,
                isLoading: isLoading,
                onPressed: onSubmit,
              ),
            ],
          ),
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
    final p    = context.palette;
    final t    = Theme.of(context).textTheme;
    final loc  = expCtrl.capturedLocation;
    final busy = expCtrl.capturingGps;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
      decoration: BoxDecoration(
        color:        p.surface,
        borderRadius: BorderRadius.circular(100),
        border:       Border.all(color: p.hairline),
      ),
      child: Row(
        children: [
          Icon(Icons.place_rounded, size: 18, color: loc != null ? p.accent : p.textFaint),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              busy ? 'Finding where you are…' : loc?.displayAddress ?? 'No location attached',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.bodySmall?.copyWith(color: loc != null ? p.text : p.textMuted),
            ),
          ),
          if (busy)
            const Padding(
              padding: EdgeInsets.all(10),
              child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            TextButton(
              onPressed: expCtrl.captureGps,
              style: TextButton.styleFrom(minimumSize: const Size(0, 34), padding: const EdgeInsets.symmetric(horizontal: 12)),
              child: Text(loc == null ? 'Add' : 'Update'),
            ),
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
      statusBg     = isDark ? AppColors.errorBgDark : AppColors.errorBgLight;
      statusBorder = isDark ? AppColors.errorBorderDark : AppColors.errorBorderLight;
      statusColor  = isDark ? AppColors.errorTextDark : AppColors.errorTextLight;
      statusTitle  = 'Over-allocated by ${Money.display((-remaining), symbol)}';
      statusIcon   = Icons.warning_amber_rounded;
    } else if (loggerIncluded) {
      // In logger included mode: remaining is user's auto-balanced share
      if (isPerfectZero) {
        statusBg     = isDark ? AppColors.successBgDark : AppColors.successBgLight;
        statusBorder = isDark ? AppColors.successBorderDark : AppColors.successBorderLight;
        statusColor  = isDark ? AppColors.success : AppColors.successTextLight;
        statusTitle  = 'All ${Money.display(total, symbol)} allocated to others (Your share: $symbol 0.00)';
        statusIcon   = Icons.check_circle_rounded;
      } else {
        statusBg     = isDark ? AppColors.goldBgDark : AppColors.goldBgLight;
        statusBorder = isDark ? AppColors.goldBorderDark : AppColors.goldMist;
        statusColor  = isDark ? AppColors.primaryLight : AppColors.poshGold;
        statusTitle  = 'Your Share: ${Money.display(remaining, symbol)} (auto-balanced)';
        statusIcon   = Icons.balance_rounded;
      }
    } else {
      // In logger NOT included mode: all must be allocated to others
      if (isPerfectZero) {
        statusBg     = isDark ? AppColors.successBgDark : AppColors.successBgLight;
        statusBorder = isDark ? AppColors.successBorderDark : AppColors.successBorderLight;
        statusColor  = isDark ? AppColors.success : AppColors.successTextLight;
        statusTitle  = '100% Split Balanced (${Money.display(total, symbol)})';
        statusIcon   = Icons.check_circle_rounded;
      } else {
        statusBg     = isDark ? AppColors.warningBgDark : AppColors.warningBgLight;
        statusBorder = isDark ? AppColors.warningBorderDark : AppColors.warningBorderLight;
        statusColor  = isDark ? AppColors.warning : AppColors.amberBurnt;
        statusTitle  = '${Money.display(remaining, symbol)} remaining to assign to members';
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
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
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
          Divider(height: 1, thickness: 0.8, color: statusBorder.withValues(alpha: 0.5)),
          const SizedBox(height: 12),

          // 3-Metric Summary Row
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: 'Total',
                  value: Money.display(total, symbol),
                  textColor: scheme.onSurface,
                ),
              ),
              Container(width: 1, height: 32, color: statusBorder.withValues(alpha: 0.5)),
              Expanded(
                child: _MetricTile(
                  label: 'Others',
                  value: Money.display(othersAllocated, symbol),
                  textColor: scheme.onSurface,
                ),
              ),
              Container(width: 1, height: 32, color: statusBorder.withValues(alpha: 0.5)),
              Expanded(
                child: _MetricTile(
                  label: loggerIncluded ? 'Your Share' : 'Remaining',
                  value: Money.display((isOverAllocated ? 0.0 : remaining), symbol),
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
