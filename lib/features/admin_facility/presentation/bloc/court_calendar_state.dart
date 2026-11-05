part of 'court_calendar_bloc.dart';

enum CalendarStatus { loading, ready, failure }

enum CalendarMode { day, week }

class CalendarNotice {
  CalendarNotice(this.message, {this.isError = false});

  final String message;
  final bool isError;
}

class CourtCalendarState extends Equatable {
  const CourtCalendarState({
    required this.anchor,
    this.status = CalendarStatus.loading,
    this.mode = CalendarMode.week,
    this.court,
    this.days = const [],
    this.locks = const [],
    this.selected = const {},
    this.submitting = false,
    this.message,
    this.notice,
  });

  /// Ngày đang xem (chế độ ngày) hoặc một ngày bất kỳ của tuần đang xem.
  final DateTime anchor;
  final CalendarStatus status;
  final CalendarMode mode;
  final Court? court;
  final List<CalendarDay> days;
  final List<CourtLock> locks;
  final Set<CellKey> selected;
  final bool submitting;
  final String? message;
  final CalendarNotice? notice;

  /// Các ngày đang hiển thị: một ngày, hoặc Thứ hai đến Chủ nhật của tuần chứa [anchor].
  List<DateTime> get visibleDates {
    if (mode == CalendarMode.day) return [anchor];
    final monday = DateTime(
      anchor.year,
      anchor.month,
      anchor.day - (anchor.weekday - DateTime.monday),
    );
    return [
      for (var i = 0; i < 7; i++)
        DateTime(monday.year, monday.month, monday.day + i),
    ];
  }

  CalendarDay? dayOf(DateTime date) {
    for (final day in days) {
      if (day.date == date) return day;
    }
    return null;
  }

  /// Khóa đang phủ lên ô `[startMinute, endMinute)` của [date] (nếu có).
  CourtLock? lockCovering(DateTime date, CalendarSlot slot) {
    final start = date.add(Duration(minutes: slot.startMinute));
    final end = date.add(Duration(minutes: slot.endMinute));
    for (final lock in locks) {
      if (lock.overlaps(start, end)) return lock;
    }
    return null;
  }

  CourtCalendarState copyWith({
    DateTime? anchor,
    CalendarStatus? status,
    CalendarMode? mode,
    Court? court,
    List<CalendarDay>? days,
    List<CourtLock>? locks,
    Set<CellKey>? selected,
    bool? submitting,
    String? message,
    bool clearMessage = false,
    CalendarNotice? notice,
  }) => CourtCalendarState(
    anchor: anchor ?? this.anchor,
    status: status ?? this.status,
    mode: mode ?? this.mode,
    court: court ?? this.court,
    days: days ?? this.days,
    locks: locks ?? this.locks,
    selected: selected ?? this.selected,
    submitting: submitting ?? this.submitting,
    message: clearMessage ? null : (message ?? this.message),
    notice: notice,
  );

  @override
  List<Object?> get props => [
    anchor,
    status,
    mode,
    court,
    days,
    locks,
    selected,
    submitting,
    message,
    notice,
  ];
}
