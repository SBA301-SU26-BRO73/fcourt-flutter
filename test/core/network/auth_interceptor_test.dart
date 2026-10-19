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

  int get refreshCalls => adapter.requests
      .where((r) => r.path == ApiEndpoints.authRefresh)
      .length;
}

ResponseBody _refreshOk() => jsonResponse(200, {
      'httpStatus': 200,
      'data': {'accessToken': 'a2', 'refreshToken': 'r2', 'expiresIn': 900},
    });

void main() {
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

    expect(h.adapter.requests.single.headers.containsKey('Authorization'), isFalse);
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
    final h = _Harness(
      (o) => jsonResponse(401, {'message': 'expired'}),
    );

    await expectLater(
      h.dio.get<dynamic>('/api/x'),
      throwsA(isA<DioException>()),
    );

    expect(await h.storage.read(), isNull);
    expect(h.sessionExpiredCount, 1);
  });

  test('không refresh khi request đặt skipAuth', () async {
    final h = _Harness((_) => jsonResponse(401, {'message': 'bad credentials'}));

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
