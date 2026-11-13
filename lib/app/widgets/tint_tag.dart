import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Small status tag on a soft tint (e.g. "Chờ duyệt", "Đã nhận sân").
/// Pass a tone from `context.fc` (success, warning, danger, info, neutral);
/// without one the tag uses the accent tint.
class TintTag extends StatelessWidget {
  const TintTag(this.label, {super.key, this.tone, this.icon});
  final String label;
  final StatusTone? tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final fg = tone?.color ?? colors.onPrimaryContainer;
    final bg = tone?.container ?? colors.primaryContainer;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(Radii.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: fg),
              const SizedBox(width: Gap.xs),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: fg,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
