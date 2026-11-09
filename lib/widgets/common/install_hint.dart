import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/app_colors.dart';
import '../../utils/web_env.dart';
import '../ui/ui.dart';

/// On the website in a normal browser tab, explains how to get the app:
/// iPhone → add it to the Home Screen; Android → download the app.
/// Shows nothing in the Android app or when opened from the home-screen icon.
class InstallHint extends StatefulWidget {
  const InstallHint({super.key});

  static const apkUrl = 'https://github.com/Crux-15/Taka-Koi-/releases/latest/download/Taka-Koi.apk';

  @override
  State<InstallHint> createState() => _InstallHintState();
}

class _InstallHintState extends State<InstallHint> {
  bool _hidden = false;

  @override
  Widget build(BuildContext context) {
    if (_hidden || isInstalledWebApp || !(isIosWeb || isAndroidWeb)) return const SizedBox.shrink();
    final p = context.palette;
    final t = Theme.of(context).textTheme;

    Widget step(String n, String text, [IconData? icon]) => Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 20, height: 20,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: p.accent, shape: BoxShape.circle),
                child: Text(n, style: TextStyle(fontFamily: AppType.display, fontSize: 11, fontWeight: FontWeight.w700, color: p.onAccent)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(text, style: t.bodySmall?.copyWith(color: p.text))),
              if (icon != null) Icon(icon, size: 18, color: p.accent),
            ],
          ),
        );

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: AppCard(
        borderColor: p.accent.withValues(alpha: 0.35),
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: Image.asset('assets/images/taka_koi_icon.jpg', width: 34, height: 34),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(isIosWeb ? 'Put Taka Koi on your iPhone' : 'Get the Android app',
                      style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                ),
                IconButton(
                  tooltip:   'Hide',
                  icon:      Icon(Icons.close_rounded, size: 18, color: p.textFaint),
                  onPressed: () => setState(() => _hidden = true),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: isIosWeb
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        step('1', 'In Safari, tap the Share button at the bottom.', Icons.ios_share_rounded),
                        step('2', 'Choose "Add to Home Screen", then Add.', Icons.add_box_outlined),
                        step('3', 'Open Taka Koi from the new icon and sign in there. '
                            'The icon keeps its own sign-in, separate from this tab.'),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 6),
                        Text('The Android app is faster and works the same. It\'s free.',
                            style: t.bodySmall?.copyWith(color: p.text)),
                        const SizedBox(height: 10),
                        Pressable(
                          onTap: () => launchUrl(Uri.parse(InstallHint.apkUrl), mode: LaunchMode.externalApplication),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: p.isDark ? AppColors.primary : AppColors.poshObsidian,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.android_rounded, size: 18, color: p.isDark ? AppColors.ink : Colors.white),
                                const SizedBox(width: 8),
                                Text('Download the app',
                                    style: TextStyle(
                                      fontFamily: AppType.display, fontWeight: FontWeight.w600, fontSize: 14,
                                      color: p.isDark ? AppColors.ink : Colors.white,
                                    )),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
