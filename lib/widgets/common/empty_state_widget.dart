import 'package:flutter/material.dart';
import '../../utils/app_palette.dart';

/// Friendly empty state: a soft icon medallion, a title and a hint.
class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String   title;
  final String   subtitle;
  final Widget?  action;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 104, height: 104,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [p.accent.withValues(alpha: p.isDark ? 0.16 : 0.12), p.accent.withValues(alpha: 0)],
                ),
              ),
              child: Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  color:        p.surface,
                  borderRadius: BorderRadius.circular(20),
                  border:       Border.all(color: p.hairline),
                  boxShadow:    p.cardShadow,
                ),
                child: Icon(icon, size: 28, color: p.accent),
              ),
            ),
            const SizedBox(height: 16),
            Text(title, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700), textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(subtitle, style: t.bodyMedium?.copyWith(color: p.textMuted), textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 22), action!],
          ],
        ),
      ),
    );
  }
}
