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
  });
  final int bookingId;
  final int branchId;
  final String courtName;
  final String date;
  final String start;
  final String end;
  final String name;
}

abstract class OperationsRepository {
  Future<BranchSchedule> today();
  Future<TicketPreview> preview(String code);
  Future<int> checkIn(String code, String key, {bool manual = false});
}
