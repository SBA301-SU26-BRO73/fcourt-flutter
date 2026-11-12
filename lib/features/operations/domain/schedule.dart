class CourtSession {
  const CourtSession({
    required this.bookingId,
    required this.date,
    required this.start,
    required this.end,
    required this.status,
    this.name = '',
    this.phone = '',
    this.endingSoon = false,
    this.lateCheckIn = false,
  });
  final int bookingId;
  final String date;
  final String start;
  final String end;
  final String status;
  final String name;
  final String phone;
  final bool endingSoon;
  final bool lateCheckIn;
  bool get playing => status == 'CHECKED_IN';
  bool get canCheckIn => status == 'CONFIRMED';
  CourtSession withStatus(String value) => CourtSession(
    bookingId: bookingId,
    date: date,
    start: start,
    end: end,
    status: value,
    name: name,
    phone: phone,
    endingSoon: endingSoon,
    lateCheckIn: lateCheckIn,
  );
}

class CourtSchedule {
  const CourtSchedule(this.id, this.name, this.sessions);
  final int id;
  final String name;
  final List<CourtSession> sessions;
}

class BranchSchedule {
  const BranchSchedule(this.branchId, this.courts);
  final int branchId;
  final List<CourtSchedule> courts;
}

class TicketPreview {
  const TicketPreview({
    required this.bookingId,
    required this.branchId,
    required this.courtName,
    required this.date,
    required this.start,
    required this.end,
    required this.name,
    this.offline = false,
  });
  final int bookingId;
  final int branchId;
  final String courtName;
  final String date;
  final String start;
  final String end;
  final String name;
  final bool offline;
}

abstract class OperationsRepository {
  Future<BranchSchedule> week(String start, String end);
  Future<BranchSchedule> today();
  Future<TicketPreview> preview(String code);
  Future<int> checkIn(String code, String key, {bool manual = false});

  /// Nhận sân một chạm theo mã đơn (lấy từ lịch hôm nay), không cần mã vé.
  Future<int> checkInByBooking(int bookingId, String key);
}

DateTime weekMonday(DateTime date) => DateTime(
  date.year,
  date.month,
  date.day,
).subtract(Duration(days: date.weekday - 1));
String calendarDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
