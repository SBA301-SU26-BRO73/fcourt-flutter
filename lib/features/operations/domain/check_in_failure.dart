import 'package:dio/dio.dart';

import '../../../core/error/failure.dart';

/// Đổi phản hồi từ chối check-in của staff-operations sang thông báo tiếng Việt.
///
/// Backend trả mã từ chối trong ProblemDetail `reason`; khi thiếu hoặc lạ thì dùng câu chung.
Failure checkInFailureFromDio(DioException e) {
  final failure = failureFromDio(e);
  if (failure is! ServerFailure) return failure;
  final body = e.response?.data;
  final raw = body is Map ? body['reason'] : null;
  final byCode = raw is String ? _byCode[raw.toUpperCase()] : null;
  if (byCode != null) {
    return ServerFailure(byCode, statusCode: failure.statusCode);
  }
  final generic = failure.message == 'Booking command rejected';
  return switch (failure.statusCode) {
    400 || 404 || 409 when generic => ServerFailure(
      'Không thể nhận sân với mã này. Mã vé có thể sai, vé không phải của ngày hôm nay, '
      'chưa tới giờ nhận sân hoặc đã được sử dụng.',
      statusCode: failure.statusCode,
    ),
    403 when generic => ServerFailure(
      'Bạn không có quyền nhận sân cho vé này. Vé có thể thuộc chi nhánh khác.',
      statusCode: 403,
    ),
    _ => failure,
  };
}

const _byCode = {
  'CHECKIN_TOO_EARLY': 'Chưa tới giờ nhận sân. Vui lòng quay lại gần giờ chơi.',
  'WRONG_DATE': 'Vé này không phải của ngày hôm nay.',
  'WRONG_BRANCH': 'Vé này thuộc chi nhánh khác.',
  'ALREADY_CHECKED_IN': 'Vé đã được sử dụng để nhận sân.',
  'BOOKING_CANCELLED': 'Đơn đặt sân này đã bị hủy.',
  'CHECKIN_EXPIRED': 'Vé đã quá giờ nhận sân.',
};

/// `2026-11-12` -> `12/11/2026`; giá trị không đúng dạng thì giữ nguyên.
String displayDate(String iso) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(iso);
  return m == null ? iso : '${m[3]}/${m[2]}/${m[1]}';
}
