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
  const ServerFailure(
    super.message, {
    this.statusCode,
    this.fieldErrors = const {},
  });

  final int? statusCode;

  /// Lỗi validation theo từng field (`errors` trong response 400), khóa là tên field.
  final Map<String, String> fieldErrors;

  @override
  List<Object?> get props => [message, statusCode, fieldErrors];
}

class UnknownFailure extends Failure {
  const UnknownFailure([super.message = 'Đã có lỗi xảy ra']);
}

Failure failureFromDio(DioException e) {
  final status = e.response?.statusCode;
  final body = e.response?.data;
  if (status == 401) {
    // Chỉ tin `detail` của RFC 7807 (ví dụ "Invalid email or password"); `message` của
    // response cũ vẫn cho ra thông báo hết phiên như trước.
    final reason = _stringField(body, 'detail');
    return reason == null ? const UnauthorizedFailure() : UnauthorizedFailure(reason);
  }
  final message = _messageFrom(body);
  if (status == 429) {
    return ServerFailure(
      _throttledMessage(e.response?.headers.value('retry-after')),
      statusCode: 429,
    );
  }
  if (status != null) {
    return ServerFailure(
      message ?? 'Lỗi máy chủ ($status)',
      statusCode: status,
      fieldErrors: _fieldErrorsFrom(body),
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

String _throttledMessage(String? retryAfter) {
  final seconds = int.tryParse(retryAfter?.trim() ?? '');
  if (seconds == null || seconds <= 0) {
    return 'Bạn thao tác quá nhanh, vui lòng thử lại sau';
  }
  final wait = seconds < 60 ? '$seconds giây' : '${(seconds / 60).ceil()} phút';
  return 'Bạn thao tác quá nhanh, vui lòng thử lại sau $wait';
}

/// RFC 7807 của các service mới dùng `detail`; response cũ dùng `message`.
String? _messageFrom(Object? body) =>
    _stringField(body, 'detail') ?? _stringField(body, 'message');

String? _stringField(Object? body, String key) {
  final value = body is Map ? body[key] : null;
  return value is String && value.isNotEmpty ? value : null;
}

Map<String, String> _fieldErrorsFrom(Object? body) {
  final errors = body is Map ? body['errors'] : null;
  if (errors is! List) return const {};
  final result = <String, String>{};
  for (final error in errors) {
    if (error is Map && error['field'] is String && error['message'] is String) {
      result.putIfAbsent(error['field'] as String, () => error['message'] as String);
    }
  }
  return result;
}
