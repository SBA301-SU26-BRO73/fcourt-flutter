import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../admin_dashboard/presentation/widgets/compact_currency.dart';
import '../../domain/entities/platform_overview.dart';

/// Biểu đồ đường đôi: tài khoản mới và dòng tiền GMV theo tháng. Hai chuỗi khác
/// đơn vị nên mỗi chuỗi được chuẩn hóa theo mức cao nhất của chính nó để so xu
/// hướng; chạm vào một tháng để xem số thật.
class GrowthLineChart extends StatelessWidget {
  const GrowthLineChart({super.key, required this.points});

  final List<MonthlyPoint> points;

  static const accountsColor = Color(0xFF1565C0);
  static const gmvColor = Color(0xFF2E7D32);

  /// `2026-10` → `10/26`.
  static String monthLabel(String month) =>
      '${month.substring(5)}/${month.substring(2, 4)}';

  static List<FlSpot> normalized(List<num> values) {
    final peak = values.fold<num>(0, (a, b) => b > a ? b : a);
    return [
      for (var i = 0; i < values.length; i++)
        FlSpot(i.toDouble(), peak == 0 ? 0 : values[i] / peak),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final hasData = points.any((p) => p.newAccounts > 0 || p.gmv > 0);
    if (points.isEmpty || !hasData) {
      return const SizedBox(
        height: 180,
        child: Center(child: Text('Chưa có dữ liệu tăng trưởng')),
      );
    }
    final scheme = Theme.of(context).colorScheme;
    // Nhãn thưa dần khi có nhiều tháng để không chồng chữ trên màn hình hẹp.
    final labelEvery = (points.length / 6).ceil();
    return Column(
      children: [
        SizedBox(
          height: 220,
          child: LineChart(
            key: const ValueKey('growth-chart'),
            LineChartData(
              minY: 0,
              maxY: 1.1,
              gridData: FlGridData(
                drawVerticalLine: false,
                horizontalInterval: 0.25,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: scheme.outlineVariant.withValues(alpha: 0.5),
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(),
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 1,
                    reservedSize: 28,
                    getTitlesWidget: (value, meta) {
                      final i = value.toInt();
                      if (value != i || i < 0 || i >= points.length) {
                        return const SizedBox.shrink();
                      }
                      if (i % labelEvery != 0) return const SizedBox.shrink();
                      return SideTitleWidget(
                        meta: meta,
                        child: Text(
                          monthLabel(points[i].month),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      );
                    },
                  ),
                ),
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (spots) => [
                    for (final spot in spots)
                      LineTooltipItem(
                        spot.barIndex == 0
                            ? '${monthLabel(points[spot.spotIndex].month)}\n'
                                  '${points[spot.spotIndex].newAccounts} tài khoản mới'
                            : '${formatCompactVnd(points[spot.spotIndex].gmv)} GMV',
                        TextStyle(
                          color: spot.barIndex == 0
                              ? Colors.lightBlue.shade100
                              : Colors.lightGreen.shade100,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              lineBarsData: [
                _line(normalized([for (final p in points) p.newAccounts]), accountsColor),
                _line(normalized([for (final p in points) p.gmv]), gmvColor),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Wrap(
          spacing: 16,
          children: [
            _Legend(color: accountsColor, label: 'Tài khoản mới'),
            _Legend(color: gmvColor, label: 'Dòng tiền GMV'),
          ],
        ),
      ],
    );
  }

  LineChartBarData _line(List<FlSpot> spots, Color color) => LineChartBarData(
    spots: spots,
    isCurved: true,
    curveSmoothness: 0.2,
    preventCurveOverShooting: true,
    color: color,
    barWidth: 3,
    dotData: FlDotData(show: points.length <= 12),
    belowBarData: BarAreaData(
      show: true,
      color: color.withValues(alpha: 0.08),
    ),
  );
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

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
