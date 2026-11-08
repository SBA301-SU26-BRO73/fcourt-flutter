import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/calendar_slot.dart';
import '../../domain/entities/court.dart';
import '../../domain/entities/court_lock.dart';
import '../../domain/usecases/court_usecases.dart';
import '../../domain/usecases/lock_usecases.dart';

part 'court_calendar_event.dart';
part 'court_calendar_state.dart';

/// SCRUM-50: lịch ngày/tuần của một sân, chọn ô trống để khóa hoặc bao sân,
/// chạm ô đã khóa để mở khóa. Trạng thái ô đọc từ discovery (cùng nguồn với
/// khách), danh sách khóa và thao tác ghi đi qua facility-service.
class CourtCalendarBloc extends Bloc<CourtCalendarEvent, CourtCalendarState> {
  CourtCalendarBloc({
    required this.courtId,
    required this._getCourt,
    required this._getDays,
    required this._getLocks,
    required this._lockCourt,
    required this._unlockCourt,
    DateTime Function()? today,
    DateTime Function()? now,
  }) : super(CourtCalendarState(anchor: _day((today ?? DateTime.now)()))) {
    _now = now ?? DateTime.now;
    on<CalendarStarted>(_onStarted);
    on<CalendarModeChanged>(_onModeChanged);
    on<CalendarShifted>(_onShifted);
    on<CalendarRefreshed>((_, emit) => _load(emit));
    on<CalendarCellToggled>(_onCellToggled);
    on<CalendarSelectionCleared>(
      (_, emit) => emit(state.copyWith(selected: const {})),
    );
    on<CalendarLockSubmitted>(_onLockSubmitted);
    on<CalendarUnlockRequested>(_onUnlockRequested);
  }

  final int courtId;
  final GetCourt _getCourt;
  final GetCalendarDays _getDays;
  final GetCourtLocks _getLocks;
  final LockCourt _lockCourt;
  final UnlockCourt _unlockCourt;
  late final DateTime Function() _now;
  int _loadRevision = 0;

