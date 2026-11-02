import 'package:dio/dio.dart';
import 'package:fcourt/core/error/failure.dart';
import 'package:flutter_test/flutter_test.dart';

DioException _error(
  int? status, {
  Object? body,
  DioExceptionType? type,
  Map<String, List<String>> headers = const {},
}) {
  final request = RequestOptions(path: '/x');
  return DioException(
    requestOptions: request,
    type: type ?? DioExceptionType.badResponse,
    response: status == null
        ? null
        : Response<dynamic>(
            requestOptions: request,
            statusCode: status,
            data: body,
            headers: Headers.fromMap(headers),
          ),
  );
}

void main() {
  group('failureFromDio', () {
    test('đọc detail của RFC 7807', () {
      final failure = failureFromDio(_error(409, body: {'detail': 'Email is already registered'}));

      expect(
        failure,
        const ServerFailure('Email is already registered', statusCode: 409),
      );
    });

    test('429 hiển thị thời gian chờ theo Retry-After', () {
      final seconds = failureFromDio(_error(429, headers: {'retry-after': ['30']}));
      final minutes = failureFromDio(_error(429, headers: {'retry-after': ['90']}));
      final none = failureFromDio(_error(429, body: {'detail': 'x'}));

      expect(seconds.message, contains('30 giây'));
      expect(minutes.message, contains('2 phút'));
      expect((none as ServerFailure).statusCode, 429);
      expect(none.message, isNot(contains('giây')));
    });

    test('vẫn đọc message của response cũ', () {
      final failure = failureFromDio(_error(500, body: {'message': 'boom'}));

      expect(failure, const ServerFailure('boom', statusCode: 500));
    });

    test('detail được ưu tiên hơn message', () {
      final failure = failureFromDio(_error(400, body: {'detail': 'a', 'message': 'b'}));

      expect((failure as ServerFailure).message, 'a');
    });

    test('lấy lỗi validation theo field, giữ lỗi đầu tiên của mỗi field', () {
      final failure = failureFromDio(_error(400, body: {
        'detail': 'Invalid request fields',
        'errors': [
          {'field': 'email', 'message': 'email is invalid'},
          {'field': 'email', 'message': 'email is required'},
          {'field': 'password', 'message': 'password must be 8 to 72 characters'},
          {'field': 1, 'message': 'bỏ qua'},
        ],
      }));

      expect((failure as ServerFailure).fieldErrors, {
        'email': 'email is invalid',
        'password': 'password must be 8 to 72 characters',
      });
    });

    test('401 có detail thì giữ lý do (sai mật khẩu), không báo hết phiên', () {
      final failure = failureFromDio(_error(401, body: {'detail': 'Invalid email or password'}));

      expect(failure, const UnauthorizedFailure('Invalid email or password'));
    });

    test('401 chỉ có message của response cũ thì vẫn báo phiên hết hạn', () {
      final failure = failureFromDio(_error(401, body: {'message': 'expired'}));

      expect(failure, const UnauthorizedFailure());
    });

    test('401 không có nội dung thì báo phiên hết hạn', () {
      expect(failureFromDio(_error(401)), const UnauthorizedFailure());
    });

    test('body không phải JSON object thì dùng thông báo chung', () {
      final failure = failureFromDio(_error(502, body: '<html>bad gateway</html>'));

      expect(failure, const ServerFailure('Lỗi máy chủ (502)', statusCode: 502));
    });

    test('không có response thì phân loại theo kiểu lỗi mạng', () {
      expect(
        failureFromDio(_error(null, type: DioExceptionType.connectionTimeout)),
        const NetworkFailure(),
      );
      expect(
        failureFromDio(_error(null, type: DioExceptionType.connectionError)),
        const NetworkFailure(),
      );
      expect(
        failureFromDio(_error(null, type: DioExceptionType.cancel)),
        const UnknownFailure(),
      );
    });
  });
}
