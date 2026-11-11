import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// The aurora wallpaper every page rests on: a calm base colour with a few
/// large, soft glows. Static paint (no blur, no animation), so it is cheap and
/// gives the glass chrome something worth refracting.
class AppBackdrop extends StatelessWidget {
  const AppBackdrop({super.key, this.child});
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final fc = context.fc;
    return CustomPaint(
      isComplex: true,
      painter: _AuroraPainter(fc.wallpaper, fc.glows),
      child: child ?? const SizedBox.expand(),
    );
  }
}

class _AuroraPainter extends CustomPainter {
  const _AuroraPainter(this.base, this.glows);
  final Color base;
  final List<(Color, Alignment, double)> glows;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = base);
    for (final (color, alignment, factor) in glows) {
      final center = alignment.alongSize(size);
      final radius = size.longestSide * factor * .62;
      canvas.drawRect(
        rect,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color,
              color.withValues(alpha: color.a * .45),
              color.withValues(alpha: 0),
            ],
            stops: const [0, .45, 1],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }
  }

  @override
  bool shouldRepaint(_AuroraPainter oldDelegate) =>
      oldDelegate.base != base || oldDelegate.glows != glows;
}

/// Gives every page route its own wallpaper, so transparent scaffolds never
/// reveal the previous page during a transition.
class BackdropPageTransitionsBuilder extends PageTransitionsBuilder {
  const BackdropPageTransitionsBuilder(this.delegate);
  final PageTransitionsBuilder delegate;

  @override
  DelegatedTransitionBuilder? get delegatedTransition =>
      delegate.delegatedTransition;

  @override
  Duration get transitionDuration => delegate.transitionDuration;

  @override
  Duration get reverseTransitionDuration => delegate.reverseTransitionDuration;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => delegate.buildTransitions(
    route,
    context,
    animation,
    secondaryAnimation,
    AppBackdrop(child: child),
  );
}
