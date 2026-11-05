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
}
