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
          appBar: AppBar(
            backgroundColor: palette.background,
            foregroundColor: palette.text,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            toolbarHeight: 72,
            titleSpacing: Navigator.canPop(context) ? 0 : 20,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.branchName != null && widget.branchName!.isNotEmpty)
                  Text(
                    widget.branchName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      height: 18 / 13,
                      fontWeight: FontWeight.w500,
                      color: palette.muted,
                    ),
                  ),
                Text(
                  'Chọn giờ chơi',
                  style: TextStyle(
                    fontSize: 24,
                    height: 32 / 24,
                    fontWeight: FontWeight.w700,
                    color: palette.text,
                  ),
                ),
              ],
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Divider(height: 1, thickness: 1, color: palette.line),
            ),
          ),
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
                    padding: const EdgeInsets.only(top: 16, bottom: 24),
                    children: [
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

class _Filters extends StatelessWidget {
  const _Filters({required this.state, required this.days});
  final SlotPickerState state;
  final List<DateTime> days;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SlotPickerCubit>();
    final multi = state.courts.length > 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SlotSectionLabel(
            'Ngày chơi',
            trailing: 'Tháng ${state.date.month}',
          ),
        ),
        SlotDateStrip(
          days: days,
          selected: state.date,
          today: venueToday(),
          onSelected: cubit.selectDate,
        ),
        if (multi) ...[
          const SizedBox(height: 24),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: SlotSectionLabel('Sân'),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
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
        const SizedBox(height: 24),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: SlotSectionLabel('Thời lượng'),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              for (var i = 0; i < slotDurations.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: SlotPill(
                    label: durationLabel(slotDurations[i]),
                    selected: state.durationMinutes == slotDurations[i],
                    onTap: () => cubit.selectDuration(slotDurations[i]),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SlotShowUnavailableRow(
            value: state.showUnavailable,
            onChanged: cubit.toggleUnavailable,
          ),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
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
                  if (state.courtFilter == null ||
                      state.courtFilter == court.id)
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
      ),
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

/// Solid bottom bar: what is selected, the total, and "Tiếp tục".
class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.state, required this.onContinue});
  final SlotPickerState state;
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    final palette = SlotPickerPalette.of(context);
    final option = state.selectedOption;
    final court = state.selectedCourt;
    final suggested = state.courtFilter == null && state.courts.length > 1;
    final enabled = option != null && !state.loading && onContinue != null;
    return Material(
      color: palette.surface,
      elevation: 0,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: palette.line)),
        ),
        child: SafeArea(
          top: false,
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AnimatedSwitcher(
                      duration: slotMotion(context, 180),
                      transitionBuilder: (child, animation) =>
                          FadeTransition(opacity: animation, child: child),
                      layoutBuilder: (current, previous) => Stack(
                        alignment: Alignment.centerLeft,
                        children: [...previous, ?current],
                      ),
                      child: SizedBox(
                        key: ValueKey(option?.startMinute),
                        height: 44,
                        child: Semantics(
                          liveRegion: true,
                          child: option == null
                              ? Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'Chưa chọn giờ',
                                    style: TextStyle(
                                      fontSize: 14,
                                      height: 20 / 14,
                                      color: palette.muted,
                                    ),
                                  ),
                                )
                              : Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${weekdayShort(state.date)} '
                                            '${slotDayMonth(state.date)} · '
                                            '${slotTime(option.startMinute)} – '
                                            '${slotTime(option.endMinute)}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 15,
                                              height: 20 / 15,
                                              fontWeight: FontWeight.w700,
                                              color: palette.text,
                                            ),
                                          ),
                                          Text(
                                            '${court?.name ?? ''}'
                                            '${suggested ? ' (gợi ý)' : ''}'
                                            ' · ${durationLabel(option.durationMinutes)}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 13,
                                              height: 18 / 13,
                                              color: palette.muted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      slotMoney(option.priceMinor),
                                      style: TextStyle(
                                        fontSize: 20,
                                        height: 28 / 20,
                                        fontWeight: FontWeight.w800,
                                        color: palette.accent,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed: enabled ? onContinue : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: palette.accent,
                          foregroundColor: palette.onAccent,
                          disabledBackgroundColor: palette.accent.withValues(
                            alpha: .38,
                          ),
                          disabledForegroundColor: palette.onAccent.withValues(
                            alpha: .8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          textStyle: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        child: const Text('Tiếp tục'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
