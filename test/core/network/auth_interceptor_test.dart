import 'package:dio/dio.dart';
import 'package:fcourt/core/network/api_endpoints.dart';
import 'package:fcourt/core/network/auth_interceptor.dart';
import 'package:fcourt/core/storage/token_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_adapter.dart';

const _oldTokens = AuthTokens(accessToken: 'a1', refreshToken: 'r1');

class _Harness {
  _Harness(FakeHandler handler, {AuthTokens? tokens = _oldTokens})
    : adapter = FakeAdapter(handler),
      storage = InMemoryTokenStorage(tokens) {
    dio = Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = adapter;
    final refreshDio = Dio(BaseOptions(baseUrl: 'http://test'))
      ..httpClientAdapter = adapter;
    dio.interceptors.add(
      AuthInterceptor(
        dio: dio,
        refreshDio: refreshDio,
        tokenStorage: storage,
        onSessionExpired: () => sessionExpiredCount++,
      ),
    );
  }

  final FakeAdapter adapter;
  final InMemoryTokenStorage storage;
  late final Dio dio;
  int sessionExpiredCount = 0;

  int get refreshCalls =>
      adapter.requests.where((r) => r.path == ApiEndpoints.authRefresh).length;
}

ResponseBody _refreshOk() => jsonResponse(200, {
  'httpStatus': 200,
  'data': {'accessToken': 'a2', 'refreshToken': 'r2', 'expiresIn': 900},
});

