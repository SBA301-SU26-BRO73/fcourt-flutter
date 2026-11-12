import 'package:flutter/material.dart';

import '../../../../app/widgets/fc_widgets.dart';
import 'compact_currency.dart';

/// Tỷ lệ lấp đầy dạng số lớn kèm thanh tiến độ. [rate] là tỉ lệ 0..1 (đúng
/// quy ước `occupancyUnit = RATIO` của BE); phần trăm chỉ được tính khi hiển thị.
class OccupancyGauge extends StatelessWidget {
  const OccupancyGauge({super.key, required this.rate});

  final double rate;

  static const fillColor = ChartColors.accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final value = rate.isFinite ? rate.clamp(0.0, 1.0) : 0.0;
    return Semantics(
      label: 'Tỷ lệ lấp đầy ${formatPercent(value)}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            formatPercent(value),
            key: const ValueKey('occupancy-gauge-value'),
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              letterSpacing: -.5,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: Gap.sm),
          TweenAnimationBuilder<double>(
            tween: Tween(end: value),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (context, animated, _) => ClipRRect(
              borderRadius: BorderRadius.circular(Radii.pill),
              child: LinearProgressIndicator(
                value: animated,
                minHeight: 8,
                color: fillColor,
                backgroundColor: scheme.surfaceContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
