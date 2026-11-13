import 'package:flutter/material.dart';

import '../../domain/slot_options.dart';
import '../../../../../app/theme/slot_picker_palette.dart';

/// One start time (mock-up ".slot"): 16dp corners, 11/14 padding, time 13/700
/// over a 10dp note; price 12/800 accent on the right. The selected row has
/// an accent border, a soft fill and a check mark instead of the price.
class SlotOptionTile extends StatelessWidget {
  const SlotOptionTile({
    super.key,
    required this.option,
    required this.courtNames,
    required this.allCourtsCount,
    required this.selected,
    required this.onTap,
  });
  final StartOption option;

  /// Names of the courts free at this start, in branch order.
  final List<String> courtNames;
  final int allCourtsCount;
  final bool selected;
  final VoidCallback onTap;

  String get _range =>
      '${slotTime(option.startMinute)}–${slotTime(option.endMinute)}';

  String get _subtitle {
    if (!option.available) return option.blockedLabel ?? 'Không khả dụng';
    if (allCourtsCount == 1) return 'Còn trống';
    if (courtNames.length == allCourtsCount && allCourtsCount > 3) {
      return 'Cả $allCourtsCount sân còn trống';
    }
    final shown = courtNames.take(3).join(', ');
    final more = courtNames.length > 3 ? ' +${courtNames.length - 3}' : '';
    return 'Còn $shown$more';
  }

  @override
  Widget build(BuildContext context) {
    final palette = SlotPickerPalette.of(context);
    final enabled = option.available;
    return Semantics(
      button: enabled,
      enabled: enabled,
      selected: selected,
      label:
          '$_range, $_subtitle'
          '${enabled ? ', ${slotMoney(option.priceMinor)}' : ''}',
      excludeSemantics: true,
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: slotMotion(context, 180),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.only(bottom: 7),
        decoration: BoxDecoration(
          color: selected ? palette.accentSoft : palette.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? palette.accent : palette.line),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _range,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: enabled ? palette.text : palette.muted,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          selected ? '$_subtitle · Đã chọn' : _subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 10, color: palette.muted),
                        ),
                      ],
                    ),
                  ),
                  if (selected)
                    Icon(Icons.check_rounded, size: 20, color: palette.accent)
                  else if (enabled)
                    Text(
                      slotMoney(option.priceMinor),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: palette.accent,
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

/// "Sáng / Chiều / Tối" (mock-up ".period"): small icon + 12/700 label.
class SlotGroupHeader extends StatelessWidget {
  const SlotGroupHeader(this.part, {super.key});
  final DayPart part;

  @override
  Widget build(BuildContext context) {
    final palette = SlotPickerPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Row(
        children: [
          Icon(
            switch (part) {
              DayPart.morning => Icons.wb_sunny_outlined,
              DayPart.afternoon => Icons.wb_twilight_outlined,
              DayPart.evening => Icons.nightlight_outlined,
            },
            size: 15,
            color: palette.muted,
          ),
          const SizedBox(width: 6),
          Text(
            part.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: palette.text,
            ),
          ),
        ],
      ),
    );
  }
}

/// Pulsing placeholder rows shown while the schedules load.
class SlotListSkeleton extends StatefulWidget {
  const SlotListSkeleton({super.key});

  @override
  State<SlotListSkeleton> createState() => _SlotListSkeletonState();
}

class _SlotListSkeletonState extends State<SlotListSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = SlotPickerPalette.of(context);
    final still = MediaQuery.disableAnimationsOf(context);
    Widget bar(double width, double height) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: palette.line,
        borderRadius: BorderRadius.circular(6),
      ),
    );
    Widget row() => Container(
      height: 58,
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.line),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: palette.line,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [bar(120, 16), const SizedBox(height: 6), bar(80, 12)],
          ),
          const Spacer(),
          bar(64, 16),
        ],
      ),
    );
    return Semantics(
      label: 'Đang tải giờ trống',
      liveRegion: true,
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) => Opacity(
            opacity: still ? .7 : .45 + .5 * _controller.value,
            child: child,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 8),
                child: bar(48, 16),
              ),
              for (var i = 0; i < 5; i++) row(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Empty or error state with an action button.
class SlotEmptyState extends StatelessWidget {
  const SlotEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    required this.actionLabel,
    required this.onAction,
  });
  final IconData icon;
  final String title, actionLabel;
  final String? message;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final palette = SlotPickerPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: palette.accentSoft,
            ),
            child: Icon(icon, size: 32, color: palette.accent),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              height: 24 / 18,
              fontWeight: FontWeight.w700,
              color: palette.text,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 4),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 20 / 14,
                color: palette.muted,
              ),
            ),
          ],
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: onAction,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(160, 48),
              foregroundColor: palette.accent,
              side: BorderSide(color: palette.accent, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              textStyle: Theme.of(context).textTheme.labelLarge
                  ?.copyWith(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}
