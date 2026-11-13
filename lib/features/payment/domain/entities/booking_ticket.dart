import 'dart:typed_data';

import 'payment_checkout.dart';

class BookingTicket {
  const BookingTicket({
    required this.bookingId,
    required this.bookingCode,
    required this.branchName,
    required this.courtName,
    required this.date,
    required this.slots,
    required this.checkInCode,
    required this.png,
  });
  final int bookingId;
  final String bookingCode, branchName, courtName, date, checkInCode;
  final List<String> slots;
  final Uint8List png;
}

class TicketNotReady extends PaymentFailure {
  const TicketNotReady()
    : super('Thanh toán đã ghi nhận. Vé đang được đồng bộ, vui lòng chờ.');
}
