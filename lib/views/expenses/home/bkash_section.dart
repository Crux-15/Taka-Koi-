import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../controllers/group_controller.dart';
import '../../../models/bkash_share.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/app_log.dart';
import '../../../utils/display_helpers.dart';
import '../../../widgets/ui/ui.dart';

/// Another member's bKash number, if they've shared it with you: ask for it,
/// see that you're waiting, or copy it and open bKash.
class BkashSection extends StatefulWidget {
  final BuildContext  homeCtx;
  final String        requesterId;
  final String        requesterName;
  final String        targetId;
  final String        targetName;
  final GroupController groupCtrl;

  const BkashSection({
    super.key,
    required this.homeCtx,
    required this.requesterId,
    required this.requesterName,
    required this.targetId,
    required this.targetName,
    required this.groupCtrl,
  });

  @override
  State<BkashSection> createState() => _BkashSectionState();
}

class _BkashSectionState extends State<BkashSection> {
  // Created once, so typing elsewhere on the screen doesn't re-subscribe.
  late final Stream<BkashShare?> _share = widget.groupCtrl.bkashShareStream(
    widget.groupCtrl.activeGroup?.groupId ?? '', widget.requesterId, widget.targetId,
  );
  bool _asking = false;

  String get _name => firstName(widget.targetName);

  void _toast(String text) =>
      ScaffoldMessenger.of(widget.homeCtx).showSnackBar(SnackBar(content: Text(text), duration: const Duration(seconds: 2)));

  Future<void> _ask() async {
    setState(() => _asking = true);
    final ok = await widget.groupCtrl.requestBkash(
      groupId:       widget.groupCtrl.activeGroup?.groupId ?? '',
      requesterId:   widget.requesterId,
      requesterName: widget.requesterName,
      targetId:      widget.targetId,
      targetName:    widget.targetName,
      groupName:     widget.groupCtrl.activeGroup?.name ?? '',
    );
    if (mounted) setState(() => _asking = false);
    _toast(ok ? 'Asked $_name. You\'ll see the number here once they share it.' : 'Couldn\'t send the request. Try again.');
  }

  Future<void> _openBkash(String number) async {
    HapticFeedback.lightImpact();
    await Clipboard.setData(ClipboardData(text: number));
    const channel = MethodChannel('com.tourtracker.tour_expense_tracker/app_launcher');
    try {
      final launched = await channel.invokeMethod<bool>('launchApp', {'package': 'com.bKash.customerapp'});
      _toast(launched == true ? 'Number copied. Opening bKash…' : 'Number copied. Opening the Play Store…');
    } catch (e, s) {
      logError('open bKash', e, s);
      await launchUrl(
        Uri.parse('https://play.google.com/store/apps/details?id=com.bKash.customerapp'),
        mode: LaunchMode.externalApplication,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;

    return StreamBuilder<BkashShare?>(
      stream: _share,
      builder: (ctx, snap) {
        final share = snap.data;
        // An acceptance from the old app (no number field) counts as not asked.
        final status = (share == null || share.legacy) ? null : share.status;
        final number = share?.number ?? '';

        Widget body;
        if (status == 'accepted' && number.isNotEmpty) {
          body = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Pressable(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  Clipboard.setData(ClipboardData(text: number));
                  _toast('bKash number copied');
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color:        p.surfaceRaised,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('$_name\'s bKash', style: t.bodySmall),
                            const SizedBox(height: 2),
                            Text(number, style: AppType.money(19, color: p.text).copyWith(letterSpacing: 1)),
                          ],
                        ),
                      ),
                      Icon(Icons.copy_rounded, size: 19, color: p.accent),
                      const SizedBox(width: 4),
                      Text('Copy', style: t.labelMedium?.copyWith(color: p.accent, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Pressable(
                onTap: () => _openBkash(number),
                child: Container(
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color:        AppColors.bkashPink.withValues(alpha: p.isDark ? 0.18 : 0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.open_in_new_rounded, size: 17, color: AppColors.bkashPink),
                      SizedBox(width: 8),
                      Text('Copy & open bKash',
                          style: TextStyle(fontFamily: AppType.display, fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.bkashPink)),
                    ],
                  ),
                ),
              ),
            ],
          );
        } else if (status == 'pending') {
          body = InfoBanner('Asked $_name for their bKash number. It shows here once they share it.',
              icon: Icons.schedule_rounded, tone: ChipTone.pending);
        } else {
          body = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                status == 'declined'
                    ? '$_name chose not to share their number. You can ask again, or pay in cash.'
                    : 'Numbers are private. Ask $_name and they decide whether to share it with you.',
                style: t.bodySmall,
              ),
              const SizedBox(height: 10),
              Pressable(
                onTap: _asking ? null : _ask,
                child: Container(
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border:       Border.all(color: p.hairline, width: 1.3),
                  ),
                  child: _asking
                      ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: p.text))
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock_open_rounded, size: 17, color: p.accent),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(status == 'declined' ? 'Ask again' : 'Ask $_name for their number',
                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontFamily: AppType.display, fontWeight: FontWeight.w600, fontSize: 14, color: p.text)),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          );
        }

        return AppCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const IconTile(Icons.account_balance_wallet_rounded, size: 32, radius: 10, color: AppColors.bkashPink),
                  const SizedBox(width: 10),
                  Text('bKash', style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 12),
              body,
            ],
          ),
        );
      },
    );
  }
}
