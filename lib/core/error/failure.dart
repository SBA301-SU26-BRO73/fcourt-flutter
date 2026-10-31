import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';

/// Lỗi đã được chuẩn hóa để tầng domain và presentation không phụ thuộc vào Dio.
sealed class Failure extends Equatable implements Exception {
  const Failure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'Không kết nối được máy chủ']);
}

class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure([super.message = 'Phiên đăng nhập đã hết hạn']);
}

class ServerFailure extends Failure {
  const ServerFailure(super.message, {this.statusCode, this.errors = const []});

  final int? statusCode;

  /// Lỗi từng trường của ProblemDetail (`errors`), ví dụ
  /// `"defaultPricePerHour: must be greater than 0"`.
  final List<String> errors;

  @override
  List<Object?> get props => [message, statusCode, errors];
}

class UnknownFailure extends Failure {
  const UnknownFailure([super.message = 'Đã có lỗi xảy ra']);
}

Failure failureFromDio(DioException e) {
  final status = e.response?.statusCode;
  if (status == 401) return const UnauthorizedFailure();
  if (status != null) {
    // Các service Spring trả lỗi dạng RFC 7807 ProblemDetail: thông điệp an toàn
    // cho người dùng nằm ở `detail`; giữ `message` cho API kiểu cũ.
    final body = e.response?.data;
    final message =
        _stringField(body, 'message') ??
        _stringField(body, 'detail') ??
        'Lỗi máy chủ ($status)';
    return ServerFailure(
      message,
      statusCode: status,
      errors: _fieldErrors(body),
    );
  }
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.connectionError:
      return const NetworkFailure();
    default:
      return const UnknownFailure();
  }
}

/// `errors` của ProblemDetail: facility/reporting trả danh sách chuỗi
/// `"field: message"`, auth trả `{field, message}`; nhận cả hai dạng.
List<String> _fieldErrors(Object? body) {
  final raw = body is Map ? body['errors'] : null;
  if (raw is! List) return const [];
  return [
    for (final item in raw)
      if (item is String && item.trim().isNotEmpty)
        item
      else if (item is Map && item['message'] is String)
        item['field'] is String
            ? '${item['field']}: ${item['message']}'
            : item['message'] as String,
  ];
}

String? _stringField(Object? body, String key) {
  if (body is! Map) return null;
  final value = body[key];
  return value is String && value.trim().isNotEmpty ? value : null;
}
