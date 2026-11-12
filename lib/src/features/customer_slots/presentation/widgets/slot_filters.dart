import 'package:flutter/material.dart';

import '../../domain/court_slot.dart';
import '../../../../../app/theme/slot_picker_palette.dart';

const _weekdayShort = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
const _weekdayLong = [
  'Thứ Hai',
  'Thứ Ba',
  'Thứ Tư',
  'Thứ Năm',
  'Thứ Sáu',
  'Thứ Bảy',
  'Chủ nhật',
];

String weekdayShort(DateTime date) => _weekdayShort[date.weekday - 1];
String weekdayLong(DateTime date) => _weekdayLong[date.weekday - 1];
String slotDayMonth(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';

/// Section label (mock-up ".label"): 12/700, 15dp above, 10dp below, with an
/// optional muted note on the right.
class SlotSectionLabel extends StatelessWidget {
  const SlotSectionLabel(this.text, {super.key, this.trailing, this.top = 15});
  final String text;
  final double top;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = SlotPickerPalette.of(context);
    return Padding(
      padding: EdgeInsets.only(top: top, bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: palette.text,
              ),
            ),
          ),
          if (trailing != null)
            Text(
              trailing!,
              style: TextStyle(fontSize: 11, color: palette.muted),
            ),
        ],
      ),
    );
  }
}

/// Pill for courts and durations (mock-up ".pill"): 12/600 text, 11/16
/// padding, soft fill; the selected pill is solid accent. The tap area is
/// 40dp high (the mock-up size).
class SlotPill extends StatelessWidget {
  const SlotPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.minWidth = 0,
    this.expand = false,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final double minWidth;

  /// Fills the width its parent gives (equal-width duration pills).
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final palette = SlotPickerPalette.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: 40, minWidth: minWidth),
          child: Center(
            child: AnimatedContainer(
              duration: slotMotion(context, 160),
              curve: Curves.easeOutCubic,
              width: expand ? double.infinity : null,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              decoration: BoxDecoration(
                color: selected ? palette.accent : palette.surfaceRaised,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: selected ? palette.accent : palette.line,
                ),
              ),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                  color: selected ? palette.onAccent : palette.text,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Seven days in one row (mock-up ".dates"): equal width, 6dp gap, 18dp
/// corners, weekday 10 over day number 17/700.
class SlotDateStrip extends StatelessWidget {
  const SlotDateStrip({
    super.key,
    required this.days,
    required this.selected,
    required this.today,
    required this.onSelected,
  });
  final List<DateTime> days;
  final DateTime selected, today;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    final palette = SlotPickerPalette.of(context);
    final motion = slotMotion(context, 160);
    return Row(
      children: [
        for (var i = 0; i < days.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: Builder(
              builder: (context) {
                final day = days[i];
                final isSelected = slotDateKey(day) == slotDateKey(selected);
                final isToday = slotDateKey(day) == slotDateKey(today);
                return Semantics(
                  button: true,
                  selected: isSelected,
                  label:
                      '${weekdayLong(day)}, ngày ${day.day} tháng ${day.month}'
                      '${isToday ? ', hôm nay' : ''}',
                  excludeSemantics: true,
                  onTap: () => onSelected(day),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onSelected(day),
                    child: AnimatedContainer(
                      duration: motion,
                      curve: Curves.easeOutCubic,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? palette.accent : palette.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isSelected ? palette.accent : palette.line,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            weekdayShort(day),
                            style: TextStyle(
                              fontSize: 10,
                              height: 1.4,
                              color: isSelected
                                  ? palette.onAccent
                                  : palette.muted,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${day.day}',
                            style: TextStyle(
                              fontSize: 17,
                              height: 1.3,
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? palette.onAccent
                                  : palette.text,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

/// "Hiện giờ đã đặt / đã qua" with the small 32x19 switch of the mock-up.
class SlotShowUnavailableRow extends StatelessWidget {
  const SlotShowUnavailableRow({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final bool value;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = SlotPickerPalette.of(context);
    return Semantics(
      container: true,
      toggled: value,
      label: 'Hiện giờ đã đặt hoặc đã qua',
      excludeSemantics: true,
      onTap: onChanged,
      child: InkWell(
        onTap: onChanged,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Hiện giờ đã đặt / đã qua',
                  style: TextStyle(fontSize: 11, color: palette.muted),
                ),
              ),
              AnimatedContainer(
                duration: slotMotion(context, 160),
                width: 32,
                height: 19,
                padding: const EdgeInsets.all(3),
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                decoration: BoxDecoration(
                  color: value ? palette.accent : palette.line,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Container(
                  width: 13,
                  height: 13,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: value ? palette.onAccent : palette.surface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
