import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// One tab of the [FloatingNavBar].
class FloatingNavItem {
  const FloatingNavItem({
    required this.label,
    required this.icon,
    this.badgeCount = 0,
  });
  final String label;
  final IconData icon;

  /// Shows a small dot when greater than zero.
  final int badgeCount;
}

/// Rounded bar floating above the page bottom (mock-up "nav": 16dp side
/// margin, 32dp corners, 1dp line, soft shadow; selected tab = accent colour
/// with a tinted rounded icon pill). Use as `Scaffold.bottomNavigationBar`; it
/// adds the system inset itself. A body above it ends [outerHeight] earlier;
/// a body that extends behind it pads its end with [clearance].
class FloatingNavBar extends StatelessWidget {
  const FloatingNavBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  /// Height of the pill itself.
  static const double height = 68;

  /// Pill plus its 12dp bottom margin, without the system inset.
  static const double outerHeight = height + 12;

  /// Bottom padding for content that scrolls behind the bar.
  static const double clearance = Gap.navClearance;

  final List<FloatingNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 5),
          decoration: BoxDecoration(
            color: colors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: colors.outlineVariant),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1214213C),
                blurRadius: 24,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              for (final (i, item) in items.indexed)
                Expanded(
                  child: _Tab(
                    item: item,
                    selected: i == selectedIndex,
                    onTap: () => onSelected(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.item, required this.selected, required this.onTap});
  final FloatingNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final ink = selected ? colors.primary : colors.onSurfaceVariant;
    Widget icon = Icon(item.icon, size: 22, color: ink);
    if (item.badgeCount > 0) {
      icon = Badge(smallSize: 8, backgroundColor: colors.error, child: icon);
    }
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 36,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
              decoration: BoxDecoration(
                color: selected ? colors.primaryContainer : Colors.transparent,
                borderRadius: BorderRadius.circular(Radii.md),
              ),
              child: icon,
            ),
            const SizedBox(height: 3),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: ink,
                fontSize: 11,
                height: 1.1,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
