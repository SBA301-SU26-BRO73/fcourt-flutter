part of 'court_calendar_bloc.dart';

sealed class CourtCalendarEvent extends Equatable {
  const CourtCalendarEvent();

  @override
  List<Object?> get props => [];
}

class CalendarStarted extends CourtCalendarEvent {
  const CalendarStarted();
}

class CalendarModeChanged extends CourtCalendarEvent {
  const CalendarModeChanged(this.mode);

  final CalendarMode mode;

  @override
  List<Object?> get props => [mode];
}

/// Sang ngày/tuần trước (-1) hoặc sau (+1).
class CalendarShifted extends CourtCalendarEvent {
  const CalendarShifted(this.direction);

  final int direction;

  @override
  List<Object?> get props => [direction];
}

class CalendarRefreshed extends CourtCalendarEvent {
  const CalendarRefreshed();
}

class CalendarCellToggled extends CourtCalendarEvent {
  const CalendarCellToggled(this.cell);

  final CellKey cell;

  @override
  List<Object?> get props => [cell];
}

class CalendarSelectionCleared extends CourtCalendarEvent {
  const CalendarSelectionCleared();
}

/// Khóa các ô đang chọn bằng nội dung của form.
class CalendarLockSubmitted extends CourtCalendarEvent {
  const CalendarLockSubmitted(this.details);

  final LockDetails details;

  @override
  List<Object?> get props => [details];
}

class CalendarUnlockRequested extends CourtCalendarEvent {
  const CalendarUnlockRequested(this.lockId);

  final int lockId;

  @override
  List<Object?> get props => [lockId];
}
