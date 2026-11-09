import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/group_controller.dart';
import '../../widgets/common/avatar_widget.dart';
import '../../widgets/common/empty_state_widget.dart';
import '../../widgets/ui/ui.dart';
import 'past_tour_detail_view.dart';

/// Tours that have ended. Open one to see what was spent or to settle up.
class TourHistoryView extends StatefulWidget {
  const TourHistoryView({super.key});

  @override
  State<TourHistoryView> createState() => _TourHistoryViewState();
}

class _TourHistoryViewState extends State<TourHistoryView> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final uid = context.read<AuthController>().user?.uid;
    if (uid != null) await context.read<GroupController>().loadHistory(uid);
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final history = context.watch<GroupController>().history;
    final p       = context.palette;
    final t       = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Past tours'), centerTitle: true),
      body: _loading && history.isEmpty
          ? const SkeletonList(count: 3)
          : history.isEmpty
              ? const EmptyStateWidget(
                  icon:     Icons.history_rounded,
                  title:    'No past tours yet',
                  subtitle: 'When a tour ends, it moves here. You can still settle up from here.',
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding:          const EdgeInsets.fromLTRB(20, 12, 20, 32),
                    itemCount:        history.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) {
                      final g = history[i];
                      final members = g.members.values.toList();
                      return AppCard(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => PastTourDetailView(group: g)),
                        ),
                        child: Row(
                          children: [
                            const IconTile(Icons.luggage_rounded, size: 48),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(g.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                                      style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 3),
                                  Text(
                                    g.inactivatedAt != null
                                        ? 'Ended ${DateFormat('d MMM y').format(g.inactivatedAt!)}'
                                        : DateFormat('d MMM y').format(g.createdAt),
                                    style: t.bodySmall,
                                  ),
                                  const SizedBox(height: 8),
                                  AvatarStack(
                                    names:     members.map((m) => m.name).toList(),
                                    imageUrls: members.map((m) => m.avatarUrl).toList(),
                                    size:      22,
                                    ringColor: p.surface,
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right_rounded, color: p.textFaint),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
