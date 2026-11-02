class Booking {
  const Booking({
    required this.id,
    required this.code,
    required this.branchName,
    required this.courtName,
    required this.date,
    required this.slots,
    required this.amount,
    required this.status,
    this.address,
    this.phone,
    this.checkInCode,
    this.paymentStatus,
  });
  final int id, amount;
  final String code, branchName, courtName, date, status;
  final String? address, phone, checkInCode, paymentStatus;
  final List<String> slots;
  bool get hasTicket => status == 'CONFIRMED' && checkInCode != null;
  DateTime? get startsAt => slots.isEmpty
      ? null
      : DateTime.tryParse('${date}T${slots.first.substring(0, 5)}:00+07:00');
  String get label => switch (status) {
    'PENDING_PAYMENT' => 'Chờ thanh toán',
    'AWAITING_CONFIRMATION' => 'Chờ duyệt',
    'CONFIRMED' => 'Sắp diễn ra',
    'CHECKED_IN' => 'Đã nhận sân',
    'COMPLETED' => 'Đã hoàn thành',
    'CANCELLED' => 'Đã hủy',
    _ => status,
  };
  String countdown(DateTime now) {
    final start = startsAt;
    if (start == null) return '';
    final minutes = start.difference(now).inMinutes;
    if (minutes < 0) return 'Đã đến giờ chơi';
    if (minutes < 60) return 'Còn $minutes phút';
    if (minutes < 1440) return 'Còn ${minutes ~/ 60} giờ ${minutes % 60} phút';
    return 'Còn ${minutes ~/ 1440} ngày';
  }
}

class BookingPage {
  const BookingPage(this.items, this.page, this.size, this.total);
  final List<Booking> items;
  final int page, size, total;
  bool get hasMore => (page + 1) * size < total;
}

abstract interface class BookingRepository {
  Future<BookingPage> history(String status, {int page = 0});
  Future<Booking> detail(int id);
}
