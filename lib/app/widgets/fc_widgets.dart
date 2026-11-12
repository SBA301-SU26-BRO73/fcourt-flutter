import 'package:flutter/material.dart';

import '../theme/tokens.dart';

export '../theme/tokens.dart';

/// Flat content surface: one step above the page, 1px hairline, no shadow.
/// Tappable cards get a real ink response.
class FcCard extends StatelessWidget {
  const FcCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Gap.lg),
    this.radius = Radii.lg,
    this.onTap,
    this.clip = false,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;

  /// Clip children (images) to the rounded shape.
  final bool clip;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final shape = BorderRadius.circular(radius);
    return Material(
      color: colors.surfaceContainerLow,
      clipBehavior: clip || onTap != null ? Clip.antiAlias : Clip.none,
      shape: RoundedRectangleBorder(
        borderRadius: shape,
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: onTap == null
          ? Padding(padding: padding, child: child)
          : InkWell(
              onTap: onTap,
              borderRadius: shape,
              child: Padding(padding: padding, child: child),
            ),
    );
  }
}

/// Title (and optional subtitle / trailing action) above a group of content.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.subtitle, this.trailing});
  final String title;
  final String? subtitle;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleMedium),
              if (subtitle != null) ...[
                const SizedBox(height: Gap.xs),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// Rounded tonal container for a leading icon.
class IconBadge extends StatelessWidget {
  const IconBadge(this.icon, {super.key, this.color, this.size = 48});
  final IconData icon;

  /// Icon colour; the container is the matching tonal surface.
  final Color? color;
  final double size;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final tint = color ?? colors.onPrimaryContainer;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.md),
        color: color == null
            ? colors.primaryContainer
            : colors.surfaceContainer,
      ),
      child: Icon(icon, color: tint, size: size / 2),
    );
  }
}

/// Status with icon + text, never colour alone.
class StatusPill extends StatelessWidget {
  const StatusPill(this.label, {super.key, required this.tone, this.icon});
  final String label;
  final StatusTone tone;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: Gap.xs),
    decoration: BoxDecoration(
      color: tone.container,
      borderRadius: BorderRadius.circular(Radii.pill),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: tone.color),
          const SizedBox(width: Gap.xs),
        ],
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              color: tone.color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Icon + message (+ action) for empty and error states.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.message,
    required this.icon,
    this.title,
    this.action,
  });
  final String message;
  final IconData icon;
  final String? title;
  final Widget? action;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Gap.xl, horizontal: Gap.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconBadge(icon, size: 64),
          const SizedBox(height: Gap.lg),
          if (title != null) ...[
            Text(
              title!,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: Gap.sm),
          ],
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (action != null) ...[const SizedBox(height: Gap.md), action!],
        ],
      ),
    );
  }
}

/// The FCOURT mark: a flat teal tile with the court glyph.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 56});
  final double size;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.lg),
        color: colors.primary,
      ),
      child: Icon(
        Icons.sports_tennis_outlined,
        color: colors.onPrimary,
        size: size * .54,
      ),
    );
  }
}
