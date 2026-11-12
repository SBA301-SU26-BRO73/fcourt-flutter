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
