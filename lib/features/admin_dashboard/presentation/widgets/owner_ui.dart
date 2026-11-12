import 'package:flutter/material.dart';

import '../../../../app/theme/tokens.dart';

/// Building blocks of the owner (chủ sân) screens, measured from the approved
/// WP3b mock-up (wp3b-mockup-2.html, screens 05 to 07). All sizes are the
/// mock-up CSS pixels.

/// Page margin of the owner screens.
const double ownerPad = 20;

/// Flat card of the mock-up: card colour, 1px line, radius 22 by default.
class OwnerCard extends StatelessWidget {
  const OwnerCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.radius = 22,
    this.color,
    this.bordered = true,
    this.onTap,
    this.clip = false,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;
  final bool bordered;
  final VoidCallback? onTap;
  final bool clip;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final shape = BorderRadius.circular(radius);
    return Material(
      color: color ?? colors.surfaceContainerLow,
      clipBehavior: clip || onTap != null ? Clip.antiAlias : Clip.none,
      shape: RoundedRectangleBorder(
        borderRadius: shape,
        side: bordered
            ? BorderSide(color: colors.outlineVariant)
            : BorderSide.none,
      ),
      child: onTap == null
          ? Padding(padding: padding, child: child)
          : InkWell(
              onTap: onTap,
              child: Padding(padding: padding, child: child),
            ),
    );
  }
}

/// Soft panel (counts): the page-raised colour, radius 20, no border.
class OwnerSoftPanel extends StatelessWidget {
  const OwnerSoftPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.onTap,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => OwnerCard(
    color: Theme.of(context).colorScheme.surfaceContainer,
    radius: 20,
    bordered: false,
    padding: padding,
    onTap: onTap,
    child: child,
  );
}

/// Round tinted disc with an icon (mock-up `.circle`).
class OwnerCircle extends StatelessWidget {
  const OwnerCircle({
    super.key,
    required this.icon,
    required this.tone,
    this.size = 30,
    this.iconSize,
  });
  final IconData icon;
  final StatusTone tone;
  final double size;
  final double? iconSize;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: tone.container),
    child: Icon(icon, size: iconSize ?? size * .56, color: tone.color),
  );
}

/// Pill button of the cards: filled accent or outlined, 11px bold label.
class OwnerPillButton extends StatelessWidget {
  const OwnerPillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.filled = true,
    this.padding = const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
    this.fontSize = 11,
    this.danger = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool filled;
  final EdgeInsetsGeometry padding;
  final double fontSize;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final enabled = onPressed != null;
    final bg = filled
        ? (danger ? colors.error : colors.primary)
        : colors.surfaceContainerLow;
    final fg = filled
        ? (danger ? colors.onError : colors.onPrimary)
        : (danger ? colors.error : colors.onSurface);
    return Opacity(
      opacity: enabled ? 1 : .5,
      child: Material(
        color: bg,
        shape: StadiumBorder(
          side: filled
              ? BorderSide.none
              : BorderSide(color: colors.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Padding(
            padding: padding,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: fontSize + 4, color: fg),
                  const SizedBox(width: 5),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: fg,
                      fontSize: fontSize,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small pill selector (`.pill`): "Tuần này ⌄", filter chips.
class OwnerPill extends StatelessWidget {
  const OwnerPill(
    this.label, {
    super.key,
    this.selected = false,
    this.onTap,
    this.trailing,
    this.fontSize = 10,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  });
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final Widget? trailing;
  final double fontSize;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: selected ? colors.primary : colors.surfaceContainer,
      shape: StadiumBorder(
        side: BorderSide(
          color: selected ? colors.primary : colors.outlineVariant,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: padding,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                  color: selected ? colors.onPrimary : colors.onSurface,
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 4), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}

/// `.section-title`: 18 bold, 23 above and 15 below, optional right note.
class OwnerSectionTitle extends StatelessWidget {
  const OwnerSectionTitle(
    this.title, {
    super.key,
    this.trailing,
    this.top = 21,
  });
  final String title;
  final Widget? trailing;
  final double top;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(top: top, bottom: 13),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -.5,
                color: colors.onSurface,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Small muted text (`.tiny.muted`, 11px).
class OwnerNote extends StatelessWidget {
  const OwnerNote(
    this.text, {
    super.key,
    this.size = 11,
    this.color,
    this.bold = false,
  });
  final String text;
  final double size;
  final Color? color;
  final bool bold;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      fontSize: size,
      height: 1.5,
      fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
      color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );
}

/// Accent link (`.small-link`): 11px bold with an arrow.
class OwnerLink extends StatelessWidget {
  const OwnerLink(this.label, {super.key, this.onTap, this.arrow = true});
  final String label;
  final VoidCallback? onTap;
  final bool arrow;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            if (arrow) ...[
              const SizedBox(width: 3),
              Icon(Icons.arrow_forward, size: 12, color: color),
            ],
          ],
        ),
      ),
    );
  }
}

/// Centered empty / error block used by owner lists.
class OwnerMessage extends StatelessWidget {
  const OwnerMessage({
    super.key,
    required this.icon,
    required this.text,
    this.action,
    this.onAction,
  });
  final IconData icon;
  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.primaryContainer,
              ),
              child: Icon(icon, color: colors.onPrimaryContainer),
            ),
            const SizedBox(height: 14),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: colors.onSurfaceVariant,
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: 14),
              OwnerPillButton(
                label: action!,
                onPressed: onAction,
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 22,
                ),
                fontSize: 12,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// "2 phút trước" style relative time in Vietnamese.
String timeAgoVi(DateTime time, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(time);
  if (diff.inMinutes < 1) return 'vừa xong';
  if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
  if (diff.inHours < 24) return '${diff.inHours} giờ trước';
  return '${diff.inDays} ngày trước';
}

/// White chip over a photo (`.badge`): optional icon + 10px bold label.
class OwnerPhotoChip extends StatelessWidget {
  const OwnerPhotoChip({super.key, required this.label, this.icon});
  final String label;
  final Widget? icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[icon!, const SizedBox(width: 4)],
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF354064),
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}
