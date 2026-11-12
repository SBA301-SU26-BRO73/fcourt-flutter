import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../domain/court_slot.dart';
import '../domain/slot_invalidations.dart';
import '../domain/slot_options.dart';
import '../domain/slot_repository.dart';

class SlotPickerState {
  SlotPickerState({
    required this.date,
    required this.courts,
    this.slotsByCourt = const {},
    this.courtFilter,
    this.durationMinutes = 60,
    this.showUnavailable = false,
    this.selectedStart,
    this.loading = true,
    this.error,
    this.notice,
  });

  final DateTime date;
  final List<PickerCourt> courts;
  final Map<int, List<CourtSlot>> slotsByCourt;

  /// Null means "Tất cả sân": the picker suggests a free court by itself.
  final int? courtFilter;
  final int durationMinutes;
  final bool showUnavailable;
  final int? selectedStart;
  final bool loading;
  final String? error, notice;

  late final List<StartOption> options = buildStartOptions(
    courts: courts,
    slotsByCourt: slotsByCourt,
    courtFilter: courtFilter,
    durationMinutes: durationMinutes,
  );

  /// Options the list shows: free ones, plus blocked ones on request.
  List<StartOption> get visibleOptions =>
      showUnavailable ? options : options.where((o) => o.available).toList();

  int get availableCount => options.where((o) => o.available).length;

  StartOption? get selectedOption {
    for (final o in options) {
      if (o.startMinute == selectedStart && o.available) return o;
    }
    return null;
  }

  PickerCourt? get selectedCourt {
    final id = selectedOption?.suggestedCourtId;
    return courts.where((c) => c.id == id).firstOrNull;
  }

  int get totalMinor => selectedOption?.priceMinor ?? 0;

  SlotPickerState copyWith({
    DateTime? date,
    Map<int, List<CourtSlot>>? slotsByCourt,
    Object? courtFilter = _keep,
    int? durationMinutes,
    bool? showUnavailable,
    Object? selectedStart = _keep,
    bool? loading,
    Object? error = _keep,
    Object? notice = _keep,
  }) => SlotPickerState(
    date: date ?? this.date,
    courts: courts,
    slotsByCourt: slotsByCourt ?? this.slotsByCourt,
    courtFilter: identical(courtFilter, _keep)
        ? this.courtFilter
        : courtFilter as int?,
    durationMinutes: durationMinutes ?? this.durationMinutes,
    showUnavailable: showUnavailable ?? this.showUnavailable,
    selectedStart: identical(selectedStart, _keep)
        ? this.selectedStart
        : selectedStart as int?,
    loading: loading ?? this.loading,
    error: identical(error, _keep) ? this.error : error as String?,
    notice: identical(notice, _keep) ? this.notice : notice as String?,
  );

  static const _keep = Object();
}

/// Drives the start-time picker: one schedule per court of the branch, merged
/// into start times for the chosen duration. Realtime invalidations and a slow
/// poll keep the schedules fresh (SCRUM-108).
class SlotPickerCubit extends Cubit<SlotPickerState> {
  SlotPickerCubit(
    this.repository, {
    required List<PickerCourt> courts,
    int? initialCourtId,
    DateTime? date,
    DateTime Function()? now,
    SlotInvalidations Function(int courtId)? invalidationsFor,
    this.pollInterval = const Duration(seconds: 15),
    this.healthyPollFactor = 4,
  }) : assert(courts.isNotEmpty),
       _now = now ?? DateTime.now,
       super(
         SlotPickerState(
           date: date ?? venueToday(now?.call()),
           courts: List.unmodifiable(courts),
           courtFilter: courts.any((c) => c.id == initialCourtId)
               ? initialCourtId
               : null,
         ),
       ) {
    if (invalidationsFor != null) {
      for (final court in courts) {
        final source = invalidationsFor(court.id);
        _invalidations.add(source);
        _subscriptions.add(
          source.changes.listen((change) {
            if (change == null || change.date == slotDateKey(state.date)) {
              _resync();
            }
          }),
        );
      }
    }
    // Redis Pub/Sub is not durable, so even a healthy socket is reconciled,
    // just less often (pollInterval * healthyPollFactor).
    _poll = Timer.periodic(pollInterval, (_) {
      if (_invalidations.isNotEmpty &&
          _invalidations.every((i) => i.connected) &&
          ++_quietTicks < healthyPollFactor) {
        return;
      }
      _quietTicks = 0;
      _resync();
    });
    _expiry = Timer.periodic(
      const Duration(seconds: 15),
      (_) => expirePastSlots(),
    );
  }

  final SlotRepository repository;
  final Duration pollInterval;
  final int healthyPollFactor;
  final DateTime Function() _now;
  final List<SlotInvalidations> _invalidations = [];
  final List<StreamSubscription<SlotChange?>> _subscriptions = [];
  late final Timer _poll, _expiry;
  int _quietTicks = 0, _revision = 0;
  bool _resyncBusy = false, _resyncAgain = false;

