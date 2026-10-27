class PendingPayment {
  const PendingPayment({
    required this.id,
    required this.bookingId,
    required this.bookingCode,
    required this.customerName,
    required this.amountVnd,
    required this.receiptUri,
    required this.submittedAt,
  });
  final int id, bookingId, amountVnd;
  final String bookingCode, customerName;
  final Uri receiptUri;
  final DateTime submittedAt;
}
