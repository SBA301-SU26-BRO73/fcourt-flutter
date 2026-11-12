import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Floating bar at the bottom of a screen: small caption + price on the left,
/// pill action on the right (mock-up "bottom-price": 16dp side margin, 32dp
/// corners, soft shadow). Put it in `Scaffold.bottomNavigationBar`; it adds the
/// system inset itself. [filled] is the solid indigo (lime in dark) variant
/// of the slot picker summary.
class FloatingBottomBar extends StatelessWidget {
  const FloatingBottomBar({
    super.key,
    required this.priceText,
    required this.actionLabel,
    required this.onAction,
    this.caption,
    this.priceUnit,
    this.actionIcon = Icons.arrow_forward,
    this.filled = false,
    this.loading = false,
  });

  /// Space a scrolling body leaves at its end when the bar overlaps it.
  static const double clearance = Gap.bottomBarClearance;

  final String priceText;
  final String actionLabel;

  /// Null disables the action.
  final VoidCallback? onAction;
  final String? caption;

  /// Small suffix after the price, e.g. "/giờ".
  final String? priceUnit;
  final IconData? actionIcon;
  final bool filled;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bar = filled
        ? (dark ? colors.primary : colors.onPrimaryContainer)
        : colors.surfaceContainerLow;
    final onBar = filled ? (dark ? colors.onPrimary : Colors.white) : null;
    final priceColor = onBar ?? colors.primary;
    final captionColor =
        onBar?.withValues(alpha: .8) ?? colors.onSurfaceVariant;
    final enabled = onAction != null && !loading;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(19, 12, 15, 12),
          decoration: BoxDecoration(
            color: bar,
            borderRadius: BorderRadius.circular(32),
            border: filled ? null : Border.all(color: colors.outlineVariant),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1015233D),
                blurRadius: 24,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (caption != null)
                      Text(
                        caption!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: captionColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    if (caption != null) const SizedBox(height: 4),
                    Text.rich(
                      TextSpan(
                        text: priceText,
                        children: [
                          if (priceUnit != null)
                            TextSpan(
                              text: priceUnit,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: priceColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Gap.md),
              FilledButton(
                onPressed: enabled ? onAction : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, Gap.touch),
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  backgroundColor: filled ? onBar : null,
                  foregroundColor: filled ? bar : null,
                ),
                child: loading
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(actionLabel),
                          if (actionIcon != null) ...[
                            const SizedBox(width: Gap.sm),
                            Icon(actionIcon, size: 18),
                          ],
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
