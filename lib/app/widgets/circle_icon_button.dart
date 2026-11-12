import 'package:flutter/material.dart';

/// Round icon button (back, map, favourite). 42dp circle inside a 48dp touch
/// target. [onImage] gives the white disc used on top of a photo.
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.onImage = false,
    this.size = 42,
  });
  final IconData icon;

  /// Spoken label; required because the button has no text.
  final String tooltip;
  final VoidCallback? onPressed;

  /// White disc with dark icon, for use over a photo in both themes.
  final bool onImage;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final disc = onImage ? Colors.white : colors.surfaceContainerLow;
    final ink = onImage ? const Color(0xFF29324B) : colors.onSurface;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        excludeSemantics: true,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: Material(
              color: disc,
              shape: CircleBorder(
                side: onImage
                    ? BorderSide.none
                    : BorderSide(color: colors.outlineVariant),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onPressed,
                child: SizedBox.square(
                  dimension: size,
                  child: Icon(icon, size: 22, color: ink),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
