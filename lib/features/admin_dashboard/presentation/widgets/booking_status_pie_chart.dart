import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/dashboard_stats.dart';

/// Vòng tròn trạng thái đặt sân (mockup 06): vòng 112 với lỗ 78 ghi tổng số
/// đơn, bên phải là chú giải Đã xác nhận / Chờ duyệt / Đã hủy.
class BookingStatusPieChart extends StatelessWidget {
  const BookingStatusPieChart({super.key, required this.counts});

  final BookingStatusCounts counts;

  static const confirmedColor = Color(0xFF7869EC);
  static const pendingColor = Color(0xFF75CBAA);
  static const cancelledColor = Color(0xFFD9DEEA);

  List<(String, int, Color)> get _entries => [
    ('Đã xác nhận', counts.confirmed, confirmedColor),
    ('Chờ duyệt', counts.pending, pendingColor),
    ('Đã hủy', counts.cancelled, cancelledColor),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final total = counts.total;
    return Row(
      children: [
        SizedBox(
          width: 112,
          height: 112,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  centerSpaceRadius: 39,
                  sectionsSpace: 0,
                  startDegreeOffset: -90,
                  sections: [
                    if (total == 0)
                      PieChartSectionData(
                        value: 1,
                        color: colors.surfaceContainerHighest,
                        radius: 17,
                        showTitle: false,
                      )
                    else
                      for (final (_, value, color) in _entries)
                        if (value > 0)
                          PieChartSectionData(
                            value: value.toDouble(),
                            color: color,
                            radius: 17,
                            showTitle: false,
                          ),
                  ],
                ),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$total',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                      color: colors.onSurface,
                    ),
                  ),
                  Text(
                    'đơn đặt',
                    style: TextStyle(
                      fontSize: 9,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Column(
            children: [
              for (final (label, value, color) in _entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 10,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Text(
                        '$value',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: colors.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
