import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import '../../utils/app_palette.dart';
import '../../utils/app_typography.dart';

/// A calm pill that slides in at the top while the phone is offline.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return StreamBuilder<List<ConnectivityResult>>(
      stream: Connectivity().onConnectivityChanged,
      builder: (context, snapshot) {
        final results   = snapshot.data ?? const [ConnectivityResult.wifi];
        final isOffline = results.every((r) => r == ConnectivityResult.none);
        return AnimatedSize(
          duration: const Duration(milliseconds: 280),
          curve:    Curves.easeOutCubic,
          child: !isOffline
              ? const SizedBox(width: double.infinity)
              : SafeArea(
                  bottom: false,
                  child: Container(
                    margin:  const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color:        p.soft(p.pending),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.cloud_off_rounded, size: 16, color: p.pending),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Offline. New expenses and payments sync when you\'re back.',
                            style: TextStyle(fontFamily: AppType.body, fontSize: 12.5, fontWeight: FontWeight.w500, color: p.text),
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
}
