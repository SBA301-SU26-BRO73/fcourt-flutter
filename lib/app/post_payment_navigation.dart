import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../features/payment/domain/entities/payment_checkout.dart';

/// Sau thanh toán, `go` thẳng tới vé/chi tiết đơn xóa ngăn xếp nên Back thoát app. Đặt danh
/// sách đơn làm gốc rồi `push` màn đích lên trên để Back quay về danh sách đơn.
void showTicketOverBookings(BuildContext context, CheckoutArguments args) {
  final router = GoRouter.of(context);
  router.go('/bookings');
  router.push('/payments/ticket', extra: args);
}

void showBookingOverList(BuildContext context, int bookingId) {
  final router = GoRouter.of(context);
  router.go('/bookings');
  router.push('/bookings/$bookingId');
}

/// Khách vãng lai không có danh sách đơn: tra cứu là màn gốc, vé nằm trên đó.
void showTicketForGuest(BuildContext context, CheckoutArguments args) {
  final router = GoRouter.of(context);
  router.go('/lookup');
  router.push('/payments/ticket', extra: args);
}

void showLookupForGuest(BuildContext context) =>
    GoRouter.of(context).go('/lookup');
