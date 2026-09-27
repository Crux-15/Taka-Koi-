import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../controllers/group_controller.dart';
import '../../models/group_model.dart';
import '../../utils/app_colors.dart';
import '../../widgets/common/empty_state_widget.dart';
import 'past_tour_detail_view.dart';

/// Read-only list of completed tour groups.
/// Tapping a card opens PastTourDetailView with full expenses + debts.
class TourHistoryView extends StatelessWidget {
  const TourHistoryView({super.key});

  @override
  Widget build(BuildContext context) {
    final history = context.watch<GroupController>().history;
    final fmt     = DateFormat('MMM d, y');

    return Scaffold(
      appBar: AppBar(title: const Text('Tour History')),
      body: history.isEmpty
          ? const EmptyStateWidget(
              icon:     Icons.history_rounded,
              title:    'No Past Tours',
              subtitle: 'Completed tours will appear here.',
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: history.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final g = history[i];
                return _TourCard(
                  group: g,
                  subtitle: '${g.members.length} members â€¢ ${g.currency}',
                  date: g.inactivatedAt != null ? 'Ended ${fmt.format(g.inactivatedAt!)}' : fmt.format(g.createdAt),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => PastTourDetailView(group: g)),
                  ),
                );
              },
            ),
    );
  }
}

class _TourCard extends StatelessWidget {
  final GroupModel   group;
  final String       subtitle;
  final String       date;
  final VoidCallback onTap;
  const _TourCard({required this.group, required this.subtitle, required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.travel_explore_rounded, color: AppColors.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(group.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
                  Text(date,    style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
          ]),
        ),
      ),
    );
  }
}
