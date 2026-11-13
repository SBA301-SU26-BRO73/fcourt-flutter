class GuestBookingLookup {
  const GuestBookingLookup({
    required this.bookingCode,
    required this.branchName,
    required this.courtName,
    required this.date,
    required this.slots,
    required this.totalPrice,
    required this.status,
    this.branchAddress,
    this.checkInCode,
  });

  final String bookingCode;
  final String branchName;
  final String? branchAddress;
  final String courtName;
  final DateTime date;
  final List<GuestBookingSlot> slots;
  final int totalPrice;
  final String status;
  final String? checkInCode;
}

class GuestBookingSlot {
  const GuestBookingSlot({required this.startTime, required this.endTime});
  final String startTime;
  final String endTime;
}
