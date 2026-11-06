import 'schedule.dart';

/// Index every half-hour cell overlapped by a session, including midnight.
Map<String, List<CourtSession>> scheduleCells(List<CourtSession> sessions) {
  final result = <String, List<CourtSession>>{};
  for (final session in sessions) {
    final start = DateTime.parse('${session.date}T${session.start}:00');
    var end = DateTime.parse('${session.date}T${session.end}:00');
    if (!end.isAfter(start)) end = end.add(const Duration(days: 1));
    var cell = DateTime(
      start.year,
      start.month,
      start.day,
      start.hour,
      (start.minute ~/ 30) * 30,
    );
    while (cell.isBefore(end)) {
      final time =
          '${cell.hour.toString().padLeft(2, '0')}:'
          '${cell.minute.toString().padLeft(2, '0')}';
      result.putIfAbsent('${calendarDate(cell)}:$time', () => []).add(session);
      cell = cell.add(const Duration(minutes: 30));
    }
  }
  return result;
}
