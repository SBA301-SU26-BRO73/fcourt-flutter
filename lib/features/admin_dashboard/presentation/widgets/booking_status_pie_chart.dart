import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/dashboard_stats.dart';

/// Biểu đồ tròn trạng thái đặt sân: Đã xác nhận / Chờ duyệt / Đã hủy.
class BookingStatusPieChart extends StatelessWidget {
  const BookingStatusPieChart({super.key, required this.counts});

  final BookingStatusCounts counts;

  static const confirmedColor = Color(0xFF2E7D32);
  static const pendingColor = Color(0xFFF9A825);
  static const cancelledColor = Color(0xFFC62828);

  List<(String, int, Color)> get _entries => [
    ('Đã xác nhận', counts.confirmed, confirmedColor),
    ('Chờ duyệt', counts.pending, pendingColor),
    ('Đã hủy', counts.cancelled, cancelledColor),
  ];

  @override
  Widget build(BuildContext context) {
    final total = counts.total;
    return Column(
      children: [
        SizedBox(
          height: 180,
          child: total == 0
              ? const Center(child: Text('Chưa có lượt đặt sân'))
              : PieChart(
                  PieChartData(
                    centerSpaceRadius: 40,
                    sectionsSpace: 2,
                    sections: [
                      for (final (_, value, color) in _entries)
                        if (value > 0)
                          PieChartSectionData(
                            value: value.toDouble(),
                            color: color,
                            radius: 50,
                            title: '${(value * 100 / total).round()}%',
                            titleStyle: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                    ],
                  ),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutCubic,
                ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (final (label, value, color) in _entries)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text('$label: $value'),
                ],
              ),
          ],
        ),
      ],
    );
  }
}
