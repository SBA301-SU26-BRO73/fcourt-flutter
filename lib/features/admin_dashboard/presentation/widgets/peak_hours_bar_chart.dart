import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/analytics.dart';

/// Biểu đồ cột số lượt đặt theo giờ (06h -> 23h); giờ vàng đổi sang màu cam.
/// Chạm vào cột để xem số lượt đặt chi tiết.
class PeakHoursBarChart extends StatelessWidget {
  const PeakHoursBarChart({super.key, required this.hours});

  final List<PeakHour> hours;

  static const firstHour = 6;
  static const lastHour = 23;
  static const peakColor = Color(0xFFEF6C00);
  static const normalColor = Color(0xFF1E88E5);

  @override
  Widget build(BuildContext context) {
    final visible = [
      for (final hour in hours)
        if (hour.hour >= firstHour && hour.hour <= lastHour) hour,
    ];
    if (visible.every((h) => h.bookings == 0)) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('Chưa có dữ liệu giờ đặt sân trong kỳ này')),
      );
    }
    final highest = visible.map((h) => h.bookings).reduce(math.max);
    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: highest * 1.2,
          gridData: FlGridData(
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
              color: Theme.of(context).colorScheme.outlineVariant,
              strokeWidth: 0.5,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, meta) {
                  if (value != value.roundToDouble() || value == 0) {
                    return const SizedBox.shrink();
                  }
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(
                      '${value.toInt()}',
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                getTitlesWidget: (value, meta) {
                  final hour = value.toInt();
                  if (hour % 2 != 0) return const SizedBox.shrink();
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(
                      hour.toString().padLeft(2, '0'),
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final item = visible[groupIndex];
                return BarTooltipItem(
                  '${hourRange(item.hour)}\n${item.bookings} lượt đặt'
                  '${item.isPeak ? '\nGiờ cao điểm' : ''}',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                );
              },
            ),
          ),
          barGroups: [
            for (final item in visible)
              BarChartGroupData(
                x: item.hour,
                barRods: [
                  BarChartRodData(
                    toY: item.bookings.toDouble(),
                    color: item.isPeak ? peakColor : normalColor,
                    width: 10,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(3),
                    ),
                  ),
                ],
              ),
          ],
        ),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      ),
    );
  }
}

/// `17` → `"17:00 - 18:00"`.
String hourRange(int hour) =>
    '${hour.toString().padLeft(2, '0')}:00 - '
    '${((hour + 1) % 24).toString().padLeft(2, '0')}:00';
