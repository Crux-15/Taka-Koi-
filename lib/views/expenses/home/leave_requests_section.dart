import 'package:flutter/material.dart';
import '../../../controllers/group_controller.dart';
import '../../../widgets/common/avatar_widget.dart';
import '../../../widgets/ui/ui.dart';

/// Pending leave requests, with approve / reject (admins only).
class LeaveRequestsSection extends StatefulWidget {
  final GroupController groupCtrl;
  const LeaveRequestsSection({super.key, required this.groupCtrl});

  @override
  State<LeaveRequestsSection> createState() => _LeaveRequestsSectionState();
}

class _LeaveRequestsSectionState extends State<LeaveRequestsSection> {
  // Created once: a new stream on every rebuild would re-subscribe and flicker.
  late final Stream<List<Map<String, dynamic>>> _requests = widget.groupCtrl.leaveRequestsStream();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _requests,
      builder: (ctx, snap) {
        final requests = snap.data ?? const [];
        if (requests.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader('Leave requests'),
              for (final req in requests)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AppCard(
                    padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                    child: Row(
                      children: [
                        AvatarWidget(name: req['memberName'] as String? ?? 'Member', uid: req['memberId'] as String?, size: 38),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(req['memberName'] as String? ?? 'Member',
                                  style: t.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                              Text('Wants to leave the tour', style: t.bodySmall),
                            ],
                          ),
                        ),
                        _ActionPill(
                          label: 'Reject',
                          color: p.textMuted,
                          onTap: () => _decide(ctx, req, approve: false),
                        ),
                        const SizedBox(width: 6),
                        _ActionPill(
                          label:  'Approve',
                          color:  p.positive,
                          filled: true,
                          onTap:  () => _decide(ctx, req, approve: true),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _decide(BuildContext ctx, Map<String, dynamic> req, {required bool approve}) async {
    final memberId   = req['memberId'] as String? ?? '';
    final memberName = req['memberName'] as String? ?? 'Member';
    final messenger  = ScaffoldMessenger.of(ctx);
    final ok = approve
        ? await widget.groupCtrl.approveLeave(memberId: memberId, memberName: memberName)
        : await widget.groupCtrl.rejectLeave(memberId: memberId, memberName: memberName);
    messenger.showSnackBar(SnackBar(
      content: Text(!ok
          ? (widget.groupCtrl.errorMessage ?? 'Something went wrong. Try again.')
          : approve
              ? '$memberName has left the tour.'
              : '$memberName\'s request was declined.'),
    ));
  }
}

class _ActionPill extends StatelessWidget {
  final String label;
  final Color color;
  final bool filled;
  final VoidCallback onTap;
  const _ActionPill({required this.label, required this.color, required this.onTap, this.filled = false});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color:        filled ? p.soft(color) : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
          border:       filled ? null : Border.all(color: p.hairline),
        ),
        child: Text(label,
            style: TextStyle(fontFamily: AppType.display, fontSize: 12.5, fontWeight: FontWeight.w600, color: color)),
      ),
    );
  }
}
