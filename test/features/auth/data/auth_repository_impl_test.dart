import 'package:dio/dio.dart';
import 'package:fcourt/core/error/failure.dart';
import 'package:fcourt/core/storage/token_storage.dart';
import 'package:fcourt/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:fcourt/features/auth/data/models/auth_session_model.dart';
import 'package:fcourt/features/auth/data/models/user_model.dart';
import 'package:fcourt/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:fcourt/features/auth/domain/entities/upload_document.dart';
import 'package:fcourt/features/auth/domain/entities/user_role.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers.dart';

class MockRemote extends Mock implements AuthRemoteDataSource {}

void main() {
  const savedTokens = AuthTokens(accessToken: 'old-access', refreshToken: 'old-refresh');
  late MockRemote remote;
  late InMemoryTokenStorage tokens;
  late AuthRepositoryImpl repository;

  final session = AuthSessionModel.fromJson(authResponseJson());

  setUp(() {
    remote = MockRemote();
    tokens = InMemoryTokenStorage();
    repository = AuthRepositoryImpl(remote, tokens);
  });

  group('login', () {
    test('lưu cặp token và trả người dùng', () async {
      when(() => remote.login('customer@demo.com', 'S3cret-pass'))
          .thenAnswer((_) async => session);

      final user = await repository.login(email: 'customer@demo.com', password: 'S3cret-pass');

      expect(user.email, 'customer@demo.com');
      expect(user.role, UserRole.customer);
      expect(
        await tokens.read(),
        const AuthTokens(accessToken: 'access-1', refreshToken: 'refresh-1'),
      );
    });

    test('sai mật khẩu: giữ lý do của BE và không lưu token', () async {
      when(() => remote.login(any(), any())).thenThrow(
        dioError(401, body: {'detail': 'Invalid email or password'}),
      );

      await expectLater(
        repository.login(email: 'customer@demo.com', password: 'wrong'),
        throwsA(const UnauthorizedFailure('Invalid email or password')),
      );
      expect(await tokens.read(), isNull);
    });

    test('tài khoản chưa được duyệt: 403 kèm lý do', () async {
      when(() => remote.login(any(), any())).thenThrow(
        dioError(403, body: {'detail': 'Account is awaiting approval'}),
      );

      await expectLater(
        repository.login(email: 'owner@demo.com', password: 'S3cret-pass'),
        throwsA(const ServerFailure('Account is awaiting approval', statusCode: 403)),
      );
    });

    test('response thiếu token: UnknownFailure, không lưu gì', () async {
      when(() => remote.login(any(), any()))
          .thenAnswer((_) async => AuthSessionModel.fromJson(const {'user': {}}));

      await expectLater(
        repository.login(email: 'a@demo.com', password: 'x'),
        throwsA(const UnknownFailure()),
      );
      expect(await tokens.read(), isNull);
    });

    test('mất mạng thành NetworkFailure', () async {
      when(() => remote.login(any(), any())).thenThrow(
        dioError(null, type: DioExceptionType.connectionError),
      );

      await expectLater(
        repository.login(email: 'a@demo.com', password: 'x'),
        throwsA(const NetworkFailure()),
      );
    });
  });

  group('registerCustomer', () {
    test('đăng nhập luôn: lưu token và trả người dùng', () async {
      when(
        () => remote.registerCustomer(
          fullName: 'An Nguyen',
          email: 'customer@demo.com',
          phone: '0909000001',
          password: 'S3cret-pass',
        ),
      ).thenAnswer((_) async => session);

      final user = await repository.registerCustomer(
        fullName: 'An Nguyen',
        email: 'customer@demo.com',
        phone: '0909000001',
        password: 'S3cret-pass',
      );

      expect(user.id, 7);
      expect((await tokens.read())?.accessToken, 'access-1');
    });

    test('email trùng: 409 và lỗi validation theo field được giữ lại', () async {
      when(
        () => remote.registerCustomer(
          fullName: any(named: 'fullName'),
          email: any(named: 'email'),
          phone: any(named: 'phone'),
          password: any(named: 'password'),
        ),
      ).thenThrow(
        dioError(400, body: {
          'detail': 'Invalid request fields',
          'errors': [
            {'field': 'email', 'message': 'email is invalid'},
          ],
        }),
      );

      await expectLater(
        repository.registerCustomer(
          fullName: 'An',
          email: 'bad',
          phone: '0909000001',
          password: 'S3cret-pass',
        ),
        throwsA(
          const ServerFailure(
            'Invalid request fields',
            statusCode: 400,
            fieldErrors: {'email': 'email is invalid'},
          ),
        ),
      );
      expect(await tokens.read(), isNull);
    });
  });

  group('registerCourtOwner', () {
    const legal = [UploadDocument(name: 'licence.pdf', path: '/tmp/licence.pdf')];

    test('gửi hồ sơ nhưng không lưu token (chờ duyệt)', () async {
      when(
        () => remote.registerCourtOwner(
          fullName: 'Chu San',
          email: 'owner@demo.com',
          phone: '0909000003',
          password: 'S3cret-pass',
          legalDocuments: legal,
          courtImages: const [],
        ),
      ).thenAnswer((_) async {});

      await repository.registerCourtOwner(
        fullName: 'Chu San',
        email: 'owner@demo.com',
        phone: '0909000003',
        password: 'S3cret-pass',
        legalDocuments: legal,
      );

      expect(await tokens.read(), isNull);
    });

    test('kho lưu trữ tài liệu lỗi: 503 được đổi thành Failure', () async {
      when(
        () => remote.registerCourtOwner(
          fullName: any(named: 'fullName'),
          email: any(named: 'email'),
          phone: any(named: 'phone'),
          password: any(named: 'password'),
          legalDocuments: any(named: 'legalDocuments'),
          courtImages: any(named: 'courtImages'),
        ),
      ).thenThrow(dioError(503, body: {'detail': 'Document storage is unavailable'}));

      await expectLater(
        repository.registerCourtOwner(
          fullName: 'Chu San',
          email: 'owner@demo.com',
          phone: '0909000003',
          password: 'S3cret-pass',
          legalDocuments: legal,
        ),
        throwsA(const ServerFailure('Document storage is unavailable', statusCode: 503)),
      );
    });
  });

  group('restoreSession', () {
    test('chưa có token thì không hỏi BE và trả null', () async {
      expect(await repository.restoreSession(), isNull);

      verifyNever(() => remote.fetchProfile());
    });

    test('có token và BE trả profile thì trả người dùng', () async {
      await tokens.save(savedTokens);
      when(() => remote.fetchProfile()).thenAnswer((_) async => UserModel.fromJson(userJson()));

      final user = await repository.restoreSession();

      expect(user?.email, 'customer@demo.com');
      expect(await tokens.read(), savedTokens);
    });

    test('401 sau khi refresh thất bại: phiên chết, xóa token', () async {
      await tokens.save(savedTokens);
      when(() => remote.fetchProfile()).thenThrow(dioError(401));

      expect(await repository.restoreSession(), isNull);
      expect(await tokens.read(), isNull);
    });

    test('403 vì tài khoản bị khóa: phiên chết, xóa token', () async {
      await tokens.save(savedTokens);
      when(() => remote.fetchProfile())
          .thenThrow(dioError(403, body: {'detail': 'Account is locked'}));

      expect(await repository.restoreSession(), isNull);
      expect(await tokens.read(), isNull);
    });

    test('404 vì tài khoản không còn: phiên chết, xóa token', () async {
      await tokens.save(savedTokens);
      when(() => remote.fetchProfile())
          .thenThrow(dioError(404, body: {'detail': 'Account not found'}));

      expect(await repository.restoreSession(), isNull);
      expect(await tokens.read(), isNull);
    });

    test('body sai hợp đồng thành UnknownFailure, giữ token', () async {
      await tokens.save(savedTokens);
      when(() => remote.fetchProfile())
          .thenAnswer((_) async => UserModel.fromJson(const {'email': 'x@demo.com'}));

      await expectLater(repository.restoreSession(), throwsA(const UnknownFailure()));
      expect(await tokens.read(), savedTokens);
    });

    test('mất mạng thì ném lỗi và giữ token để lần sau thử lại', () async {
      await tokens.save(savedTokens);
      when(() => remote.fetchProfile())
          .thenThrow(dioError(null, type: DioExceptionType.connectionTimeout));

      await expectLater(repository.restoreSession(), throwsA(const NetworkFailure()));
      expect(await tokens.read(), savedTokens);
    });

    test('lỗi máy chủ 500 cũng giữ token', () async {
      await tokens.save(savedTokens);
      when(() => remote.fetchProfile()).thenThrow(dioError(500));

      await expectLater(repository.restoreSession(), throwsA(isA<ServerFailure>()));
      expect(await tokens.read(), savedTokens);
    });
  });

  group('updateProfile', () {
    test('trả người dùng đã cập nhật', () async {
      when(() => remote.updateProfile('New Name', '0911222333'))
          .thenAnswer((_) async => UserModel.fromJson(userJson()));

      final user = await repository.updateProfile(fullName: 'New Name', phone: '0911222333');

      expect(user.id, 7);
    });

    test('số điện thoại đã có người dùng: 409', () async {
      when(() => remote.updateProfile(any(), any())).thenThrow(
        dioError(409, body: {'detail': 'Phone number is already registered'}),
      );

      await expectLater(
        repository.updateProfile(fullName: 'New Name', phone: '0911222333'),
        throwsA(const ServerFailure('Phone number is already registered', statusCode: 409)),
      );
    });
  });

  group('logout', () {
    test('thu hồi refresh token ở BE rồi xóa token cục bộ', () async {
      await tokens.save(savedTokens);
      when(() => remote.logout('old-refresh')).thenAnswer((_) async {});

      await repository.logout();

      verify(() => remote.logout('old-refresh')).called(1);
      expect(await tokens.read(), isNull);
    });

    test('BE không trả lời vẫn xóa token cục bộ và không ném lỗi', () async {
      await tokens.save(savedTokens);
      when(() => remote.logout(any()))
          .thenThrow(dioError(null, type: DioExceptionType.connectionError));

      await repository.logout();

      expect(await tokens.read(), isNull);
    });

    test('chưa đăng nhập thì không gọi BE', () async {
      await repository.logout();

      verifyNever(() => remote.logout(any()));
    });
  });
}
