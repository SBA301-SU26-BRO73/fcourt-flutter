import 'package:flutter/material.dart';

import '../../domain/entities/pricing_rule.dart';
import 'facility_formatters.dart';
import '../../../../app/theme/tokens.dart';

const peakColor = ChartColors.peak;
const offPeakColor = ChartColors.success;

const _minutesPerDay = 24 * 60;

/// "150k" cho giá tròn nghìn, ngược lại giữ dạng đầy đủ.
String compactVnd(int amount) =>
    amount % 1000 == 0 ? '${amount ~/ 1000}k' : formatVnd(amount);

/// SCRUM-81: thanh dải màu biểu diễn 24 giờ. Xanh lá = giờ thấp điểm, cam =
/// giờ cao điểm kèm giá; khoảng trống (xám) dùng giá mặc định của sân.
class PricingTimelineBar extends StatelessWidget {
  const PricingTimelineBar({
    super.key,
    required this.rules,
    required this.onSegmentTap,
  });

  final List<PricingRule> rules;
  final void Function(PricingRule rule) onSegmentTap;

  static const _barHeight = 56.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return SizedBox(
              key: const Key('pricing-timeline'),
              height: _barHeight,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  for (final rule in rules)
                    Positioned(
                      left: width * rule.startTime.inMinutes / _minutesPerDay,
                      width:
                          width *
                          (rule.endTime.inMinutes - rule.startTime.inMinutes) /
                          _minutesPerDay,
                      top: 0,
                      bottom: 0,
                      child: _Segment(
                        rule: rule,
                        onTap: () => onSegmentTap(rule),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 4),
        const _HourTicks(),
        const SizedBox(height: 8),
        const Wrap(
          spacing: 16,
          runSpacing: 4,
          children: [
            _LegendDot(color: offPeakColor, label: 'Giờ thấp điểm'),
            _LegendDot(color: peakColor, label: 'Giờ cao điểm'),
            _LegendDot(color: Colors.grey, label: 'Giá mặc định của sân'),
          ],
        ),
      ],
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({required this.rule, required this.onTap});

  final PricingRule rule;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = rule.peak ? peakColor : offPeakColor;
    return Semantics(
      button: true,
      label:
          '${rule.name}, ${rule.startTime.format()} đến ${rule.endTime.format()}, '
          '${formatVnd(rule.pricePerHour)} mỗi giờ',
      child: Material(
        key: Key('pricing-segment-${rule.id}'),
        color: color,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  compactVnd(rule.pricePerHour),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HourTicks extends StatelessWidget {
  const _HourTicks();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final hour in const [0, 6, 12, 18, 24])
          Text('${hour.toString().padLeft(2, '0')}h', style: style),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}