void main() {
  test(
    'receipt multipart is cloned before retry after token refresh',
    () async {
      final h = _Harness((o) {
        if (o.path == ApiEndpoints.authRefresh) return _refreshOk();
        return o.headers['Authorization'] == 'Bearer a2'
            ? jsonResponse(200, {'id': 1, 'status': 'PENDING'})
            : jsonResponse(401, {'message': 'expired'});
      });
      final body = FormData.fromMap({
        'file': MultipartFile.fromBytes([1, 2, 3], filename: 'receipt.jpg'),
      });
      final response = await h.dio.post<dynamic>(
        '/api/payments/42/upload-receipt',
        data: body,
      );
      expect(response.statusCode, 200);
      expect(h.refreshCalls, 1);
      expect(body.isFinalized, true);
      expect(h.adapter.requests.last.data, isNot(same(body)));
      expect(
        (h.adapter.requests.last.data as FormData).files.single.value.filename,
        'receipt.jpg',
      );
    },
  );
  test('gắn Bearer token vào request', () async {
    final h = _Harness((_) => jsonResponse(200, {'ok': true}));

    await h.dio.get<dynamic>('/api/x');

    expect(h.adapter.requests.single.headers['Authorization'], 'Bearer a1');
  });

  test('không gắn token khi đặt skipAuth', () async {
    final h = _Harness((_) => jsonResponse(200, {'ok': true}));

    await h.dio.get<dynamic>(
      '/api/x',
      options: Options(extra: {AuthInterceptor.skipAuthKey: true}),
    );

    expect(
      h.adapter.requests.single.headers.containsKey('Authorization'),
      isFalse,
    );
  });

  test('gặp 401 thì refresh token rồi gửi lại request', () async {
    final h = _Harness((o) {
      if (o.path == ApiEndpoints.authRefresh) return _refreshOk();
      return o.headers['Authorization'] == 'Bearer a2'
          ? jsonResponse(200, {'ok': true})
          : jsonResponse(401, {'message': 'expired'});
    });

    final response = await h.dio.get<dynamic>('/api/x');

    expect(response.statusCode, 200);
    expect(h.refreshCalls, 1);
    expect(h.adapter.requests.length, 3);
    expect(h.adapter.requests[1].data, {'refreshToken': 'r1'});
    expect(
      await h.storage.read(),
      const AuthTokens(accessToken: 'a2', refreshToken: 'r2'),
    );
  });

  test('nhiều request cùng 401 chỉ refresh một lần', () async {
    final h = _Harness((o) {
      if (o.path == ApiEndpoints.authRefresh) return _refreshOk();
      return o.headers['Authorization'] == 'Bearer a2'
          ? jsonResponse(200, {'ok': true})
          : jsonResponse(401, {'message': 'expired'});
    });

    final responses = await Future.wait([
      h.dio.get<dynamic>('/api/a'),
      h.dio.get<dynamic>('/api/b'),
      h.dio.get<dynamic>('/api/c'),
    ]);

    expect(responses.map((r) => r.statusCode), everyElement(200));
    expect(h.refreshCalls, 1);
  });

  test('refresh thất bại thì xóa token và báo hết phiên', () async {
    final h = _Harness((o) => jsonResponse(401, {'message': 'expired'}));

    await expectLater(
      h.dio.get<dynamic>('/api/x'),
      throwsA(isA<DioException>()),
    );

    expect(await h.storage.read(), isNull);
    expect(h.sessionExpiredCount, 1);
  });

  test('refresh đọc được response phẳng của auth-service', () async {
    final h = _Harness((o) {
      if (o.path == ApiEndpoints.authRefresh) {
        return jsonResponse(200, {
          'accessToken': 'a2',
          'refreshToken': 'r2',
          'tokenType': 'Bearer',
          'expiresIn': 900,
        });
      }
      return o.headers['Authorization'] == 'Bearer a2'
          ? jsonResponse(200, {'ok': true})
          : jsonResponse(401, {'detail': 'expired'});
    });

    final response = await h.dio.get<dynamic>('/api/x');

    expect(response.statusCode, 200);
    expect(
      await h.storage.read(),
      const AuthTokens(accessToken: 'a2', refreshToken: 'r2'),
    );
  });

  test('refresh không có refreshToken mới thì giữ token cũ', () async {
    final h = _Harness((o) {
      if (o.path == ApiEndpoints.authRefresh) {
        return jsonResponse(200, {'accessToken': 'a2'});
      }
      return o.headers['Authorization'] == 'Bearer a2'
          ? jsonResponse(200, {'ok': true})
          : jsonResponse(401, {'message': 'expired'});
    });

    await h.dio.get<dynamic>('/api/x');

    expect(
      await h.storage.read(),
      const AuthTokens(accessToken: 'a2', refreshToken: 'r1'),
    );
  });

  test('không refresh khi request đặt skipAuth', () async {
    final h = _Harness(
      (_) => jsonResponse(401, {'message': 'bad credentials'}),
    );

    await expectLater(
      h.dio.post<dynamic>(
        '/api/auth/login',
        options: Options(extra: {AuthInterceptor.skipAuthKey: true}),
      ),
      throwsA(isA<DioException>()),
    );

    expect(h.refreshCalls, 0);
    expect(await h.storage.read(), _oldTokens);
  });

  test('request gửi lại vẫn lỗi thì trả lỗi đó, không kẹt hàng đợi', () async {
    final h = _Harness((o) {
      if (o.path == ApiEndpoints.authRefresh) return _refreshOk();
      return o.headers['Authorization'] == 'Bearer a2'
          ? jsonResponse(409, {'detail': 'conflict'})
          : jsonResponse(401, {'detail': 'expired'});
    });

    final error = await h.dio
        .get<dynamic>('/api/x')
        .then<Object?>((_) => null, onError: (Object e) => e)
        .timeout(const Duration(seconds: 2));

    expect((error as DioException).response?.statusCode, 409);
    // Hàng đợi vẫn chạy: request sau vẫn nhận được lỗi của nó.
    final next = await h.dio
        .get<dynamic>('/api/y')
        .then<Object?>((_) => null, onError: (Object e) => e)
        .timeout(const Duration(seconds: 2));
    expect((next as DioException).response?.statusCode, 409);
  });

  test('request gửi lại vẫn 401 thì dừng, không refresh lần hai', () async {
    final h = _Harness((o) {
      if (o.path == ApiEndpoints.authRefresh) return _refreshOk();
      return jsonResponse(401, {'detail': 'expired'});
    });

    await expectLater(
      h.dio.get<dynamic>('/api/x').timeout(const Duration(seconds: 2)),
      throwsA(isA<DioException>()),
    );

    expect(h.refreshCalls, 1);
  });

  test('refresh mất mạng thì giữ token, không báo hết phiên', () async {
    final h = _Harness((o) {
      if (o.path == ApiEndpoints.authRefresh) {
        throw DioException.connectionError(
          requestOptions: o,
          reason: 'offline',
        );
      }
      return jsonResponse(401, {'detail': 'expired'});
    });

    final error = await h.dio
        .get<dynamic>('/api/x')
        .then<Object?>((_) => null, onError: (Object e) => e);

    expect((error as DioException).type, DioExceptionType.connectionError);
    expect(await h.storage.read(), _oldTokens);
    expect(h.sessionExpiredCount, 0);
  });

  test('refresh lỗi 5xx thì giữ token, không báo hết phiên', () async {
    final h = _Harness((o) {
      if (o.path == ApiEndpoints.authRefresh) {
        return jsonResponse(503, {'detail': 'down'});
      }
      return jsonResponse(401, {'detail': 'expired'});
    });

    final error = await h.dio
        .get<dynamic>('/api/x')
        .then<Object?>((_) => null, onError: (Object e) => e);

    expect((error as DioException).response?.statusCode, 503);
    expect(await h.storage.read(), _oldTokens);
    expect(h.sessionExpiredCount, 0);
  });

  test('refresh bị throttle 429 thì giữ token, không báo hết phiên', () async {
    final h = _Harness((o) {
      if (o.path == ApiEndpoints.authRefresh) {
        return jsonResponse(429, {'detail': 'Too many requests'});
      }
      return jsonResponse(401, {'detail': 'expired'});
    });

    final error = await h.dio
        .get<dynamic>('/api/x')
        .then<Object?>((_) => null, onError: (Object e) => e);

    expect((error as DioException).response?.statusCode, 429);
    expect(await h.storage.read(), _oldTokens);
    expect(h.sessionExpiredCount, 0);
  });

  test('refresh bị từ chối 403 (tài khoản khóa) thì xóa token', () async {
    final h = _Harness((o) {
      if (o.path == ApiEndpoints.authRefresh) {
        return jsonResponse(403, {'detail': 'Account is locked'});
      }
      return jsonResponse(401, {'detail': 'expired'});
    });

    await expectLater(
      h.dio.get<dynamic>('/api/x'),
      throwsA(isA<DioException>()),
    );

    expect(await h.storage.read(), isNull);
    expect(h.sessionExpiredCount, 1);
  });

  test('không có token thì trả lỗi 401 nguyên trạng', () async {
    final h = _Harness(
      (_) => jsonResponse(401, {'message': 'expired'}),
      tokens: null,
    );

    await expectLater(
      h.dio.get<dynamic>('/api/x'),
      throwsA(isA<DioException>()),
    );

    expect(h.refreshCalls, 0);
  });
}
