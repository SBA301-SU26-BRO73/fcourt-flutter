import 'package:flutter/material.dart';

import 'fc_widgets.dart';

/// Figure card for dashboards: label, big value, optional note and an icon in
/// a soft disc. [tone] colours the icon disc and the note (default accent).
class KpiCard extends StatelessWidget {
  const KpiCard({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.note,
    this.tone,
    this.onTap,
  });
  final String label;
  final String value;
  final IconData? icon;

  /// Small line under the value, e.g. "+12% so với tuần trước".
  final String? note;
  final StatusTone? tone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final fg = tone?.color ?? colors.onPrimaryContainer;
    final bg = tone?.container ?? colors.primaryContainer;
    return FcCard(
      onTap: onTap,
      radius: Radii.xl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: bg),
                  child: Icon(icon, size: 20, color: fg),
                ),
                const SizedBox(width: Gap.sm),
              ],
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.md),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                height: 1.1,
              ),
            ),
          ),
          if (note != null) ...[
            const SizedBox(height: Gap.xs),
            Text(
              note!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: tone?.color ?? colors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
