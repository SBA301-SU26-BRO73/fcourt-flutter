import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/analytics.dart';
import 'compact_currency.dart';
import '../../../../app/widgets/fc_widgets.dart';

/// Biểu đồ đường doanh thu theo ngày/tuần/tháng. Chạm vào một điểm để xem số
/// tiền chi tiết trong tooltip.
class RevenueLineChart extends StatelessWidget {
  const RevenueLineChart({super.key, required this.chart});

  final RevenueChart chart;

  static const lineColor = ChartColors.accent;

  @override
  Widget build(BuildContext context) {
    final points = chart.points;
    if (points.isEmpty || chart.totalRevenue == 0) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('Chưa có doanh thu trong khoảng này')),
      );
    }
    final scheme = Theme.of(context).colorScheme;
    final highest = points.map((p) => p.revenue).reduce(math.max);
    final labelEvery = math.max(1, (points.length / 5).ceil());
    return SizedBox(
      height: 220,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: highest * 1.15,
          minX: 0,
          maxX: math.max(1, points.length - 1).toDouble(),
          gridData: FlGridData(
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: scheme.outlineVariant, strokeWidth: 0.5),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 56,
                getTitlesWidget: (value, meta) {
                  if (value == meta.min || value == meta.max) {
                    return const SizedBox.shrink();
                  }
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(
                      formatCompactVnd(value),
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                reservedSize: 28,
                getTitlesWidget: (value, meta) {
                  final index = value.round();
                  if (value != index.toDouble() ||
                      index < 0 ||
                      index >= points.length ||
                      index % labelEvery != 0) {
                    return const SizedBox.shrink();
                  }
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(
                      shortPeriodLabel(chart.granularity, points[index]),
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            handleBuiltInTouches: true,
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => [
                for (final spot in spots)
                  LineTooltipItem(
                    '${fullPeriodLabel(chart.granularity, points[spot.x.round()])}\n'
                    '${formatFullVnd(points[spot.x.round()].revenue)}',
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (var i = 0; i < points.length; i++)
                  FlSpot(i.toDouble(), points[i].revenue.toDouble()),
              ],
              isCurved: false,
              color: lineColor,
              barWidth: 3,
              dotData: FlDotData(show: points.length <= 14),
              belowBarData: BarAreaData(
                show: true,
                color: lineColor.withValues(alpha: 0.12),
              ),
            ),
          ],
        ),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      ),
    );
  }
}

String _two(int value) => value.toString().padLeft(2, '0');

String _dayMonth(DateTime date) => '${_two(date.day)}/${_two(date.month)}';

/// Nhãn ngắn dưới trục hoành: `05/11` (ngày, tuần) hoặc `11/26` (tháng).
String shortPeriodLabel(
  RevenueGranularity granularity,
  RevenuePoint point,
) => switch (granularity) {
  RevenueGranularity.month =>
    '${_two(point.periodStart.month)}/${_two(point.periodStart.year % 100)}',
  _ => _dayMonth(point.periodStart),
};

/// Nhãn đầy đủ trong tooltip.
String fullPeriodLabel(RevenueGranularity granularity, RevenuePoint point) =>
    switch (granularity) {
      RevenueGranularity.day =>
        '${_dayMonth(point.periodStart)}/${point.periodStart.year}',
      RevenueGranularity.week =>
        '${_dayMonth(point.periodStart)} - ${_dayMonth(point.periodEnd)}',
      RevenueGranularity.month =>
        'Tháng ${point.periodStart.month}/${point.periodStart.year}',
    };
