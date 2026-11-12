import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'compact_currency.dart';
import '../../../../app/theme/tokens.dart';

/// Đồng hồ nửa vòng tròn thể hiện tỷ lệ lấp đầy. [rate] là tỉ lệ 0..1 (đúng
/// quy ước `occupancyUnit = RATIO` của BE); phần trăm chỉ được tính khi hiển thị.
class OccupancyGauge extends StatelessWidget {
  const OccupancyGauge({super.key, required this.rate});

  final double rate;

  static const fillColor = ChartColors.peak;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final value = rate.isFinite ? rate.clamp(0.0, 1.0) : 0.0;
    return Semantics(
      label: 'Tỷ lệ lấp đầy ${formatPercent(value)}',
      child: SizedBox(
        height: 130,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: value),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
          builder: (context, animated, _) => CustomPaint(
            painter: _GaugePainter(
              fraction: animated,
              fill: fillColor,
              track: scheme.surfaceContainerHighest,
            ),
            child: Align(
              alignment: const Alignment(0, 0.55),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    formatPercent(value),
                    key: const ValueKey('occupancy-gauge-value'),
                    style: Theme.of(context).textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text('lấp đầy', style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  const _GaugePainter({
    required this.fraction,
    required this.fill,
    required this.track,
  });

  final double fraction;
  final Color fill;
  final Color track;

  static const _stroke = 16.0;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = math.min(size.width / 2, size.height) - _stroke / 2;
    final center = Offset(size.width / 2, size.height - _stroke / 2);
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, math.pi, math.pi, false, paint..color = track);
    if (fraction > 0) {
      canvas.drawArc(
        rect,
        math.pi,
        math.pi * fraction,
        false,
        paint..color = fill,
      );
    }
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.fraction != fraction || old.fill != fill || old.track != track;
}
