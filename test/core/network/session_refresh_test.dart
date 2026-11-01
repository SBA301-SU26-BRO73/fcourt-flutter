import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fcourt/core/network/auth_interceptor.dart';
import 'package:fcourt/core/storage/token_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_adapter.dart';

class _AsyncAdapter implements HttpClientAdapter {
  _AsyncAdapter(this.reply);
  final Future<ResponseBody> Function(RequestOptions) reply;
  @override
  Future<ResponseBody> fetch(
    RequestOptions r,
    Stream<Uint8List>? body,
    Future<void>? cancel,
  ) => reply(r);
  @override
  void close({bool force = false}) {}
}

const _old = AuthTokens(accessToken: 'old', refreshToken: 'r1');
Dio _client(TokenStorage storage, Dio refresh, {bool allowRefresh = true}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'));
  dio.httpClientAdapter = FakeAdapter(
    (r) => r.headers['Authorization'] == 'Bearer new'
        ? jsonResponse(200, {})
        : jsonResponse(401, {}),
  );
  dio.interceptors.add(
    AuthInterceptor(dio: dio, refreshDio: refresh, tokenStorage: storage),
  );
  return dio;
}

void main() {
  test('separate service clients share one rotating refresh', () async {
    final storage = InMemoryTokenStorage(_old);
    final entered = Completer<void>(), release = Completer<void>();
    var calls = 0;
    final refresh = Dio(BaseOptions(baseUrl: 'http://test'))
      ..httpClientAdapter = _AsyncAdapter((r) async {
        calls++;
        if (!entered.isCompleted) entered.complete();
        await release.future;
        return jsonResponse(200, {
          'data': {'accessToken': 'new', 'refreshToken': 'r2'},
        });
      });
    final clients = [_client(storage, refresh), _client(storage, refresh)];
    final results = Future.wait(
      clients.map((d) => d.get<dynamic>('/protected')),
    );
    await entered.future;
    release.complete();
    expect((await results).length, 2);
    expect(calls, 1);
    expect((await storage.read())?.refreshToken, 'r2');
  });
  test('second 401 completes with error without another refresh', () async {
    var calls = 0;
    final refresh = Dio(BaseOptions(baseUrl: 'http://test'))
      ..httpClientAdapter = FakeAdapter((r) {
        calls++;
        return jsonResponse(200, {
          'data': {'accessToken': 'new'},
        });
      });
    final client = _client(InMemoryTokenStorage(_old), refresh)
      ..httpClientAdapter = FakeAdapter((r) => jsonResponse(401, {}));
    await expectLater(
      client.get<dynamic>('/protected').timeout(const Duration(seconds: 2)),
      throwsA(isA<DioException>()),
    );
    expect(calls, 1);
  });
  test('logout during refresh cannot restore session', () async {
    final storage = InMemoryTokenStorage(_old);
    final refresh = Dio(BaseOptions(baseUrl: 'http://test'))
      ..httpClientAdapter = _AsyncAdapter((r) async {
        await storage.clear();
        return jsonResponse(200, {
          'data': {'accessToken': 'new'},
        });
      });
    await expectLater(
      _client(storage, refresh).get<dynamic>('/protected'),
      throwsA(isA<DioException>()),
    );
    expect(await storage.read(), isNull);
  });
  test('transient refresh failure preserves current credentials', () async {
    final storage = InMemoryTokenStorage(_old);
    final refresh = Dio(BaseOptions(baseUrl: 'http://test'))
      ..httpClientAdapter = FakeAdapter((r) => jsonResponse(503, {}));
    await expectLater(
      _client(storage, refresh).get<dynamic>('/protected'),
      throwsA(isA<DioException>()),
    );
    expect(await storage.read(), _old);
  });
  test(
    'account replacement during refresh is never overwritten or replayed',
    () async {
      const replacement = AuthTokens(
        accessToken: 'another-user',
        refreshToken: 'another-refresh',
      );
      final storage = InMemoryTokenStorage(_old);
      final refresh = Dio(BaseOptions(baseUrl: 'http://test'))
        ..httpClientAdapter = _AsyncAdapter((r) async {
          await storage.save(replacement);
          return jsonResponse(200, {
            'data': {'accessToken': 'new'},
          });
        });
      await expectLater(
        _client(storage, refresh).get<dynamic>('/protected'),
        throwsA(isA<DioException>()),
      );
      expect(await storage.read(), replacement);
    },
  );
  test('new account refresh never joins an old account operation', () async {
    final storage = InMemoryTokenStorage(_old);
    final entered = Completer<void>(), release = Completer<void>();
    final refresh = Dio(BaseOptions(baseUrl: 'http://test'))
      ..httpClientAdapter = _AsyncAdapter((r) async {
        if ((r.data as Map)['refreshToken'] == 'r1') {
          entered.complete();
          await release.future;
          return jsonResponse(200, {
            'data': {'accessToken': 'old-result'},
          });
        }
        return jsonResponse(200, {
          'data': {'accessToken': 'new', 'refreshToken': 'new-user-refresh'},
        });
      });
    final oldResult = expectLater(
      _client(storage, refresh).get<dynamic>('/protected'),
      throwsA(isA<DioException>()),
    );
    await entered.future;
    await storage.save(
      const AuthTokens(
        accessToken: 'another-user',
        refreshToken: 'another-refresh',
      ),
    );
    await _client(
      storage,
      refresh,
    ).get<dynamic>('/protected').timeout(const Duration(seconds: 2));
    release.complete();
    await oldResult;
    expect((await storage.read())?.refreshToken, 'new-user-refresh');
  });
  test(
    'background client cannot rotate or clear foreground credentials',
    () async {
      final storage = InMemoryTokenStorage(_old);
      var refreshCalls = 0;
      final refresh = Dio(BaseOptions(baseUrl: 'http://test'))
        ..httpClientAdapter = FakeAdapter((r) {
          refreshCalls++;
          return jsonResponse(401, {});
        });
      await expectLater(
        _client(
          storage,
          refresh,
          allowRefresh: false,
        ).get<dynamic>('/protected'),
        throwsA(isA<DioException>()),
      );
      expect(refreshCalls, 0);
      expect(await storage.read(), _old);
    },
  );
}
