import '../../../../core/storage/guest_booking_store.dart';
import '../../domain/entities/payment_checkout.dart';
import '../../domain/repositories/payment_repository.dart';

/// Ghi mã đơn (`bookingCode`) vào phiên khách vãng lai ngay khi thông tin thanh toán tải
/// được, để sau này tra cứu bằng mã đơn + SĐT mà không phải đọc lại biên lai.
class GuestSessionPaymentRepository implements PaymentRepository {
  const GuestSessionPaymentRepository(this.inner, this.store);
  final PaymentRepository inner;
  final GuestBookingStore store;

  @override
  Future<PaymentCheckout> checkout(CheckoutArguments arguments) async {
    final checkout = await inner.checkout(arguments);
    try {
      final session = await store.read();
      if (session != null &&
          session.bookingId == checkout.bookingId &&
          session.bookingCode != checkout.bookingCode) {
        await store.save(session.withCode(checkout.bookingCode));
      }
    } catch (_) {
      // Lưu mã đơn chỉ là tiện ích; không được làm hỏng bước thanh toán.
    }
    return checkout;
  }
}
