import 'package:dio/dio.dart';
import 'package:fcourt/core/config/app_config.dart';
import 'package:fcourt/core/error/failure.dart';
import 'package:flutter_test/flutter_test.dart';

DioException _error(int status, Object body) {
  final options = RequestOptions(path: '/x');
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response(requestOptions: options, statusCode: status, data: body),
  );
}

void main() {
  group('AppConfig', () {
    test('URL facility/reporting mặc định dùng API_BASE_URL', () {
      const config = AppConfig(env: AppEnv.dev, apiBaseUrl: 'http://gw');

      expect(config.facilityUrl, 'http://gw');
      expect(config.reportingUrl, 'http://gw');
    });

    test('dùng URL riêng khi được khai báo, bỏ qua chuỗi rỗng', () {
      const config = AppConfig(
        env: AppEnv.dev,
        apiBaseUrl: 'http://gw',
        facilityBaseUrl: 'http://10.0.2.2:8083',
        reportingBaseUrl: '',
      );

      expect(config.facilityUrl, 'http://10.0.2.2:8083');
      expect(config.reportingUrl, 'http://gw');
    });
  });

  group('failureFromDio', () {
    test('đọc detail của RFC 7807 ProblemDetail', () {
      expect(
        failureFromDio(_error(409, {'title': 'Conflict', 'detail': 'Trùng'})),
        const ServerFailure('Trùng', statusCode: 409),
      );
    });

    test('vẫn ưu tiên message của API kiểu cũ', () {
      expect(
        failureFromDio(_error(500, {'message': 'boom', 'detail': 'x'})),
        const ServerFailure('boom', statusCode: 500),
      );
    });

    test('không có thông điệp → thông báo chung kèm mã lỗi', () {
      expect(
        failureFromDio(_error(404, {'detail': ''})),
        const ServerFailure('Lỗi máy chủ (404)', statusCode: 404),
      );
    });
  });
}
