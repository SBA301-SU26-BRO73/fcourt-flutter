import 'dart:io';

import 'package:dio/dio.dart';

import '../../domain/entities/payment_checkout.dart';
import '../../domain/repositories/payment_repository.dart';
import '../models/checkout_model.dart';

class PaymentRepositoryImpl implements PaymentRepository {
  const PaymentRepositoryImpl(this.dio);
  final Dio dio;

  @override
  Future<PaymentCheckout> checkout(CheckoutArguments arguments) async {
    if (arguments.bookingId <= 0) {
      throw const PaymentFailure('Mã đặt sân không hợp lệ');
    }
    try {
      final response = await dio.get<Map<String, dynamic>>(
        '/api/payments/checkout-info/${arguments.bookingId}',
        options: Options(
          headers: {
            if (arguments.holdToken != null)
              'X-Hold-Token': arguments.holdToken,
          },
        ),
      );
      final json = response.data;
      if (json == null) throw const FormatException('Empty checkout');
      return CheckoutModel.fromJson(
        json,
        arguments.bookingId,
        serverClockAhead: _serverClockAhead(response.headers.value('date')),
      );
    } on DioException catch (error) {
      throw switch (error.response?.statusCode) {
        410 => const PaymentFailure('Phiên giữ chỗ đã hết hạn', expired: true),
        401 ||
        403 => const PaymentFailure('Bạn không có quyền xem đơn đặt sân này'),
        404 => const PaymentFailure('Không tìm thấy đơn đặt sân'),
        409 => const PaymentFailure('Đơn đặt sân không còn chờ thanh toán'),
        _ => const PaymentFailure(
          'Chưa tải được thông tin thanh toán. Vui lòng thử lại.',
        ),
      };
    } on FormatException {
      throw const PaymentFailure(
        'Thông tin thanh toán không hợp lệ. Vui lòng thử lại.',
      );
    }
  }

  static Duration _serverClockAhead(String? header) {
    if (header == null) return Duration.zero;
    try {
      return HttpDate.parse(header).difference(DateTime.now().toUtc());
    } on HttpException {
      return Duration.zero;
    } on FormatException {
      return Duration.zero;
    }
  }
}
