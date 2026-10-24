import 'package:dio/dio.dart';

import '../../domain/entities/booking_hold.dart';
import '../../domain/entities/booking_selection.dart';
import '../../domain/repositories/booking_repository.dart';
import '../datasources/booking_remote_data_source.dart';

class BookingRepositoryImpl implements BookingRepository {
  const BookingRepositoryImpl(this.source);
  final BookingRemoteDataSource source;

  @override
  Future<BookingHold> hold(BookingSelection selection, String phone) async {
    try {
      final json = await source.hold(selection, phone);
      final token = json['holdToken'];
      final expiry = json['expiresAt'];
      final expiresAt = expiry is String ? DateTime.tryParse(expiry) : null;
      if (token is! String ||
          token.isEmpty ||
          expiresAt == null ||
          !expiresAt.isAfter(DateTime.now())) {
        throw const FormatException('Invalid or expired hold response');
      }
      return BookingHold(token: token, expiresAt: expiresAt.toUtc());
    } on DioException catch (error) {
      throw BookingFailure(switch (error.response?.statusCode) {
        409 =>
          'Khung giờ vừa có người đặt. Vui lòng chọn lại sân hoặc giờ chơi.',
        400 => 'Thông tin đặt sân không hợp lệ. Vui lòng kiểm tra lại.',
        404 => 'Không tìm thấy sân đã chọn.',
        _ => 'Chưa thể giữ chỗ. Kiểm tra kết nối rồi thử lại.',
      });
    } on FormatException {
      throw const BookingFailure(
        'Thông tin giữ chỗ không hợp lệ. Vui lòng thử lại.',
      );
    }
  }
}