  static DateTime _day(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  Future<void> _onStarted(
    CalendarStarted event,
    Emitter<CourtCalendarState> emit,
  ) async {
    emit(
      state.copyWith(
        status: CalendarStatus.loading,
        days: const [],
        locks: const [],
        selected: const {},
        clearMessage: true,
      ),
    );
    try {
      final court = await _getCourt(courtId);
      emit(state.copyWith(court: court));
    } on Failure catch (failure) {
      emit(
        state.copyWith(
          status: CalendarStatus.failure,
          message: failure.message,
        ),
      );
      return;
    }
    await _load(emit);
  }

  Future<void> _onModeChanged(
    CalendarModeChanged event,
    Emitter<CourtCalendarState> emit,
  ) async {
    if (event.mode == state.mode) return;
    emit(state.copyWith(mode: event.mode, selected: const {}));
    await _load(emit);
  }

  Future<void> _onShifted(
    CalendarShifted event,
    Emitter<CourtCalendarState> emit,
  ) async {
    final step = state.mode == CalendarMode.week ? 7 : 1;
    final a = state.anchor;
    emit(
      state.copyWith(
        anchor: DateTime(a.year, a.month, a.day + event.direction * step),
        selected: const {},
      ),
    );
    await _load(emit);
  }

  void _onCellToggled(
    CalendarCellToggled event,
    Emitter<CourtCalendarState> emit,
  ) {
    if (state.status != CalendarStatus.ready || state.submitting) return;
    final slot = state.dayOf(event.cell.date)?.slotAt(event.cell.startMinute);
    if (slot == null || !slot.selectable) return;
    if (_cellHasStarted(event.cell)) {
      emit(
        state.copyWith(
          days: _expireCells({event.cell}),
          selected: state.selected.difference({event.cell}),
          notice: CalendarNotice(
            'Khung giờ đã bắt đầu nên không thể khóa',
            isError: true,
          ),
        ),
      );
      return;
    }
    final next = {...state.selected};
    if (!next.remove(event.cell)) next.add(event.cell);
    emit(state.copyWith(selected: next));
  }

  bool _cellHasStarted(CellKey cell) {
    final venueNow = _now().toUtc().add(const Duration(hours: 7));
    final start = DateTime.utc(
      cell.date.year,
      cell.date.month,
      cell.date.day,
    ).add(Duration(minutes: cell.startMinute));
    return !start.isAfter(venueNow);
  }

  List<CalendarDay> _expireCells(Set<CellKey> cells) => [
    for (final day in state.days)
      CalendarDay(
        date: day.date,
        slots: [
          for (final slot in day.slots)
            if (cells.contains(CellKey(day.date, slot.startMinute)))
              CalendarSlot(
                startMinute: slot.startMinute,
                endMinute: slot.endMinute,
                status: CalendarSlotStatus.expired,
              )
            else
              slot,
        ],
      ),
  ];

  /// Tải lại ngày/tuần đang xem; lựa chọn bị xóa vì dữ liệu ô có thể đã đổi.
  Future<void> _load(Emitter<CourtCalendarState> emit) async {
    final court = state.court;
    if (court == null) return;
    final revision = ++_loadRevision;
    emit(
      state.copyWith(
        status: CalendarStatus.loading,
        days: const [],
        locks: const [],
        selected: const {},
        clearMessage: true,
      ),
    );
    final dates = state.visibleDates;
    final last = dates.last;
    try {
      final days = _getDays(courtId, dates);
      final locks = _getLocks(
        court.branchId,
        courtId: courtId,
        from: dates.first,
        to: DateTime(last.year, last.month, last.day + 1),
      );
      final loadedDays = await days;
      final loadedLocks = await locks;
      if (emit.isDone || revision != _loadRevision) return;
      emit(
        state.copyWith(
          status: CalendarStatus.ready,
          days: loadedDays,
          locks: loadedLocks,
          selected: const {},
        ),
      );
    } on Failure catch (failure) {
      if (emit.isDone || revision != _loadRevision) return;
      emit(
        state.copyWith(
          status: CalendarStatus.failure,
          message: failure.message,
        ),
      );
    }
  }

  Future<void> _onLockSubmitted(
    CalendarLockSubmitted event,
    Emitter<CourtCalendarState> emit,
  ) async {
    if (state.status != CalendarStatus.ready ||
        state.submitting ||
        state.selected.isEmpty) {
      return;
    }
    final expired = state.selected.where(_cellHasStarted).toSet();
    if (expired.isNotEmpty) {
      emit(
        state.copyWith(
          days: _expireCells(expired),
          selected: state.selected.difference(expired),
          notice: CalendarNotice(
            'Đã bỏ các khung giờ vừa bắt đầu. Vui lòng kiểm tra lại lịch trước khi khóa.',
            isError: true,
          ),
        ),
      );
      return;
    }
    final ranges = mergeSelection(
      state.selected,
      (cell) => state.dayOf(cell.date)!.slotAt(cell.startMinute)!.endMinute,
    );
    emit(state.copyWith(submitting: true));
    var created = 0;
    CalendarNotice? notice;
    for (final range in ranges) {
      try {
        await _lockCourt(
          CourtLockRequest(
            courtId: courtId,
            startAt: range.startAt,
            endAt: range.endAt,
            details: event.details,
          ),
        );
        created++;
      } on Failure catch (failure) {
        final done = created == 0
            ? ''
            : ' (đã khóa $created/${ranges.length} khoảng)';
        notice = CalendarNotice('${failure.message}$done', isError: true);
        break;
      }
    }
    notice ??= CalendarNotice(
      created == 1
          ? 'Đã khóa khung giờ đã chọn'
          : 'Đã khóa $created khoảng thời gian',
    );
    emit(state.copyWith(submitting: false, notice: notice));
    await _load(emit);
  }

  Future<void> _onUnlockRequested(
    CalendarUnlockRequested event,
    Emitter<CourtCalendarState> emit,
  ) async {
    if (state.status != CalendarStatus.ready || state.submitting) return;
    emit(state.copyWith(submitting: true));
    CalendarNotice notice;
    try {
      await _unlockCourt(event.lockId);
      notice = CalendarNotice('Đã mở khóa');
    } on Failure catch (failure) {
      notice = CalendarNotice(failure.message, isError: true);
    }
    emit(state.copyWith(submitting: false, notice: notice));
    await _load(emit);
  }
}
