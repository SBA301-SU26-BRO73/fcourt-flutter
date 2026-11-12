import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'sport_icon.dart';

/// Sport icon inside a soft round disc with a label under it (home filter
/// row). [selected] fills the disc with the accent.
class SportCircleIcon extends StatelessWidget {
  const SportCircleIcon({
    super.key,
    required this.kind,
    required this.label,
    this.selected = false,
    this.onTap,
    this.size = 54,
  });
  final SportKind kind;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  /// Disc diameter.
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final disc = selected ? colors.primary : colors.primaryContainer;
    final ink = selected ? colors.onPrimary : colors.onPrimaryContainer;
    return Semantics(
      button: onTap != null,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: size * .8,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: Gap.touch),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(shape: BoxShape.circle, color: disc),
                child: Center(
                  child: SportIcon(kind, size: size / 2, color: ink),
                ),
              ),
              const SizedBox(height: 9),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: selected ? colors.primary : colors.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
