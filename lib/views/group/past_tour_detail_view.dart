import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_controller.dart';
import '../../models/debt_model.dart';
import '../../models/expense_model.dart';
import '../../models/group_model.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_constants.dart';
import '../../widgets/common/avatar_widget.dart';
import '../../widgets/common/empty_state_widget.dart';
import '../../widgets/common/loading_widget.dart';

/// Full read-only view of a completed past tour — expenses, debts, members.
/// No add/edit/join controls, purely historical.
class PastTourDetailView extends StatefulWidget {
  final GroupModel group;
  const PastTourDetailView({super.key, required this.group});

  @override
  State<PastTourDetailView> createState() => _PastTourDetailViewState();
}

class _PastTourDetailViewState extends State<PastTourDetailView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);
  List<ExpenseModel> _expenses = [];
  List<DebtModel>    _debts    = [];
  bool _loading = true;

  final _db = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _loadData() async {
    final gid = widget.group.groupId;
    try {
      // Fetch all expenses (approved only) for this group
      final expSnap = await _db
          .collection(AppConstants.colGroups)
          .doc(gid)
          .collection(AppConstants.colExpenses)
          .where('status', isEqualTo: AppConstants.statusApproved)
          .get();
      final expenses = expSnap.docs
          .map((d) => ExpenseModel.fromDoc(d, groupId: gid))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // Fetch all debts for this group
      final debtSnap = await _db
          .collection(AppConstants.colGroups)
          .doc(gid)
          .collection(AppConstants.colDebts)
          .get();
      final debts = debtSnap.docs
          .map((d) => DebtModel.fromDoc(d, groupId: gid))
          .toList();

      if (!mounted) return;
      setState(() {
        _expenses = expenses;
        _debts    = debts;
        _loading  = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final group  = widget.group;
    final symbol = group.currencySymbol;
    final myUid  = context.read<AuthController>().user?.uid ?? '';
    final fmt    = DateFormat('MMM d, y');

    final totalSpent = _expenses.fold<double>(0, (s, e) => s + e.amount);

    return Scaffold(
      appBar: AppBar(
        title: Text(group.name),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Expenses'),
            Tab(text: 'Debts'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: AppLoader())
          : TabBarView(
              controller: _tabs,
              children: [
                // ── Tab 1: Overview ──────────────────────────────────────────
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Summary card
                      _SummaryCard(
                        name:        group.name,
                        symbol:      symbol,
                        totalSpent:  totalSpent,
                        memberCount: group.members.length,
                        createdAt:   fmt.format(group.createdAt),
                        endedAt:     group.inactivatedAt != null ? fmt.format(group.inactivatedAt!) : '—',
                      ),
                      const SizedBox(height: 20),

                      // Members with their spending
                      Text('Member Spending',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      ...group.members.values.map((m) {
                        final memberTotal = _expenses
                            .where((e) => e.loggedBy == m.userId)
                            .fold<double>(0, (s, e) => s + e.amount);
                        return _MemberSpendRow(
                          member:     m,
                          total:      memberTotal,
                          symbol:     symbol,
                          isMe:       m.userId == myUid,
                        );
                      }),
                    ],
                  ),
                ),

                // ── Tab 2: Expenses (read-only) ──────────────────────────────
                _expenses.isEmpty
                    ? const EmptyStateWidget(
                        icon:     Icons.receipt_long_outlined,
                        title:    'No Expenses',
                        subtitle: 'No approved expenses were recorded in this tour.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _expenses.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final e = _expenses[i];
                          return Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppColors.primary.withOpacity(0.12),
                                child: const Icon(Icons.receipt_rounded, color: AppColors.primary, size: 20),
                              ),
                              title: Text(e.comment.isNotEmpty ? e.comment : 'Expense',
                                  style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text(
                                '${e.loggedByName} • ${fmt.format(e.createdAt)}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              trailing: Text(
                                '$symbol${e.amount.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color:      AppColors.primary,
                                  fontSize:   15,
                                ),
                              ),
                            ),
                          );
                        },
                      ),

                // ── Tab 3: Debts (read-only) ─────────────────────────────────
                _debts.isEmpty
                    ? const EmptyStateWidget(
                        icon:     Icons.account_balance_wallet_outlined,
                        title:    'No Debts',
                        subtitle: 'All debts were settled or none were created.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _debts.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final d = _debts[i];
                          final isSettled = d.status == AppConstants.statusSettled;
                          final isMe      = d.fromUserId == myUid;
                          return Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isSettled
                                    ? AppColors.success.withOpacity(0.12)
                                    : AppColors.error.withOpacity(0.12),
                                child: Icon(
                                  isSettled ? Icons.check_rounded : Icons.arrow_forward_rounded,
                                  color: isSettled ? AppColors.success : AppColors.error,
                                  size: 18,
                                ),
                              ),
                              title: Text(
                                '${d.fromUserName} → ${d.toUserName}',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                              subtitle: Text(
                                isSettled ? 'Settled' : 'Outstanding: $symbol${d.remainingAmount.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color:    isSettled ? AppColors.success : AppColors.error,
                                ),
                              ),
                              trailing: Text(
                                '$symbol${d.originalAmount.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize:   14,
                                  color:      isMe ? AppColors.error : AppColors.success,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ],
            ),
    );
  }
}

// ── Widgets ──────────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final String name, symbol, createdAt, endedAt;
  final double totalSpent;
  final int    memberCount;
  const _SummaryCard({
    required this.name, required this.symbol, required this.totalSpent,
    required this.memberCount, required this.createdAt, required this.endedAt,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient:     AppColors.heroGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          Row(children: [
            _StatChip(label: 'Total Spent', value: '$symbol${totalSpent.toStringAsFixed(2)}'),
            const SizedBox(width: 12),
            _StatChip(label: 'Members', value: '$memberCount'),
          ]),
          const SizedBox(height: 12),
          Text('Created: $createdAt', style: const TextStyle(color: Colors.white70, fontSize: 12)),
          Text('Ended: $endedAt',    style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label, value;
  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color:        Colors.white.withOpacity(0.15),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(children: [
      Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
    ]),
  );
}

class _MemberSpendRow extends StatelessWidget {
  final GroupMember member;
  final double      total;
  final String      symbol;
  final bool        isMe;
  const _MemberSpendRow({required this.member, required this.total, required this.symbol, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(children: [
          AvatarWidget(imageUrl: member.avatarUrl, name: member.name, size: 38),
          const SizedBox(width: 12),
          Expanded(child: Text(
            '${member.name}${isMe ? " (You)" : ""}',
            style: const TextStyle(fontWeight: FontWeight.w500),
          )),
          Text(
            '$symbol${total.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize:   15,
              color:      scheme.primary,
            ),
          ),
        ]),
      ),
    );
  }
}
