import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/court_slot.dart';
import '../domain/slot_invalidations.dart';
import '../domain/slot_options.dart';
import '../domain/slot_repository.dart';
import 'slot_picker_cubit.dart';
import 'widgets/slot_filters.dart';
import 'widgets/slot_lock_contacts.dart';
import 'widgets/slot_option_views.dart';
import '../../../../app/theme/slot_picker_palette.dart';
import '../../../../app/widgets/wp3b_widgets.dart';

/// Start-time picker: day strip, court chips, duration, then the list of free
/// start times grouped by part of the day. Picking a 2-hour game takes three
/// taps (duration, start time, "Tiếp tục").
class SlotPickerScreen extends StatelessWidget {
  const SlotPickerScreen({
    super.key,
    required this.repository,
    required this.courts,
    this.initialCourtId,
    this.branchName,
    this.date,
    this.onContinue,
    this.invalidationsFor,
    this.now,
  });
  final SlotRepository repository;
  final List<PickerCourt> courts;
  final int? initialCourtId;
  final String? branchName;
  final DateTime? date;

  /// Receives the selection and the name of the court it is on.
  final void Function(SlotSelection selection, String courtName)? onContinue;
  final SlotInvalidations Function(int courtId)? invalidationsFor;
  final DateTime Function()? now;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => SlotPickerCubit(
      repository,
      courts: courts,
      initialCourtId: initialCourtId,
      date: date,
      now: now,
      invalidationsFor: invalidationsFor,
    )..refresh(),
    child: _SlotView(branchName: branchName, onContinue: onContinue),
  );
}

class _SlotView extends StatefulWidget {
  const _SlotView({this.branchName, this.onContinue});
  final String? branchName;
  final void Function(SlotSelection selection, String courtName)? onContinue;
  @override
  State<_SlotView> createState() => _SlotViewState();
}

class _SlotViewState extends State<_SlotView> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<SlotPickerCubit>().refresh();
    }
  }

  void _continue(SlotPickerCubit cubit) {
    final selection = cubit.selection;
    final court = cubit.state.selectedCourt;
    if (selection == null || court == null) return;
    widget.onContinue?.call(selection, court.name);
  }

  List<DateTime> _days(SlotPickerState state) {
    final today = venueToday();
    final first =
        state.date.isBefore(today) ||
            state.date.isAfter(today.add(const Duration(days: 6)))
        ? state.date
        : today;
    return [
      for (var i = 0; i < 7; i++)
        DateTime(first.year, first.month, first.day + i),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final palette = SlotPickerPalette.of(context);
    return BlocBuilder<SlotPickerCubit, SlotPickerState>(
      builder: (context, state) {
        final cubit = context.read<SlotPickerCubit>();
        final days = _days(state);
        return Scaffold(
          backgroundColor: palette.background,
          appBar: AppBar(title: const Text('Chọn giờ')),
          body: SafeArea(
            top: false,
            bottom: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: RefreshIndicator(
                  color: palette.accent,
                  backgroundColor: palette.surface,
                  onRefresh: cubit.refresh,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      20,
                      3,
                      20,
                      FloatingBottomBar.clearance + 8,
                    ),
                    children: [
                      if (widget.branchName != null &&
                          widget.branchName!.isNotEmpty)
                        _VenueStrip(
                          name: widget.branchName!,
                          courtCount: state.courts.length,
                        ),
                      _Filters(state: state, days: days),
                      _Results(state: state, days: days),
                    ],
                  ),
                ),
              ),
            ),
          ),
          bottomNavigationBar: _BottomBar(
            state: state,
            onContinue: widget.onContinue == null
                ? null
                : () => _continue(cubit),
          ),
        );
      },
    );
  }
}

/// Branch name with a small photo (mock-up ".venue-strip").
class _VenueStrip extends StatelessWidget {
  const _VenueStrip({required this.name, required this.courtCount});
  final String name;
  final int courtCount;

