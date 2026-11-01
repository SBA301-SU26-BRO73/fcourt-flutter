import 'package:flutter/material.dart';

import '../../domain/entities/court.dart';

/// Nhãn trạng thái sân: Hoạt động (xanh) / Bảo trì (vàng) / Đang đóng (xám).
class CourtStatusBadge extends StatelessWidget {
  const CourtStatusBadge(this.status, {super.key});

  final CourtStatus status;

  static String label(CourtStatus status) => switch (status) {
    CourtStatus.active => 'Hoạt động',
    CourtStatus.maintenance => 'Bảo trì',
    CourtStatus.inactive => 'Đang đóng',
  };

  static Color color(CourtStatus status) => switch (status) {
    CourtStatus.active => const Color(0xFF2E7D32),
    CourtStatus.maintenance => const Color(0xFFF9A825),
    CourtStatus.inactive => const Color(0xFF757575),
  };

  @override
  Widget build(BuildContext context) {
    final color = CourtStatusBadge.color(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        label(status),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
