import 'package:flutter/material.dart';

/// Reusable empty state display with icon, title, and subtitle.
/// Same API as EmptyState in loading_widget.dart but exported separately for clean imports.
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
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color:  scheme.primaryContainer,
                shape:  BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: scheme.primary),
            ),
            const SizedBox(height: 20),
            Text(title,    style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant), textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 24), action!],
          ],
        ),
      ),
    );
  }
}
