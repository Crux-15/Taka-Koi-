import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../utils/app_palette.dart';

/// Keeps the app at a comfortable width on big screens.
///
/// Phones use the whole screen. On tablets the app is a centred column, and
/// on computers it sits in a rounded card, both on a soft branded backdrop,
/// instead of stretching every card, field and button edge to edge.
///
/// Everything inside (pages, dialogs, bottom sheets, snack bars) sees the
/// frame as "the screen", so layouts that read the screen size still fit.
class AppFrame extends StatelessWidget {
  const AppFrame({super.key, required this.child});

  final Widget child;

  /// Up to this width the app fills the screen.
  static const double phoneMaxWidth = 640;

  /// Tablet column width.
  static const double columnWidth = 600;

  /// Computer card size.
  static const double cardWidth = 520;
  static const double cardMaxHeight = 960;
  static const double cardMargin = 24;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final screen = mq.size;
    if (screen.width <= phoneMaxWidth) return child;

    final p = context.palette;
    final asCard = screen.width >= 1024 && screen.height >= 640;

    final Widget framed;
    if (asCard) {
      final height = math.min(screen.height - cardMargin * 2, cardMaxHeight);
      final bottomGap = (screen.height - height) / 2;
      framed = Center(
        child: Container(
          width: cardWidth,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: p.isDark ? const Color(0x14FFFFFF) : const Color(0x14000000)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: p.isDark ? 0.5 : 0.10),
                blurRadius: 48,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(27),
            child: MediaQuery(
              data: mq.copyWith(
                size: Size(cardWidth, height),
                padding: EdgeInsets.zero,
                viewPadding: EdgeInsets.zero,
                // An on-screen keyboard covers less of the card than of the screen.
                viewInsets: mq.viewInsets.copyWith(bottom: math.max(0, mq.viewInsets.bottom - bottomGap)),
              ),
              child: child,
            ),
          ),
        ),
      );
    } else {
      final width = math.min(screen.width, columnWidth);
      framed = Center(
        child: Container(
          width: width,
          height: screen.height,
          decoration: BoxDecoration(
            border: Border.symmetric(
              vertical: BorderSide(color: p.isDark ? const Color(0x14FFFFFF) : const Color(0x14000000)),
            ),
          ),
          child: MediaQuery(
            data: mq.copyWith(
              size: Size(width, screen.height),
              padding: mq.padding.copyWith(left: 0, right: 0),
              viewPadding: mq.viewPadding.copyWith(left: 0, right: 0),
            ),
            child: child,
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.background,
        gradient: RadialGradient(
          center: const Alignment(0, -1.1),
          radius: 1.3,
          colors: p.isDark
              ? const [Color(0xFF2A2114), Color(0xFF0B0A08)]
              : const [Color(0xFFF3E7C6), Color(0xFFEDE9E0)],
        ),
      ),
      child: framed,
    );
  }
}
