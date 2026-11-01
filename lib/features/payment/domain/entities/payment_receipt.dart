import 'dart:typed_data';

class ReceiptImage {
  const ReceiptImage(this.bytes);
  final Uint8List bytes;
}

enum ReceiptStatus { pending, confirmed, rejected, cancelled }

class PaymentReceipt {
  const PaymentReceipt({
    required this.id,
    required this.bookingId,
    required this.status,
    this.rejectionReason,
  });
  final int id;
  final int bookingId;
  final ReceiptStatus status;
  final String? rejectionReason;
}
