import 'package:dio/dio.dart';

import '../../../core/error/failure.dart';
import '../domain/booking.dart';
import '../domain/cancellation.dart';
import 'booking_repository_impl.dart';

class CancellationRepositoryImpl implements CancellationRepository {
  const CancellationRepositoryImpl(this.dio);
  final Dio dio;
  @override
  Future<CancellationPolicy> quote(int id) async {
    try {
      final r = (await dio.get<Map<String, dynamic>>(
        '/api/bookings/$id/cancellation-policy',
      )).data;
      if (r == null ||
          r['allowed'] is! bool ||
          r['reason'] is! String ||
          r['cutoffHours'] is! int ||
          r['cutoffHours'] < 0 ||
          r['currency'] != 'VND') {
        throw const FormatException();
      }
      final amount = r['refundAmount'], percent = r['refundPercent'];
      if (amount is! num ||
          !amount.isFinite ||
          amount < 0 ||
          amount != amount.roundToDouble() ||
          percent is! num ||
          !percent.isFinite ||
          percent < 0 ||
          percent > 100) {
        throw const FormatException();
      }
      final start = r['startsAt'] == null
          ? null
          : DateTime.tryParse(r['startsAt'].toString());
      final before = r['cancelBefore'] == null
          ? null
          : DateTime.tryParse(r['cancelBefore'].toString());
      if (r['allowed'] == true &&
          (start == null || before == null || before.isAfter(start))) {
        throw const FormatException();
      }
      return CancellationPolicy(
        allowed: r['allowed'] as bool,
        reason: r['reason'] as String,
        cutoffHours: r['cutoffHours'] as int,
        refundAmount: amount.toInt(),
        refundPercent: percent,
        startsAt: start,
        cancelBefore: before,
      );
    } on DioException catch (e) {
      throw failureFromDio(e);
    } on FormatException {
      throw const ServerFailure(
        'Chính sách hủy sân chưa hợp lệ. Vui lòng tải lại.',
      );
    }
  }

  @override
  Future<Booking> cancel(int id, String reason) async {
    if (reason.trim().isEmpty || reason.trim().length > 500) {
      throw const ServerFailure('Vui lòng nhập lý do hủy (1–500 ký tự)');
    }
    try {
      final r = await dio.post<Map<String, dynamic>>(
        '/api/bookings/$id/cancel',
        data: {'reason': reason.trim()},
      );
      final booking = BookingRepositoryImpl.parse(r.data);
      if (booking.id != id || booking.status != 'CANCELLED') {
        throw const FormatException();
      }
      return booking;
    } on DioException catch (e) {
      throw failureFromDio(e);
    } on FormatException {
      throw const ServerFailure(
        'Chưa xác nhận được trạng thái hủy. Vui lòng tải lại đơn.',
      );
    }
  }
}
