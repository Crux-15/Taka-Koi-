import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/app_log.dart';
import '../../../models/group_model.dart';

/// Bottom sheet for sharing the join code (WhatsApp, Messenger, ...).
void showInviteSheet(BuildContext context, GroupModel group) {
  final scheme = Theme.of(context).colorScheme;
  final code = group.groupCode;
  final tourName = group.name;
  final inviteText = '$code\n\n'
      'Join our tour "$tourName" on Taka Koi? to track all our shared expenses!';

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCardDeep : scheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Title Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.gold.withValues(alpha: 0.18)
                            : AppColors.primary.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.send_rounded,
                        color: isDark ? AppColors.primary : AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Invite to $tourName',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurface,
                            ),
                          ),
                          Text(
                            'Send the join code to your friends',
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Code Display Card (Never wraps, prominent, elegant)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkPanel : AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark
                          ? AppColors.gold.withValues(alpha: 0.3)
                          : AppColors.primary.withValues(alpha: 0.3),
                      width: 1.2,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'GROUP JOIN CODE',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                              color: isDark ? AppColors.onSurfaceVariantDark : scheme.onSurfaceVariant,
                            ),
                          ),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () {
                                HapticFeedback.lightImpact();
                                Clipboard.setData(ClipboardData(text: code));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('✅ Join code copied!'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? AppColors.gold.withValues(alpha: 0.18)
                                      : AppColors.primary.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.copy_rounded,
                                      size: 14,
                                      color: isDark ? AppColors.primary : AppColors.poshGold,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Copy Code',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? AppColors.primary : AppColors.poshGold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          code,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 8,
                            color: isDark ? AppColors.primary : AppColors.poshGold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Share Targets with Actual Brand Icons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _ShareTargetButton(
                      label: 'WhatsApp',
                      app: 'whatsapp',
                      onTap: () {
                        Navigator.pop(ctx);
                        _launchShare(tourName: tourName, code: code, target: 'whatsapp');
                      },
                    ),
                    _ShareTargetButton(
                      label: 'Messenger',
                      app: 'messenger',
                      onTap: () {
                        Navigator.pop(ctx);
                        _launchShare(tourName: tourName, code: code, target: 'messenger');
                      },
                    ),
                    _ShareTargetButton(
                      label: 'Instagram',
                      app: 'instagram',
                      onTap: () {
                        Navigator.pop(ctx);
                        _launchShare(tourName: tourName, code: code, target: 'instagram');
                      },
                    ),
                    _ShareTargetButton(
                      label: 'More Apps',
                      app: 'more',
                      onTap: () {
                        Navigator.pop(ctx);
                        _launchShare(tourName: tourName, code: code, target: null);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Formatted Message Preview Card (Clean, NO Github link)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkPanel : scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? AppColors.gold.withValues(alpha: 0.2) : scheme.outline.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'MESSAGE PREVIEW',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          InkWell(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: inviteText));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('✅ Full invite message copied!'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                            child: Row(
                              children: [
                                Icon(Icons.copy_rounded, size: 12, color: scheme.primary),
                                const SizedBox(width: 4),
                                Text(
                                  'Copy Message',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: scheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.gold.withValues(alpha: 0.18)
                              : AppColors.primary.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          code,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2,
                            color: isDark ? AppColors.primary : AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Join our tour "$tourName" on Taka Koi? to track all our shared expenses!',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                          color: scheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

Future<void> _launchShare({
  required String tourName,
  required String code,
  String? target,
}) async {
  final inviteText = '$code\n\n'
      'Join our tour "$tourName" on Taka Koi? to track all our shared expenses!';

  const channel = MethodChannel('com.tourtracker.tour_expense_tracker/app_launcher');

  if (target == 'whatsapp') {
    try {
      final ok = await channel.invokeMethod<bool>('shareToPackage', {
        'package': 'com.whatsapp',
        'text': inviteText,
      });
      if (ok == true) return;
    } catch (e, s) {
      logError('launchShare', e, s);
    }

    final uri = Uri.parse('whatsapp://send?text=${Uri.encodeComponent(inviteText)}');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (e, s) {
      logError('launchShare', e, s);
    }

    final webUri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(inviteText)}');
    try {
      if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (e, s) {
      logError('launchShare', e, s);
    }
  } else if (target == 'messenger') {
    try {
      final ok = await channel.invokeMethod<bool>('shareToPackage', {
        'package': 'com.facebook.orca',
        'text': inviteText,
      });
      if (ok == true) return;
    } catch (e, s) {
      logError('launchShare', e, s);
    }
  } else if (target == 'instagram') {
    try {
      final ok = await channel.invokeMethod<bool>('shareToPackage', {
        'package': 'com.instagram.android',
        'text': inviteText,
      });
      if (ok == true) return;
    } catch (e, s) {
      logError('launchShare', e, s);
    }
  }

  // System share sheet (Default / "More Apps")
  try {
    final ok = await channel.invokeMethod<bool>('shareText', {
      'text': inviteText,
      'title': 'Invite Members to $tourName',
    });
    if (ok == true) return;
  } catch (e, s) {
    logError('launchShare', e, s);
  }

  // Fallback: copy to clipboard
  await Clipboard.setData(ClipboardData(text: inviteText));
}

class _ShareTargetButton extends StatelessWidget {
  final String label;
  final String app;
  final VoidCallback onTap;

  const _ShareTargetButton({
    required this.label,
    required this.app,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BrandLogoWidget(app: app, size: 52),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BrandLogoWidget extends StatelessWidget {
  final String app;
  final double size;

  const BrandLogoWidget({super.key, required this.app, this.size = 52});

  @override
  Widget build(BuildContext context) {
    switch (app) {
      case 'whatsapp':
        return SizedBox(
          width: size,
          height: size,
          child: Image.asset(
            'assets/icons/whatsapp.png',
            width: size,
            height: size,
            fit: BoxFit.contain,
          ),
        );

      case 'messenger':
        return SizedBox(
          width: size,
          height: size,
          child: Image.asset(
            'assets/icons/messenger.png',
            width: size,
            height: size,
            fit: BoxFit.contain,
          ),
        );

      case 'instagram':
        return SizedBox(
          width: size,
          height: size,
          child: Image.asset(
            'assets/icons/instagram.png',
            width: size,
            height: size,
            fit: BoxFit.contain,
          ),
        );

      default:
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDark ? AppColors.darkChip : AppColors.sandChip,
            border: Border.all(
              color: isDark ? AppColors.gold.withValues(alpha: 0.35) : AppColors.sandBorder,
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: Icon(
              Icons.apps_rounded,
              size: size * 0.46,
              color: isDark ? AppColors.primary : AppColors.poshObsidian,
            ),
          ),
        );
    }
  }
}
