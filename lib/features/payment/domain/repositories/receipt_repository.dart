import '../entities/payment_checkout.dart';
import '../entities/payment_receipt.dart';

abstract interface class ReceiptRepository {
  ReceiptSession open(CheckoutArguments arguments);
}

abstract interface class ReceiptSession {
  Future<PaymentReceipt?> status();
  Future<PaymentReceipt> upload(
    ReceiptImage image,
    void Function(double) onProgress,
  );
  void close();
}

abstract interface class ReceiptPicker {
  Future<ReceiptImage?> pick({required bool camera});
  Future<ReceiptImage?> recover();
}
