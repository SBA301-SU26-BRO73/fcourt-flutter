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

/// Uppercase section caption ("NGÀY CHƠI") on a 4-pt rhythm.
class SlotSectionLabel extends StatelessWidget {
  const SlotSectionLabel(this.text, {super.key, this.trailing});
  final String text;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = SlotPickerPalette.of(context);
    final style = TextStyle(
      fontSize: 12,
      height: 16 / 12,
      fontWeight: FontWeight.w700,
      letterSpacing: .8,
      color: palette.muted,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(text.toUpperCase(), style: style)),
          if (trailing != null) Text(trailing!, style: style),
        ],
      ),
    );
  }
}

/// A 48dp-high pill used for courts and durations. The selected state is an
/// accent fill plus a check mark, so color is never the only signal.
class SlotPill extends StatelessWidget {
  const SlotPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.minWidth = 0,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    final palette = SlotPickerPalette.of(context);
    final motion = slotMotion(context, 160);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: AnimatedContainer(
        duration: motion,
        curve: Curves.easeOutCubic,
        constraints: BoxConstraints(minHeight: 48, minWidth: minWidth),
        decoration: BoxDecoration(
          color: selected ? palette.accent : palette.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? palette.accent : palette.line,
            width: 1.5,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedSize(
                    duration: motion,
                    curve: Curves.easeOutCubic,
                    child: selected
                        ? Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Icon(
                              Icons.check_rounded,
                              size: 18,
                              color: palette.onAccent,
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        height: 20 / 14,
                        fontWeight: FontWeight.w700,
                        color: selected ? palette.onAccent : palette.text,
                      ),
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

/// Horizontal strip of days (today + 6). Tiles are 52x64dp.
class SlotDateStrip extends StatefulWidget {
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
  State<SlotDateStrip> createState() => _SlotDateStripState();
}

class _SlotDateStripState extends State<SlotDateStrip> {
  static const _tile = 52.0, _gap = 8.0;
  late final ScrollController _controller;

  @override
  void initState() {
    super.initState();
    final index = widget.days.indexWhere(
      (d) => slotDateKey(d) == slotDateKey(widget.selected),
    );
    _controller = ScrollController(
      initialScrollOffset: index <= 3 ? 0 : (index - 3) * (_tile + _gap),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = SlotPickerPalette.of(context);
    final motion = slotMotion(context, 160);
    return SizedBox(
      height: 68,
      child: ListView.separated(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: widget.days.length,
        separatorBuilder: (_, _) => const SizedBox(width: _gap),
        itemBuilder: (context, index) {
          final day = widget.days[index];
          final selected = slotDateKey(day) == slotDateKey(widget.selected);
          final today = slotDateKey(day) == slotDateKey(widget.today);
          final foreground = selected ? palette.onAccent : palette.text;
          return Semantics(
            button: true,
            selected: selected,
            label:
                '${weekdayLong(day)}, ngày ${day.day} tháng ${day.month}'
                '${today ? ', hôm nay' : ''}',
            excludeSemantics: true,
            onTap: () => widget.onSelected(day),
            child: AnimatedContainer(
              duration: motion,
              curve: Curves.easeOutCubic,
              width: _tile,
              decoration: BoxDecoration(
                color: selected ? palette.accent : palette.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected ? palette.accent : palette.line,
                  width: 1.5,
                ),
              ),
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => widget.onSelected(day),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        weekdayShort(day),
                        style: TextStyle(
                          fontSize: 12,
                          height: 16 / 12,
                          fontWeight: FontWeight.w600,
                          color: selected ? palette.onAccent : palette.muted,
                        ),
                      ),
                      Text(
                        '${day.day}',
                        style: TextStyle(
                          fontSize: 20,
                          height: 24 / 20,
                          fontWeight: FontWeight.w700,
                          color: foreground,
                        ),
                      ),
                      Container(
                        width: 4,
                        height: 4,
                        margin: const EdgeInsets.only(top: 2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: today
                              ? (selected ? palette.onAccent : palette.accent)
                              : Colors.transparent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// "Hiện giờ đã đặt / đã qua" switch row, 56dp high.
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
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Hiện giờ đã đặt / đã qua',
                    style: TextStyle(
                      fontSize: 14,
                      height: 20 / 14,
                      color: palette.muted,
                    ),
                  ),
                ),
                IgnorePointer(
                  child: Switch(
                    value: value,
                    onChanged: (_) {},
                    activeThumbColor: palette.onAccent,
                    activeTrackColor: palette.accent,
                    inactiveThumbColor: palette.muted,
                    inactiveTrackColor: palette.surface,
                    trackOutlineColor: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.selected)
                          ? palette.accent
                          : palette.line,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
