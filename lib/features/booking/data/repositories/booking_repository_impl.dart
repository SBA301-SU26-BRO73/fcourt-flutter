import '../../domain/repositories/booking_creation_repository.dart';

import 'package:dio/dio.dart';

import '../../domain/entities/booking_hold.dart';
import '../../domain/entities/booking_selection.dart';
import '../../domain/repositories/booking_repository.dart';
import '../datasources/booking_remote_data_source.dart';

class BookingRepositoryImpl
    implements BookingRepository, BookingCreationRepository {
  const BookingRepositoryImpl(this.source);
  final BookingRemoteDataSource source;

  @override
  Future<int> createBooking(BookingCheckout checkout) async {
    try {
      final response = await source.create(checkout);
      final id = response['id'];
      if (id is! int || id <= 0) {
        throw const FormatException('Invalid booking ID');
      }
      return id;
    } on DioException catch (error) {
      throw BookingFailure(switch (error.response?.statusCode) {
        409 => 'Khung giờ hoặc giữ chỗ không còn hợp lệ. Vui lòng quay lại chọn giờ.',
        410 => 'Giữ chỗ đã hết hạn. Vui lòng quay lại chọn giờ.',
        400 => 'Thông tin đặt sân không hợp lệ. Vui lòng quay lại kiểm tra.',
        401 => 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
        403 => 'Tài khoản không được phép tạo đơn đặt sân này.',
        _ => 'Chưa xác nhận được kết quả tạo đơn. Bạn có thể thử lại cùng yêu cầu hoặc kiểm tra lịch sử đặt sân.',
      });
    } on FormatException {
      throw const BookingFailure(
        'Chưa xác nhận được mã đơn. Vui lòng thử lại cùng yêu cầu hoặc kiểm tra lịch sử đặt sân.',
      );
    }
  }

  @override
  Future<BookingHold> hold(BookingSelection selection, String phone) async {
    try {
      final json = await source.hold(selection, phone);
      final token = json['holdToken'];
      final seconds = json['expiresInSeconds'];
      final expiry = json['expiresAt'];
      final expiresAt = seconds is int && seconds > 0
          ? DateTime.now().toUtc().add(Duration(seconds: seconds))
          : expiry is String
          ? DateTime.tryParse(expiry)
          : null;
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
