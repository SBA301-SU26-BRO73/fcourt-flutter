import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../domain/court_slot.dart';

String slotTime(int minute) =>
    '${((minute ~/ 60) % 24).toString().padLeft(2, '0')}:'
    '${(minute % 60).toString().padLeft(2, '0')}';
String slotMoney(int minor) =>
    '${NumberFormat('#,##0.##', 'vi').format(minor / 100)} đ';

extension SlotAppearance on SlotStatus {
  String get label => switch (this) {
    SlotStatus.available => 'Trống',
    SlotStatus.booked => 'Đã đặt',
    SlotStatus.hold => 'Đang giữ',
    SlotStatus.outOfService => 'Ngừng phục vụ',
    SlotStatus.privateEvent => 'Bao sân',
    SlotStatus.expired => 'Đã qua',
    SlotStatus.unknown => 'Không khả dụng',
  };
  Color get color => switch (this) {
    SlotStatus.available => const Color(0xFF176B3A),
    SlotStatus.booked => const Color(0xFFAB2929),
    SlotStatus.hold => const Color(0xFF965000),
    SlotStatus.outOfService => const Color(0xFF3C6E8F),
    SlotStatus.privateEvent => const Color(0xFF7B3FA0),
    _ => const Color(0xFF646B69),
  };

  String? get unavailableReason => switch (this) {
    SlotStatus.available => null,
    SlotStatus.booked => 'Khung giờ này đã có người đặt.',
    SlotStatus.hold => 'Khung giờ đang được giữ chỗ, hiện chưa thể chọn.',
    SlotStatus.outOfService => 'Khung giờ bị khóa và không nhận đặt lẻ.',
    SlotStatus.expired => 'Khung giờ đã bắt đầu hoặc đã qua, không thể đặt.',
    SlotStatus.unknown => 'Khung giờ không khả dụng, không thể chọn.',
  };
}

extension RestrictedSlotAppearance on CourtSlot {
  bool get isPrivateEvent =>
      status == SlotStatus.outOfService && restriction?.isPrivateEvent == true;
  String get displayLabel => isPrivateEvent ? 'Bao sân' : status.label;
  Color get displayColor =>
      isPrivateEvent ? const Color(0xFF4648D4) : status.color;
  String? get unavailableReason {
    final reason = isPrivateEvent
        ? 'Khung giờ đã được bao sân cho sự kiện, không nhận đặt lẻ.'
        : status.unavailableReason;
    final publicReason = status == SlotStatus.outOfService
        ? restriction?.publicReason
        : null;
    return publicReason == null ? reason : '$reason $publicReason';
  }
}

/// Touch-sized adaptation of React CourtAvailabilityGrid for one real court.
class SlotGridPicker extends StatelessWidget {
  const SlotGridPicker({
    super.key,
    required this.slots,
    required this.selectedIds,
    required this.onToggle,
  });
  final List<CourtSlot> slots;
  final Set<int> selectedIds;
  final bool Function(int) onToggle;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = (constraints.maxWidth / 112).floor().clamp(2, 6);
      final width = (constraints.maxWidth - (columns - 1) * 8) / columns;
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final slot in slots)
            SizedBox(
              width: width,
              child: _SlotCell(
                key: ValueKey('slot-${slot.id}'),
                slot: slot,
                selected:
                    slot.status == SlotStatus.available &&
                    selectedIds.contains(slot.id),
                onTap: () {
                  if (onToggle(slot.id)) HapticFeedback.selectionClick();
                },
              ),
            ),
        ],
      );
    },
  );
}

class _SlotCell extends StatelessWidget {
  const _SlotCell({
    super.key,
    required this.slot,
    required this.selected,
    required this.onTap,
  });
  final CourtSlot slot;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = slot.status == SlotStatus.available;
    final color = slot.displayColor;
    final label = selected ? 'Đã chọn' : slot.displayLabel;
    final time = '${slotTime(slot.startMinute)}–${slotTime(slot.endMinute)}';
    final cell = Semantics(
      container: true,
      button: true,
      enabled: enabled,
      selected: selected,
      hint: slot.unavailableReason,
      label:
          '$time${slot.endMinute == 1440 ? ', kết thúc ngày tiếp theo' : ''}, '
          '${slotMoney(slot.priceMinor)}, $label',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: selected ? null : color.withValues(alpha: .09),
            gradient: selected
                ? const LinearGradient(
                    colors: [Color(0xFF4648D4), Color(0xFF006C49)],
                  )
                : null,
            border: Border.all(
              color: selected
                  ? Colors.transparent
                  : color.withValues(alpha: .4),
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: enabled ? onTap : null,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 108),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 6,
                ),
                child: DefaultTextStyle.merge(
                  style: TextStyle(color: selected ? Colors.white : color),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        time,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Icon(
                        selected
                            ? Icons.check_circle
                            : enabled
                            ? Icons.add_circle_outline
                            : slot.isPrivateEvent
                            ? Icons.celebration_outlined
                            : slot.status == SlotStatus.outOfService
                            ? Icons.block
                            : Icons.lock_outline,
                        size: 20,
                        color: selected ? Colors.white : color,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 11),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        slotMoney(slot.priceMinor),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final reason = slot.unavailableReason;
    return reason == null
        ? cell
        : Tooltip(message: reason, excludeFromSemantics: true, child: cell);
  }
}

class SlotLegend extends StatelessWidget {
  const SlotLegend({super.key});
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 16,
    runSpacing: 10,
    children: [
      const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.celebration_outlined, size: 14, color: Color(0xFF4648D4)),
          SizedBox(width: 5),
          Text('Bao sân'),
        ],
      ),
      for (final status in SlotStatus.values.where(
        (s) => s != SlotStatus.unknown,
      ))
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.circle, size: 10, color: status.color),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                status.label,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
          ],
        ),
    ],
  );
}
