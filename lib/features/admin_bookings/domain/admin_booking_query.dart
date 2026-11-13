import 'admin_booking_status.dart';

class AdminBookingQuery {
  const AdminBookingQuery({
    required this.branchId,
    this.courtId,
    this.status,
    this.date,
    this.search = '',
  });
  final int branchId;
  final int? courtId;
  final AdminBookingStatus? status;
  final DateTime? date;
  final String search;

  AdminBookingQuery copyWith({
    int? branchId,
    int? courtId,
    bool clearCourt = false,
    AdminBookingStatus? status,
    bool clearStatus = false,
    DateTime? date,
    bool clearDate = false,
    String? search,
  }) => AdminBookingQuery(
    branchId: branchId ?? this.branchId,
    courtId: clearCourt ? null : courtId ?? this.courtId,
    status: clearStatus ? null : status ?? this.status,
    date: clearDate ? null : date ?? this.date,
    search: search ?? this.search,
  );
}
