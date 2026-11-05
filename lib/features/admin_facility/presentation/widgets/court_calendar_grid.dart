import 'package:flutter/material.dart';

import '../../domain/entities/calendar_slot.dart';
import '../bloc/court_calendar_bloc.dart';

const _weekdayLabels = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

/// "07:30"; phút 1440 (nửa đêm hết ngày) hiển thị 00:00.
String formatMinute(int minute) {
  final m = minute % 1440;
  return '${(m ~/ 60).toString().padLeft(2, '0')}:'
      '${(m % 60).toString().padLeft(2, '0')}';
}

String formatDay(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';

/// Màu và nhãn của từng trạng thái ô, dùng chung cho ô lịch và chú thích.
class SlotStyle {
  const SlotStyle(this.color, this.label, this.icon);

  final Color color;
  final String label;
  final IconData icon;

  static const eventColor = Color(0xFF4648D4);
  static const serviceColor = Color(0xFF705A7B);

  static SlotStyle of(CalendarSlot slot) => switch (slot.status) {
    CalendarSlotStatus.available => const SlotStyle(
      Color(0xFF1B7F4B),
      'Trống',
      Icons.add_circle_outline,
    ),
    CalendarSlotStatus.booked => const SlotStyle(
      Color(0xFFB3261E),
      'Đã đặt',
      Icons.person,
    ),
    CalendarSlotStatus.hold => const SlotStyle(
      Color(0xFFB26A00),
      'Đang giữ',
      Icons.hourglass_top,
    ),
    CalendarSlotStatus.locked when slot.isPrivateEvent => const SlotStyle(
      eventColor,
      'Bao sân',
      Icons.celebration_outlined,
    ),
    CalendarSlotStatus.locked => const SlotStyle(
      serviceColor,
      'Ngừng phục vụ',
      Icons.block,
    ),
    CalendarSlotStatus.expired => const SlotStyle(
      Color(0xFF8A8F8D),
      'Đã qua',
      Icons.history,
    ),
    CalendarSlotStatus.unknown => const SlotStyle(
      Color(0xFF8A8F8D),
      'Không rõ',
      Icons.help_outline,
    ),
  };
}

/// Ma trận giờ (hàng) x ngày (cột) của lịch ngày/tuần. Hàng là hợp các khung giờ
/// của mọi ngày đang xem; ô không có slot ở ngày đó để trống.
class CourtCalendarGrid extends StatelessWidget {
  const CourtCalendarGrid({
    super.key,
    required this.state,
    required this.onCellTap,
  });

  final CourtCalendarState state;
  final void Function(DateTime date, CalendarSlot slot) onCellTap;

  static const double rowHeight = 44;
  static const double timeColumn = 46;

  @override
  Widget build(BuildContext context) {
    final starts = <int>{
      for (final day in state.days)
        for (final slot in day.slots) slot.startMinute,
    }.toList()..sort();
    if (starts.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Sân chưa có khung giờ nào trong khoảng này.\n'
            'Hãy áp dụng mẫu khung giờ cho sân trước.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final weekMode = state.mode == CalendarMode.week;
    return Column(
      children: [
        Row(
          children: [
            const SizedBox(width: timeColumn),
            for (final day in state.days)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    children: [
                      Text(
                        _weekdayLabels[day.date.weekday - 1],
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      Text(
                        formatDay(day.date),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            key: const Key('calendar-rows'),
            itemCount: starts.length,
            itemExtent: rowHeight,
            itemBuilder: (context, index) {
              final start = starts[index];
              return Row(
                children: [
                  SizedBox(
                    width: timeColumn,
                    child: Text(
                      formatMinute(start),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  for (final day in state.days)
                    Expanded(
                      child: _Cell(
                        date: day.date,
                        slot: day.slotAt(start),
                        selected: state.selected.contains(
                          CellKey(day.date, start),
                        ),
                        compact: weekMode,
                        onTap: onCellTap,
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.date,
    required this.slot,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  final DateTime date;
  final CalendarSlot? slot;
  final bool selected;
  final bool compact;
  final void Function(DateTime date, CalendarSlot slot) onTap;

  @override
  Widget build(BuildContext context) {
    final slot = this.slot;
    if (slot == null) return const SizedBox.shrink();
    final style = SlotStyle.of(slot);
    final label = selected ? 'Đã chọn' : style.label;
    final time = '${formatMinute(slot.startMinute)}-${formatMinute(slot.endMinute)}';
    return Padding(
      padding: const EdgeInsets.all(1.5),
      child: Semantics(
        button: true,
        selected: selected,
        label: '${formatDay(date)} $time, $label',
        child: InkWell(
          key: Key('cell-${date.toIso8601String().substring(0, 10)}-${slot.startMinute}'),
          borderRadius: BorderRadius.circular(6),
          onTap: () => onTap(date, slot),
          child: Ink(
            decoration: BoxDecoration(
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : style.color.withValues(
                      alpha: slot.status == CalendarSlotStatus.available ? 0.10 : 0.22,
                    ),
              border: Border.all(
                color: selected
                    ? Theme.of(context).colorScheme.primary
                    : style.color.withValues(alpha: 0.7),
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: compact
                  ? Icon(
                      selected ? Icons.check : style.icon,
                      size: 16,
                      color: selected ? Colors.white : style.color,
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          selected ? Icons.check : style.icon,
                          size: 16,
                          color: selected ? Colors.white : style.color,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          label,
                          style: TextStyle(
                            color: selected ? Colors.white : style.color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class CalendarLegend extends StatelessWidget {
  const CalendarLegend({super.key});

  @override
  Widget build(BuildContext context) {
    const samples = [
      CalendarSlot(
        startMinute: 0,
        endMinute: 30,
        status: CalendarSlotStatus.available,
      ),
      CalendarSlot(
        startMinute: 0,
        endMinute: 30,
        status: CalendarSlotStatus.booked,
      ),
      CalendarSlot(
        startMinute: 0,
        endMinute: 30,
        status: CalendarSlotStatus.hold,
      ),
      CalendarSlot(
        startMinute: 0,
        endMinute: 30,
        status: CalendarSlotStatus.locked,
      ),
      CalendarSlot(
        startMinute: 0,
        endMinute: 30,
        status: CalendarSlotStatus.locked,
        isPrivateEvent: true,
      ),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Wrap(
        spacing: 14,
        runSpacing: 4,
        children: [
          for (final sample in samples)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  SlotStyle.of(sample).icon,
                  size: 14,
                  color: SlotStyle.of(sample).color,
                ),
                const SizedBox(width: 4),
                Text(
                  SlotStyle.of(sample).label,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
        ],
      ),
    );
  }
}
