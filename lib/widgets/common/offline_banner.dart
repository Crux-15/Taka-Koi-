import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../utils/app_colors.dart';

/// A slim banner that slides down when the device is offline.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ConnectivityResult>>(
      stream: Connectivity().onConnectivityChanged,
      builder: (context, snapshot) {
        final results     = snapshot.data ?? [ConnectivityResult.wifi];
        final isOffline   = results.contains(ConnectivityResult.none);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height:   isOffline ? 36 : 0,
          color:    AppColors.warning,
          alignment: Alignment.center,
          child: isOffline
              ? const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.wifi_off_rounded, size: 16, color: Colors.white),
                    SizedBox(width: 8),
                    Text('You are offline — changes will sync when back online',
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                )
              : null,
        );
      },
    );
  }
}
