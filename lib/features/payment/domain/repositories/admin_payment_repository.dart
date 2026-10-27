import '../entities/pending_payment.dart';

abstract interface class AdminPaymentRepository {
  Future<List<PendingPayment>> pending(int branchId, {int offset = 0});
  Future<void> confirm(int paymentId);
  Future<void> reject(int paymentId, String reason);
}
