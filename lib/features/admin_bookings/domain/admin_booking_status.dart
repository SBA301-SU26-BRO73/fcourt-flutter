enum AdminBookingStatus {
  pendingPayment('PENDING_PAYMENT', 'Chờ thanh toán'),
  awaitingConfirmation('AWAITING_CONFIRMATION', 'Chờ duyệt'),
  confirmed('CONFIRMED', 'Đã xác nhận'),
  checkedIn('CHECKED_IN', 'Đã check-in'),
  completed('COMPLETED', 'Đã hoàn thành'),
  cancelled('CANCELLED', 'Đã hủy');

  const AdminBookingStatus(this.code, this.label);
  final String code, label;
}
