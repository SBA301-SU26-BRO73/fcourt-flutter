import '../../payment/domain/entities/payment_receipt.dart';
import 'refund.dart';

abstract interface class AdminRefunds {
  Future<List<RefundRequest>> pending(int branchId, {int page = 0});
  Future<RefundRequest> approve(int id);
  Future<RefundRequest> complete(int id, ReceiptImage proof);
  Future<RefundRequest> reject(int id, String reason);
}

Uri refundQr(RefundRequest r) => Uri.https(
  'img.vietqr.io',
  '/image/${r.bankBin}-${r.accountNumber}-compact2.svg',
  {
    'amount': '${r.amount}',
    'accountName': r.accountName,
    'addInfo': 'HOAN ${r.bookingId} R${r.id}',
  },
);