  @override
  Widget build(BuildContext context) {
    final palette = SlotPickerPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 3, bottom: 12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: const SizedBox(width: 44, height: 38, child: SportPhoto()),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: palette.text,
                  ),
                ),
                if (courtCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      '$courtCount sân',
                      style: TextStyle(fontSize: 11, color: palette.muted),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({required this.state, required this.days});
  final SlotPickerState state;
  final List<DateTime> days;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SlotPickerCubit>();
    final palette = SlotPickerPalette.of(context);
    final multi = state.courts.length > 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SlotSectionLabel(
          'Ngày chơi',
          top: 0,
          trailing: 'Tháng ${state.date.month}, ${state.date.year}',
        ),
        SlotDateStrip(
          days: days,
          selected: state.date,
          today: venueToday(),
          onSelected: cubit.selectDate,
        ),
        if (multi) ...[
          const SlotSectionLabel('Sân'),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                SlotPill(
                  label: 'Tất cả sân',
                  selected: state.courtFilter == null,
                  onTap: () => cubit.selectCourt(null),
                ),
                for (final court in state.courts) ...[
                  const SizedBox(width: 8),
                  SlotPill(
                    label: court.name,
                    selected: state.courtFilter == court.id,
                    onTap: () => cubit.selectCourt(court.id),
                  ),
                ],
              ],
            ),
          ),
        ],
        const SlotSectionLabel('Thời lượng'),
        Row(
          children: [
            for (var i = 0; i < slotDurations.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: SlotPill(
                  expand: true,
                  label: durationLabel(slotDurations[i]),
                  selected: state.durationMinutes == slotDurations[i],
                  onTap: () => cubit.selectDuration(slotDurations[i]),
                ),
              ),
            ],
          ],
        ),
        Divider(height: 12, thickness: 1, color: palette.line),
        SlotShowUnavailableRow(
          value: state.showUnavailable,
          onChanged: cubit.toggleUnavailable,
        ),
      ],
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({required this.state, required this.days});
  final SlotPickerState state;
  final List<DateTime> days;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SlotPickerCubit>();
    final palette = SlotPickerPalette.of(context);
    final Widget content;
    final Object key;
    if (state.loading) {
      key = 'loading';
      content = const SlotListSkeleton();
    } else if (state.error != null) {
      key = 'error';
      content = SlotEmptyState(
        icon: Icons.wifi_off_rounded,
        title: 'Không tải được lịch sân',
        message: state.error,
        actionLabel: 'Thử lại',
        onAction: cubit.refresh,
      );
    } else {
      final options = state.visibleOptions;
      key =
          '${slotDateKey(state.date)}-${state.courtFilter}-'
          '${state.durationMinutes}-${state.showUnavailable}';
      if (options.isEmpty) {
        content = SlotEmptyState(
          icon: Icons.event_busy_rounded,
          title: 'Không còn giờ trống',
          message: state.durationMinutes > 60
              ? 'Thử ngày khác hoặc chọn thời lượng ngắn hơn.'
              : 'Thử xem ngày khác.',
          actionLabel: 'Xem ngày khác',
          onAction: () => cubit.selectNextDay(days),
        );
      } else {
        content = _OptionList(state: state, options: options);
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.notice != null && !state.loading)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Semantics(
              liveRegion: true,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: palette.accentSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 20,
                      color: palette.accent,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        state.notice!,
                        style: TextStyle(
                          fontSize: 14,
                          height: 20 / 14,
                          color: palette.text,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (!state.loading && state.error == null)
          SlotLockContacts(
            slots: [
              for (final court in state.courts)
                if (state.courtFilter == null || state.courtFilter == court.id)
                  ...?state.slotsByCourt[court.id],
            ],
          ),
        AnimatedSwitcher(
          duration: slotMotion(context, 220),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0, .02),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.topCenter,
            children: [
              ...previous.map(
                (w) => Positioned(top: 0, left: 0, right: 0, child: w),
              ),
              ?current,
            ],
          ),
          child: KeyedSubtree(key: ValueKey(key), child: content),
        ),
      ],
    );
  }
}

class _OptionList extends StatelessWidget {
  const _OptionList({required this.state, required this.options});
  final SlotPickerState state;
  final List<StartOption> options;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SlotPickerCubit>();
    final names = {for (final c in state.courts) c.id: c.name};
    final children = <Widget>[];
    DayPart? part;
    for (final option in options) {
      if (option.part != part) {
        part = option.part;
        children.add(SlotGroupHeader(part));
      }
      children.add(
        SlotOptionTile(
          option: option,
          courtNames: [for (final id in option.courtIds) names[id] ?? '#$id'],
          allCourtsCount: state.courtFilter == null ? state.courts.length : 1,
          selected: state.selectedStart == option.startMinute,
          onTap: () => cubit.selectStart(option.startMinute),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

/// Floating total (mock-up ".floating-total"): solid indigo (lime in dark)
/// bar, 28dp corners. One line with the time range, court and price; the day
/// below; "Tiếp tục" on the right.
class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.state, required this.onContinue});
  final SlotPickerState state;
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bar = dark ? colors.primary : colors.onPrimaryContainer;
    final ink = dark ? colors.onPrimary : Colors.white;
    final option = state.selectedOption;
    final court = state.selectedCourt;
    final suggested = state.courtFilter == null && state.courts.length > 1;
    final enabled = option != null && !state.loading && onContinue != null;
    final line1 = option == null
        ? 'Chưa chọn giờ'
        : '${slotTime(option.startMinute)}–${slotTime(option.endMinute)}'
              ' · ${court?.name ?? ''} · ${slotMoney(option.priceMinor)}';
    final line2 = option == null
        ? 'Chọn một khung giờ trống'
        : '${weekdayLong(state.date)}, ${slotDayMonth(state.date)}'
              '${suggested ? ' · gợi ý ${court?.name ?? ''}' : ''}';
    return SafeArea(
      top: false,
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Semantics(
              button: true,
              enabled: enabled,
              label: 'Tiếp tục',
              child: Opacity(
                opacity: enabled ? 1 : .6,
                child: Material(
                  color: bar,
                  borderRadius: BorderRadius.circular(28),
                  clipBehavior: Clip.antiAlias,
                  elevation: 0,
                  child: InkWell(
                    onTap: enabled ? onContinue : null,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(19, 17, 19, 17),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  line1,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: ink,
                                    fontSize: 12,
                                    height: 1.3,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  line2,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: ink.withValues(alpha: .85),
                                    fontSize: 11,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Tiếp tục',
                            style: TextStyle(
                              color: ink,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Icon(Icons.arrow_forward, size: 15, color: ink),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
