import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';

/// Full-screen loading overlay.
class LoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;

  const LoadingOverlay({super.key, required this.isLoading, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            color: AppColors.overlay,
            child: const Center(child: AppLoader()),
          ),
      ],
    );
  }
}

/// Branded circular loader.
class AppLoader extends StatelessWidget {
  final double size;
  final Color? color;

  const AppLoader({super.key, this.size = 44, this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width:  size,
      height: size,
      child:  CircularProgressIndicator(
        strokeWidth: 3,
        color: color ?? Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

/// Inline empty state with icon, title, and subtitle.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String   title;
  final String   subtitle;
  final Widget?  action;

  const EmptyState({
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
                color:        scheme.primaryContainer,
                shape:        BoxShape.circle,
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