  Future<void> _resync() async {
    if (isClosed) return;
    if (_resyncBusy || state.loading) {
      _resyncAgain = true;
      return;
    }
    _resyncBusy = true;
    try {
      do {
        _resyncAgain = false;
        await _load(null, silent: true);
      } while (_resyncAgain && !isClosed && !state.loading);
    } finally {
      _resyncBusy = false;
    }
  }

  /// Reloads the schedules of every court for [date] (default: current day).
  Future<void> refresh([DateTime? date]) async {
    await _load(date);
    if (_resyncAgain && !isClosed) await _resync();
  }

  Future<void> _load(DateTime? date, {bool silent = false}) async {
    final revision = ++_revision;
    final nextDate = date ?? state.date;
    final sameDay = slotDateKey(nextDate) == slotDateKey(state.date);
    if (!silent) {
      emit(
        state.copyWith(
          date: nextDate,
          slotsByCourt: const {},
          selectedStart: sameDay ? state.selectedStart : null,
          loading: true,
          error: null,
          notice: null,
        ),
      );
    }
    try {
      final loaded = await Future.wait([
        for (final court in state.courts)
          repository
              .getSlots(court.id, nextDate)
              .then((slots) => MapEntry(court.id, slots)),
      ]);
      if (isClosed || revision != _revision) return;
      final byCourt = {
        for (final entry in loaded)
          entry.key: List<CourtSlot>.unmodifiable(
            entry.value.map((s) => s.isPast(nextDate, _now()) ? s.expired : s),
          ),
      };
      _emitSlots(byCourt, nextDate);
    } catch (error) {
      if (isClosed || revision != _revision || silent) return;
      emit(
        state.copyWith(
          loading: false,
          error: error is Failure
              ? error.message
              : 'Không thể tải lịch sân. Vui lòng thử lại.',
        ),
      );
    }
  }

  void _emitSlots(
    Map<int, List<CourtSlot>> byCourt,
    DateTime date, {
    String? lostMessage,
  }) {
    var next = state.copyWith(
      date: date,
      slotsByCourt: byCourt,
      loading: false,
      error: null,
    );
    if (next.selectedStart != null && next.selectedOption == null) {
      next = next.copyWith(
        selectedStart: null,
        notice: lostMessage ?? 'Khung giờ bạn chọn vừa thay đổi. Chọn lại nhé.',
      );
    }
    emit(next);
  }

  void selectDate(DateTime date) {
    if (slotDateKey(date) == slotDateKey(state.date) && !state.loading) return;
    refresh(date);
  }

  /// Jumps to the next day of [days] (wraps around); used by the empty state.
  void selectNextDay(List<DateTime> days) {
    final index = days.indexWhere(
      (d) => slotDateKey(d) == slotDateKey(state.date),
    );
    selectDate(days[(index + 1) % days.length]);
  }

  void selectCourt(int? courtId) {
    if (courtId == state.courtFilter) return;
    emit(
      state.copyWith(courtFilter: courtId, selectedStart: null, notice: null),
    );
  }

  void selectDuration(int minutes) {
    if (minutes == state.durationMinutes) return;
    emit(
      state.copyWith(
        durationMinutes: minutes,
        selectedStart: null,
        notice: null,
      ),
    );
  }

  void toggleUnavailable() =>
      emit(state.copyWith(showUnavailable: !state.showUnavailable));

  /// Selects (or deselects) a start time. Returns true when it is selected.
  bool selectStart(int startMinute) {
    expirePastSlots();
    if (state.loading || state.error != null) return false;
    if (state.selectedStart == startMinute) {
      emit(state.copyWith(selectedStart: null, notice: null));
      return false;
    }
    final option = state.options
        .where((o) => o.startMinute == startMinute && o.available)
        .firstOrNull;
    if (option == null) return false;
    emit(state.copyWith(selectedStart: startMinute, notice: null));
    return true;
  }

  void clear() {
    if (state.selectedStart == null) return;
    emit(state.copyWith(selectedStart: null));
  }

  void expirePastSlots() {
    if (state.loading || state.error != null || isClosed) return;
    var changed = false;
    final byCourt = {
      for (final entry in state.slotsByCourt.entries)
        entry.key: List<CourtSlot>.unmodifiable(
          entry.value.map((s) {
            if (s.status != SlotStatus.expired &&
                s.isPast(state.date, _now())) {
              changed = true;
              return s.expired;
            }
            return s;
          }),
        ),
    };
    if (!changed) return;
    _emitSlots(
      byCourt,
      state.date,
      lostMessage: 'Khung giờ đã bắt đầu được bỏ khỏi lựa chọn.',
    );
  }

  /// The slots to hold for the selected start; null when nothing is selected.
  SlotSelection? get selection {
    expirePastSlots();
    final option = state.selectedOption;
    final courtId = option?.suggestedCourtId;
    if (option == null || courtId == null) return null;
    final cells = bookableCells(
      state.slotsByCourt[courtId] ?? const [],
      option.startMinute,
      option.durationMinutes,
    );
    if (cells == null) return null;
    return SlotSelection(courtId: courtId, date: state.date, slots: cells);
  }

  @override
  Future<void> close() async {
    _revision++;
    _poll.cancel();
    _expiry.cancel();
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    for (final source in _invalidations) {
      await source.close();
    }
    return super.close();
  }
}
