import 'package:flutter/material.dart';

import '../../../../app/widgets/fc_widgets.dart';
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

  static StatusTone tone(BuildContext context, CourtStatus status) =>
      switch (status) {
        CourtStatus.active => context.fc.success,
        CourtStatus.maintenance => context.fc.warning,
        CourtStatus.inactive => context.fc.neutral,
      };

  @override
  Widget build(BuildContext context) =>
      StatusPill(label(status), tone: tone(context, status));
}
