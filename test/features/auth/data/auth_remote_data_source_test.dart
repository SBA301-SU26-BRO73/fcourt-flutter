import 'dart:io';

import 'package:dio/dio.dart';
import 'package:fcourt/core/network/auth_interceptor.dart';
import 'package:fcourt/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:fcourt/features/auth/domain/entities/upload_document.dart';
import 'package:fcourt/features/auth/domain/entities/user_role.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_adapter.dart';
import '../helpers.dart';

void main() {
  late FakeAdapter adapter;
  late AuthRemoteDataSource remote;

  void useResponse(FakeHandler handler) {
    adapter = FakeAdapter(handler);
    remote = AuthRemoteDataSource(
      Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = adapter,
    );
  }

  group('đăng nhập và đăng ký khách hàng', () {
    test('login gửi email, mật khẩu không kèm token và đọc response phẳng', () async {
      useResponse((_) => jsonResponse(200, authResponseJson()));

      final session = await remote.login('customer@demo.com', 'S3cret-pass');

      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/api/auth/login');
      expect(request.data, {'email': 'customer@demo.com', 'password': 'S3cret-pass'});
      expect(request.extra[AuthInterceptor.skipAuthKey], isTrue);
      expect(session.accessToken, 'access-1');
      expect(session.refreshToken, 'refresh-1');
      expect(session.user.toEntity().role, UserRole.customer);
    });

    test('registerCustomer gửi đủ bốn trường tới endpoint đăng ký', () async {
      useResponse((_) => jsonResponse(201, authResponseJson()));

      await remote.registerCustomer(
        fullName: 'An Nguyen',
        email: 'customer@demo.com',
        phone: '0909000001',
        password: 'S3cret-pass',
      );

      final request = adapter.requests.single;
      expect(request.path, '/api/auth/register/customer');
      expect(request.data, {
        'fullName': 'An Nguyen',
        'email': 'customer@demo.com',
        'phone': '0909000001',
        'password': 'S3cret-pass',
      });
      expect(request.extra[AuthInterceptor.skipAuthKey], isTrue);
    });

    test('lỗi HTTP được ném nguyên dạng DioException để repository xử lý', () async {
      useResponse((_) => jsonResponse(401, {'detail': 'Invalid email or password'}));

      await expectLater(
        remote.login('customer@demo.com', 'wrong'),
        throwsA(isA<DioException>()),
      );
    });
  });

  group('đăng ký chủ sân (multipart)', () {
    late Directory tempDir;

    setUp(() => tempDir = Directory.systemTemp.createTempSync('fcourt_auth_test'));
    tearDown(() {
      try {
        tempDir.deleteSync(recursive: true);
      } on FileSystemException {
        // Windows: MultipartFile.fromFile giữ handle vì adapter giả không đọc stream. Thư mục tạm do OS dọn.
      }
    });

    UploadDocument file(String name) {
      final path = '${tempDir.path}${Platform.pathSeparator}$name';
      File(path).writeAsBytesSync([1, 2, 3]);
      return UploadDocument(name: name, path: path);
    }

    test('gửi các trường, giấy tờ pháp lý và ảnh sân dưới đúng tên field', () async {
      useResponse((_) => jsonResponse(201, {'id': 9, 'status': 'PENDING_APPROVAL'}));

      await remote.registerCourtOwner(
        fullName: 'Chu San',
        email: 'owner@demo.com',
        phone: '0909000003',
        password: 'S3cret-pass',
        legalDocuments: [file('licence.pdf'), file('id.PNG')],
        courtImages: [file('front.jpg')],
      );

      final request = adapter.requests.single;
      final form = request.data as FormData;
      expect(request.path, '/api/auth/register/court-owner');
      expect(request.extra[AuthInterceptor.skipAuthKey], isTrue);
      expect(Map.fromEntries(form.fields), {
        'fullName': 'Chu San',
        'email': 'owner@demo.com',
        'phone': '0909000003',
        'password': 'S3cret-pass',
      });
      expect(form.files.map((e) => e.key), ['legalDocuments', 'legalDocuments', 'courtImages']);
      expect(form.files.map((e) => e.value.filename), ['licence.pdf', 'id.PNG', 'front.jpg']);
      expect(
        form.files.map((e) => e.value.contentType?.mimeType),
        ['application/pdf', 'image/png', 'image/jpeg'],
      );
    });

    test('không có ảnh sân thì chỉ gửi giấy tờ pháp lý', () async {
      useResponse((_) => jsonResponse(201, {'id': 9}));

      await remote.registerCourtOwner(
        fullName: 'Chu San',
        email: 'owner@demo.com',
        phone: '0909000003',
        password: 'S3cret-pass',
        legalDocuments: [file('licence.pdf')],
        courtImages: const [],
      );

      final form = adapter.requests.single.data as FormData;
      expect(form.files.map((e) => e.key), ['legalDocuments']);
    });
  });

  group('profile và đăng xuất', () {
    test('fetchProfile gọi GET có token', () async {
      useResponse((_) => jsonResponse(200, userJson()));

      final user = await remote.fetchProfile();

      final request = adapter.requests.single;
      expect(request.method, 'GET');
      expect(request.path, '/api/auth/profile');
      expect(request.extra.containsKey(AuthInterceptor.skipAuthKey), isFalse);
      expect(user.email, 'customer@demo.com');
    });

    test('updateProfile gọi PATCH với họ tên và số điện thoại', () async {
      useResponse((_) => jsonResponse(200, userJson()));

      await remote.updateProfile('New Name', '0911222333');

      final request = adapter.requests.single;
      expect(request.method, 'PATCH');
      expect(request.path, '/api/auth/profile');
      expect(request.data, {'fullName': 'New Name', 'phone': '0911222333'});
    });

    test('logout gửi refresh token và không kích hoạt refresh', () async {
      useResponse((_) => ResponseBody.fromString('', 204));

      await remote.logout('refresh-1');

      final request = adapter.requests.single;
      expect(request.path, '/api/auth/logout');
      expect(request.data, {'refreshToken': 'refresh-1'});
      expect(request.extra[AuthInterceptor.skipAuthKey], isTrue);
    });
  });

  group('contentTypeOf', () {
    test('nhận đúng các loại tệp BE chấp nhận, không phân biệt hoa thường', () {
      expect(AuthRemoteDataSource.contentTypeOf('a.jpg'), 'image/jpeg');
      expect(AuthRemoteDataSource.contentTypeOf('a.JPEG'), 'image/jpeg');
      expect(AuthRemoteDataSource.contentTypeOf('a.png'), 'image/png');
      expect(AuthRemoteDataSource.contentTypeOf('a.webp'), 'image/webp');
      expect(AuthRemoteDataSource.contentTypeOf('a.PDF'), 'application/pdf');
    });

    test('đuôi lạ hoặc không có đuôi gửi octet-stream để BE từ chối', () {
      expect(AuthRemoteDataSource.contentTypeOf('a.exe'), 'application/octet-stream');
      expect(AuthRemoteDataSource.contentTypeOf('noextension'), 'application/octet-stream');
    });
  });
}
