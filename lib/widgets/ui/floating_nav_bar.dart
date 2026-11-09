import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/app_palette.dart';
import '../../utils/app_typography.dart';

class NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int badge;
  const NavItem(this.icon, this.activeIcon, this.label, {this.badge = 0});
}

/// Bottom navigation as a floating rounded bar. It sits in the Scaffold's
/// bottomNavigationBar slot, so content never scrolls underneath it.
class FloatingNavBar extends StatelessWidget {
  final List<NavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  const FloatingNavBar({super.key, required this.items, required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Container(
          height: 66,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color:        p.isDark ? const Color(0xFF181611) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border:       Border.all(color: p.hairline),
            boxShadow:    p.floatingShadow,
          ),
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(child: _NavButton(item: items[i], selected: i == currentIndex, onTap: () => onTap(i))),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final NavItem item;
  final bool selected;
  final VoidCallback onTap;

  const _NavButton({required this.item, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = selected ? p.text : p.textFaint;
    return Semantics(
      button:   true,
      selected: selected,
      label:    item.label,
      child: InkResponse(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        radius:          36,
        highlightShape:  BoxShape.rectangle,
        splashColor:     Colors.transparent,
        highlightColor:  Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve:    Curves.easeOutCubic,
              padding:  const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
              decoration: BoxDecoration(
                color:        selected ? p.soft(p.accent) : Colors.transparent,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Badge(
                isLabelVisible: item.badge > 0,
                label:          Text(item.badge > 9 ? '9+' : '${item.badge}'),
                offset:         const Offset(8, -6),
                child: Icon(selected ? item.activeIcon : item.icon,
                    size: 22, color: selected ? p.accent : color),
              ),
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 220),
              style: TextStyle(
                fontFamily: AppType.body,
                fontSize:   11.5,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color:      color,
              ),
              child: Text(item.label, maxLines: 1),
            ),
          ],
        ),
      ),
    );
  }
}
