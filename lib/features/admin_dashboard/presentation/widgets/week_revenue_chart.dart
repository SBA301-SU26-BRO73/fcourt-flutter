import 'package:flutter/material.dart';

import '../../domain/entities/analytics.dart';

/// Biểu đồ cột "Doanh thu 7 ngày" (mockup 06): trục 0 / giữa / đỉnh theo triệu
/// đồng, cột tím, ngày hôm nay đậm hơn, nhãn thứ ở dưới mỗi cột.
class WeekRevenueChart extends StatelessWidget {
  const WeekRevenueChart({super.key, required this.points});
  final List<RevenuePoint> points;

  static const _days = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

  /// Đỉnh trục (triệu đồng): làm tròn lên 0,5 / 1 / 2 / 5 / 10... cho gọn.
  static double axisTop(int maxVnd) {
    final millions = maxVnd / 1e6;
    if (millions <= 0.5) return 0.5;
    if (millions <= 1) return 1;
    if (millions <= 2) return 2;
    if (millions <= 5) return 5;
    var step = 10.0;
    while (millions > step) {
      step *= 2;
    }
    return step;
  }

  static String _axis(double v) => v == v.roundToDouble()
      ? '${v.toInt()},0'
      : v.toString().replaceAll('.', ',');

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final top = axisTop(
      points.fold<int>(0, (m, p) => p.revenue > m ? p.revenue : m),
    );
    final bar = dark ? const Color(0xFF8D80F2) : const Color(0xFF7869EC);
    final today = dark ? const Color(0xFFC1B7FF) : const Color(0xFF4F3FE8);
    final axisStyle = TextStyle(
      fontSize: 9,
      height: 1.1,
      color: colors.onSurfaceVariant,
    );
    return SizedBox(
      height: 141,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 21),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_axis(top), style: axisStyle),
                Text(_axis(top / 2), style: axisStyle),
                Text('0', style: axisStyle),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: Container(height: 1, color: colors.outlineVariant),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 59,
                  child: Container(height: 1, color: colors.outlineVariant),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < points.length; i++) ...[
                      if (i > 0) const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          children: [
                            SizedBox(
                              height: 120,
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: FractionallySizedBox(
                                  widthFactor: 1,
                                  heightFactor: (points[i].revenue / 1e6 / top)
                                      .clamp(0.02, 1.0),
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: i == points.length - 1
                                          ? today
                                          : bar,
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(6),
                                        bottom: Radius.circular(2),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _days[points[i].periodStart.weekday - 1],
                              style: axisStyle,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
