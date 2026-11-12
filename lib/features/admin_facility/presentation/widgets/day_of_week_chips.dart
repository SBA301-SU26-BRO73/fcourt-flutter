import 'package:flutter/material.dart';

import '../../../../app/theme/tokens.dart';

/// Bảy ô chọn thứ trong một hàng (CN, T2 ... T7), dùng chung cho mẫu khung giờ
/// và hộp áp dụng mẫu cho nhiều sân.
class DayOfWeekChips extends StatelessWidget {
  const DayOfWeekChips({
    super.key,
    required this.selected,
    required this.onToggle,
    this.keyPrefix,
  });

  static const labels = ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'];

  final Set<int> selected;

  /// `null` vô hiệu hóa các ô.
  final ValueChanged<int>? onToggle;
  final String? keyPrefix;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (var day = 0; day < 7; day++)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Gap.xs / 2),
            child: FilterChip(
              key: keyPrefix == null ? null : Key('$keyPrefix-$day'),
              showCheckmark: false,
              padding: EdgeInsets.zero,
              labelPadding: EdgeInsets.zero,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              label: SizedBox(
                width: double.infinity,
                child: Text(labels[day], textAlign: TextAlign.center),
              ),
              selected: selected.contains(day),
              onSelected: onToggle == null ? null : (_) => onToggle!(day),
            ),
          ),
        ),
    ],
  );
}
