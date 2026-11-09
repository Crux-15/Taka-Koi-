import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';
import 'empty_state_widget.dart';

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

/// Branded loader: a thin gold ring.
class AppLoader extends StatelessWidget {
  final double size;
  final Color? color;

  const AppLoader({super.key, this.size = 32, this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width:  size,
      height: size,
      child:  CircularProgressIndicator(
        strokeWidth: 2.5,
        strokeCap:   StrokeCap.round,
        color:       color ?? Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

/// Inline empty state (same look as [EmptyStateWidget]).
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
  Widget build(BuildContext context) =>
      EmptyStateWidget(icon: icon, title: title, subtitle: subtitle, action: action);
}
