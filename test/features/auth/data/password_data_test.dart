import 'package:dio/dio.dart';
import 'package:fcourt/core/error/failure.dart';
import 'package:fcourt/core/network/auth_interceptor.dart';
import 'package:fcourt/core/storage/token_storage.dart';
import 'package:fcourt/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:fcourt/features/auth/data/models/auth_session_model.dart';
import 'package:fcourt/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fake_adapter.dart';
import '../helpers.dart';

class MockRemote extends Mock implements AuthRemoteDataSource {}

void main() {
  group('AuthRemoteDataSource: mật khẩu', () {
    late FakeAdapter adapter;
    late AuthRemoteDataSource remote;

    void useResponse(FakeHandler handler) {
      adapter = FakeAdapter(handler);
      remote = AuthRemoteDataSource(
        Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = adapter,
      );
    }

    test('forgotPassword gửi email tới endpoint công khai', () async {
      useResponse((_) => jsonResponse(202, {'message': 'sent'}));

      await remote.forgotPassword('customer@demo.com');

      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/api/auth/password/forgot');
      expect(request.data, {'email': 'customer@demo.com'});
      expect(request.extra[AuthInterceptor.skipAuthKey], isTrue);
    });

    test('resetPassword gửi token và mật khẩu mới, không kèm Bearer', () async {
      useResponse((_) => jsonResponse(200, {'message': 'ok'}));

      await remote.resetPassword('abc123', 'new-pass-2');

      final request = adapter.requests.single;
      expect(request.path, '/api/auth/password/reset');
      expect(request.data, {'token': 'abc123', 'newPassword': 'new-pass-2'});
      expect(request.extra[AuthInterceptor.skipAuthKey], isTrue);
    });

    test('changePassword dùng PATCH có token và đọc cặp token mới', () async {
      useResponse(
        (_) => jsonResponse(200, authResponseJson(accessToken: 'access-2', refreshToken: 'refresh-2')),
      );

      final session = await remote.changePassword('old-pass-1', 'new-pass-2');

      final request = adapter.requests.single;
      expect(request.method, 'PATCH');
      expect(request.path, '/api/auth/password');
      expect(request.data, {'currentPassword': 'old-pass-1', 'newPassword': 'new-pass-2'});
      expect(request.extra.containsKey(AuthInterceptor.skipAuthKey), isFalse);
      expect(session.accessToken, 'access-2');
      expect(session.refreshToken, 'refresh-2');
    });
  });

  group('AuthRepositoryImpl: mật khẩu', () {
    late MockRemote remote;
    late InMemoryTokenStorage tokens;
    late AuthRepositoryImpl repository;

    setUp(() {
      remote = MockRemote();
      tokens = InMemoryTokenStorage(
        const AuthTokens(accessToken: 'old-access', refreshToken: 'old-refresh'),
      );
      repository = AuthRepositoryImpl(remote, tokens);
    });

    test('requestPasswordReset gọi BE', () async {
      when(() => remote.forgotPassword('customer@demo.com')).thenAnswer((_) async {});

      await repository.requestPasswordReset('customer@demo.com');

      verify(() => remote.forgotPassword('customer@demo.com')).called(1);
    });

    test('requestPasswordReset: mất mạng thành NetworkFailure', () async {
      when(() => remote.forgotPassword(any()))
          .thenThrow(dioError(null, type: DioExceptionType.connectionError));

      await expectLater(
        repository.requestPasswordReset('customer@demo.com'),
        throwsA(const NetworkFailure()),
      );
    });

    test('resetPassword thành công không đụng tới token đang lưu', () async {
      when(() => remote.resetPassword('abc123', 'new-pass-2')).thenAnswer((_) async {});

      await repository.resetPassword(token: 'abc123', newPassword: 'new-pass-2');

      expect(
        await tokens.read(),
        const AuthTokens(accessToken: 'old-access', refreshToken: 'old-refresh'),
      );
    });

    test('resetPassword: token sai hoặc hết hạn thành lỗi 400 kèm lý do của BE', () async {
      when(() => remote.resetPassword(any(), any())).thenThrow(
        dioError(400, body: {'detail': 'Reset token is invalid or has expired'}),
      );

      await expectLater(
        repository.resetPassword(token: 'bad', newPassword: 'new-pass-2'),
        throwsA(const ServerFailure('Reset token is invalid or has expired', statusCode: 400)),
      );
    });

    test('changePassword lưu cặp token mới để phiên hiện tại vẫn dùng được', () async {
      when(() => remote.changePassword('old-pass-1', 'new-pass-2')).thenAnswer(
        (_) async => AuthSessionModel.fromJson(
          authResponseJson(accessToken: 'access-2', refreshToken: 'refresh-2'),
        ),
      );

      final user = await repository.changePassword(
        currentPassword: 'old-pass-1',
        newPassword: 'new-pass-2',
      );

      expect(user.email, 'customer@demo.com');
      expect(
        await tokens.read(),
        const AuthTokens(accessToken: 'access-2', refreshToken: 'refresh-2'),
      );
    });

    test('changePassword: sai mật khẩu hiện tại thì giữ token cũ và báo lỗi 400', () async {
      when(() => remote.changePassword(any(), any())).thenThrow(
        dioError(400, body: {'detail': 'Current password is incorrect'}),
      );

      await expectLater(
        repository.changePassword(currentPassword: 'wrong', newPassword: 'new-pass-2'),
        throwsA(const ServerFailure('Current password is incorrect', statusCode: 400)),
      );
      expect(
        await tokens.read(),
        const AuthTokens(accessToken: 'old-access', refreshToken: 'old-refresh'),
      );
    });

    test('changePassword: lỗi validation theo field được giữ lại', () async {
      when(() => remote.changePassword(any(), any())).thenThrow(
        dioError(400, body: {
          'detail': 'Invalid request fields',
          'errors': [
            {'field': 'newPassword', 'message': 'newPassword must be 8 to 72 characters'},
          ],
        }),
      );

      await expectLater(
        repository.changePassword(currentPassword: 'old-pass-1', newPassword: 'short'),
        throwsA(
          const ServerFailure(
            'Invalid request fields',
            statusCode: 400,
            fieldErrors: {'newPassword': 'newPassword must be 8 to 72 characters'},
          ),
        ),
      );
    });
  });
}
