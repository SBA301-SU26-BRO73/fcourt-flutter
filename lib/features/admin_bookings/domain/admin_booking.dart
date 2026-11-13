import 'admin_booking_status.dart';

class AdminBooking {
  const AdminBooking({
    required this.id,
    required this.code,
    required this.branchId,
    required this.branchName,
    required this.courtId,
    required this.courtName,
    required this.date,
    required this.createdAt,
    required this.status,
    required this.amount,
    this.customerName,
    this.customerPhone,
    this.paymentStatus,
    this.receiptUri,
  });
  final int id, branchId, courtId;
  final String code, branchName, courtName;
  final String? customerName, customerPhone, paymentStatus;
  final DateTime date, createdAt;
  final AdminBookingStatus status;
  final num amount;
  final Uri? receiptUri;
}
