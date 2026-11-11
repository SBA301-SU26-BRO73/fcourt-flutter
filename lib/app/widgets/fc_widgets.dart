import 'package:flutter/material.dart';

import '../theme/tokens.dart';

export '../theme/tokens.dart';

/// Content surface resting on the wallpaper: translucent fill, light-catching
/// hairline and a soft tinted shadow. Paint only — safe in long lists, unlike
/// refractive glass, which is reserved for navigation chrome.
class FrostedCard extends StatelessWidget {
  const FrostedCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Gap.lg),
    this.radius = Radii.card,
    this.onTap,
    this.strong = false,
    this.elevated = true,
    this.clip = false,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;

  /// Denser fill, for surfaces that carry inputs or small text.
  final bool strong;
  final bool elevated;

  /// Clip children (images) to the rounded shape.
  final bool clip;

  @override
  Widget build(BuildContext context) {
    final fc = context.fc;
    final shape = BorderRadius.circular(radius);
    Widget content = Padding(padding: padding, child: child);
    if (onTap != null) {
      content = InkWell(onTap: onTap, borderRadius: shape, child: content);
    }
    final card = DecoratedBox(
      decoration: BoxDecoration(
        color: strong ? fc.frostedStrong : fc.frostedFill,
        borderRadius: shape,
        border: Border.all(color: fc.hairline),
        boxShadow: elevated ? fc.shadow : null,
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: shape,
        clipBehavior: clip || onTap != null ? Clip.antiAlias : Clip.none,
        child: content,
      ),
    );
    return onTap == null ? card : PressableScale(child: card);
  }
}

/// Brand-gradient hero with faint court lines and a soft glow.
class HeroPanel extends StatelessWidget {
  const HeroPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Gap.xl),
    this.radius = Radii.xl,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final fc = context.fc;
    final shape = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        gradient: fc.brand,
        boxShadow: [
          BoxShadow(
            color: fc.brandGradient[1].withValues(alpha: .34),
            blurRadius: 36,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: shape,
        child: CustomPaint(
          foregroundPainter: _HeroSheenPainter(radius),
          painter: const _HeroCourtPainter(),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class _HeroCourtPainter extends CustomPainter {
  const _HeroCourtPainter();
  @override
  void paint(Canvas canvas, Size size) {
    // Glow in the top-right corner.
    final glow = Offset(size.width * .92, size.height * .05);
    canvas.drawCircle(
      glow,
      size.width * .55,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: .26),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: glow, radius: size.width * .55)),
    );
    // Faint court markings, tilted.
    final line = Paint()
      ..color = Colors.white.withValues(alpha: .13)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    canvas.save();
    canvas.translate(size.width * .78, size.height * .5);
    canvas.rotate(-.32);
    final court = Rect.fromCenter(
      center: Offset.zero,
      width: size.width * .62,
      height: size.width * .98,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(court, const Radius.circular(6)),
      line,
    );
    canvas.drawLine(court.centerLeft, court.centerRight, line);
    canvas.drawLine(court.topCenter, court.bottomCenter, line);
    canvas.drawRect(court.deflate(court.width * .16), line);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_HeroCourtPainter oldDelegate) => false;
}

/// Specular edge along the top-left, like light catching a glass rim.
class _HeroSheenPainter extends CustomPainter {
  const _HeroSheenPainter(this.radius);
  final double radius;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(.75);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radius)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: .6),
            Colors.white.withValues(alpha: .04),
            Colors.white.withValues(alpha: .22),
          ],
          stops: const [0, .55, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_HeroSheenPainter oldDelegate) =>
      oldDelegate.radius != radius;
}

/// Small uppercase label used above heroes and groups.
class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key, this.color, this.icon});
  final String text;
  final Color? color;
  final IconData? icon;
  @override
  Widget build(BuildContext context) {
    final tint = color ?? Theme.of(context).colorScheme.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: tint),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: Text(
            text,
            style: TextStyle(
              color: tint,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.3,
            ),
          ),
        ),
      ],
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
              Text(title, style: theme.textTheme.titleLarge),
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

/// Rounded, softly tinted container for a leading icon.
class IconBadge extends StatelessWidget {
  const IconBadge(this.icon, {super.key, this.color, this.size = 46});
  final IconData icon;
  final Color? color;
  final double size;
  @override
  Widget build(BuildContext context) {
    final tint = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * .34),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [tint.withValues(alpha: .1), tint.withValues(alpha: .24)],
        ),
        border: Border.all(color: tint.withValues(alpha: .16)),
      ),
      child: Icon(icon, color: tint, size: size * .5),
    );
  }
}

/// Status with icon + text, never colour alone.
class StatusPill extends StatelessWidget {
  const StatusPill(this.label, {super.key, required this.color, this.icon});
  final String label;
  final Color color;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .13),
      borderRadius: BorderRadius.circular(Radii.pill),
      border: Border.all(color: color.withValues(alpha: .22)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
        ],
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              color: color,
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
    this.icon = Icons.sports_tennis,
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
            const SizedBox(height: 6),
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

/// Subtle press feedback (scale down) for tappable surfaces. Listens only, so
/// the child's own tap handling keeps working.
class PressableScale extends StatefulWidget {
  const PressableScale({super.key, required this.child});
  final Widget child;
  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _down = false;
  void _set(bool value) {
    if (_down != value) setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (_) => _set(true),
    onPointerUp: (_) => _set(false),
    onPointerCancel: (_) => _set(false),
    child: AnimatedScale(
      scale: _down ? .975 : 1,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 140),
      curve: Curves.easeOutCubic,
      child: widget.child,
    ),
  );
}

/// The FCOURT mark: a glossy brand-gradient tile with the racket glyph.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 64});
  final double size;
  @override
  Widget build(BuildContext context) {
    final fc = context.fc;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * .32),
        gradient: fc.brand,
        border: Border.all(color: Colors.white.withValues(alpha: .45)),
        boxShadow: [
          BoxShadow(
            color: fc.brandGradient[1].withValues(alpha: .38),
            blurRadius: size * .4,
            offset: Offset(0, size * .16),
          ),
        ],
      ),
      child: Icon(Icons.sports_tennis, color: Colors.white, size: size * .54),
    );
  }
}
