import 'package:flutter/material.dart';
import '../../utils/app_palette.dart';

/// A segmented "pill" tab bar (for an AppBar's `bottom` or inline).
class PillTabBar extends StatelessWidget implements PreferredSizeWidget {
  final TabController? controller;
  final List<Widget> tabs;
  final EdgeInsetsGeometry margin;

  const PillTabBar({
    super.key,
    required this.tabs,
    this.controller,
    this.margin = const EdgeInsets.fromLTRB(20, 4, 20, 12),
  });

  @override
  Size get preferredSize => const Size.fromHeight(62);

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      margin:  margin,
      height:  46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color:        p.surfaceRaised,
        borderRadius: BorderRadius.circular(15),
        border:       Border.all(color: p.hairline),
      ),
      child: TabBar(controller: controller, tabs: tabs),
    );
  }
}
