import 'package:flutter/material.dart';

import '../../../../app/theme/tokens.dart';
import '../../../../app/widgets/photo_empty_state.dart';
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

/// Tông màu, nhãn và icon của từng trạng thái ô; dùng chung cho ô lịch và
/// chú thích. Màu lấy từ theme (`context.fc`), không hard-code.
class SlotStyle {
  const SlotStyle(this.tone, this.label, this.icon);

  final StatusTone tone;
  final String label;
  final IconData icon;

  static SlotStyle of(BuildContext context, CalendarSlot slot) {
    final fc = context.fc;
    return switch (slot.status) {
      CalendarSlotStatus.available => SlotStyle(
        fc.success,
        'Trống',
        Icons.add_circle_outline,
      ),
      CalendarSlotStatus.booked => SlotStyle(fc.danger, 'Đã đặt', Icons.person),
      CalendarSlotStatus.hold => SlotStyle(
        fc.warning,
        'Đang giữ',
        Icons.hourglass_top,
      ),
      CalendarSlotStatus.locked when slot.isPrivateEvent => SlotStyle(
        fc.info,
        'Bao sân',
        Icons.celebration_outlined,
      ),
      CalendarSlotStatus.locked => SlotStyle(
        fc.neutral,
        'Ngừng phục vụ',
        Icons.block,
      ),
      CalendarSlotStatus.expired => SlotStyle(
        fc.neutral,
        'Đã qua',
        Icons.history,
      ),
      CalendarSlotStatus.unknown => SlotStyle(
        fc.neutral,
        'Không rõ',
        Icons.help_outline,
      ),
    };
  }
}

/// Ma trận giờ (hàng) x ngày (cột) của lịch ngày/tuần, đặt trong một thẻ bo
/// góc như các thẻ của mockup. Hàng là hợp các khung giờ của mọi ngày đang
/// xem; ô không có slot ở ngày đó để trống.
class CourtCalendarGrid extends StatelessWidget {
  const CourtCalendarGrid({
    super.key,
    required this.state,
    required this.onCellTap,
  });

  final CourtCalendarState state;
  final void Function(DateTime date, CalendarSlot slot) onCellTap;

  static const double rowHeight = 46;
  static const double timeColumn = 46;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final starts = <int>{
      for (final day in state.days)
        for (final slot in day.slots) slot.startMinute,
    }.toList()..sort();
    if (starts.isEmpty) {
      return const Center(
        child: PhotoEmptyState(
          title: 'Chưa có khung giờ',
          message:
              'Sân chưa có khung giờ nào trong khoảng này.\n'
              'Hãy áp dụng mẫu khung giờ cho sân trước.',
        ),
      );
    }
    final weekMode = state.mode == CalendarMode.week;
    final muted = TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w600,
      color: colors.onSurfaceVariant,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(21),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 10, 6, 8),
              child: Row(
                children: [
                  const SizedBox(width: timeColumn),
                  for (final day in state.days)
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            _weekdayLabels[day.date.weekday - 1],
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: colors.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(formatDay(day.date), style: muted),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Divider(height: 1, color: colors.outlineVariant),
            Expanded(
              child: ListView.builder(
                key: const Key('calendar-rows'),
                padding: const EdgeInsets.only(right: 6, top: 4, bottom: 4),
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
                          style: muted,
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
        ),
      ),
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
    final colors = Theme.of(context).colorScheme;
    final style = SlotStyle.of(context, slot);
    final label = selected ? 'Đã chọn' : style.label;
    final time =
        '${formatMinute(slot.startMinute)}-${formatMinute(slot.endMinute)}';
    final fg = selected ? colors.onPrimary : style.tone.color;
    return Padding(
      padding: const EdgeInsets.all(2),
      child: Semantics(
        button: true,
        selected: selected,
        label: '${formatDay(date)} $time, $label',
        child: Material(
          color: selected ? colors.primary : style.tone.container,
          borderRadius: BorderRadius.circular(Radii.sm),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: Key(
              'cell-${date.toIso8601String().substring(0, 10)}-${slot.startMinute}',
            ),
            onTap: () => onTap(date, slot),
            child: Center(
              child: compact
                  ? Icon(
                      selected ? Icons.check : style.icon,
                      size: 16,
                      color: fg,
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          selected ? Icons.check : style.icon,
                          size: 16,
                          color: fg,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          label,
                          style: TextStyle(
                            color: fg,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
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
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        for (final sample in samples)
          Builder(
            builder: (context) {
              final style = SlotStyle.of(context, sample);
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: style.tone.color,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    style.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: muted,
                    ),
                  ),
                ],
              );
            },
          ),
      ],
    );
  }
}
