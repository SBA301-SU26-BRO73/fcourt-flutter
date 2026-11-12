import 'package:flutter/material.dart';

import '../../domain/entities/slot_template.dart';
import 'facility_formatters.dart';

/// Lưới xem trước toàn bộ slot trong ngày kèm giá (SCRUM-19).
///
/// Dùng sliver để cuộn chung với form phía trên.
class SlotMatrixPreview extends StatelessWidget {
  const SlotMatrixPreview({super.key, required this.slots});

  final List<GeneratedSlot> slots;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SliverGrid.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 130,
        mainAxisExtent: 64,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: slots.length,
      itemBuilder: (context, index) {
        final slot = slots[index];
        return Container(
          key: Key('slot-${slot.startTime.format()}'),
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${slot.startTime.format()}–${slot.endTime.format()}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
              Text(
                formatVnd(slot.price),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: scheme.primary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
