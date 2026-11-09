import 'package:dio/dio.dart';
import 'package:fcourt/features/notifications/data/device_registry.dart';
import 'package:fcourt/features/notifications/data/device_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_adapter.dart';

class _MemoryPushDeviceStore implements PushDeviceStore {
  String? tokenCache;
  int clearCount = 0;

  @override
  Future<String> deviceId() async => 'stable-install-id';

  @override
  Future<String?> readToken() async => tokenCache;

  @override
  Future<void> saveToken(String token) async => tokenCache = token;

  @override
  Future<void> clearToken() async {
    clearCount++;
    tokenCache = null;
  }
}

void main() {
  test(
    'PUT /devices sends the contract fields and caches a successful token',
    () async {
      final adapter = FakeAdapter((_) => ResponseBody.fromString('', 204));
      final store = _MemoryPushDeviceStore();
      final registry = DeviceRegistry(
        dio: Dio(BaseOptions(baseUrl: 'https://api.test'))
          ..httpClientAdapter = adapter,
        store: store,
        appVersion: () async => '1.0.0',
      );

      await registry.register('fcm-token');

      final request = adapter.requests.single;
      expect(request.method, 'PUT');
      expect(request.path, '/devices');
      expect(request.data, {
        'deviceId': 'stable-install-id',
        'token': 'fcm-token',
        'platform': 'ANDROID',
        'appVersion': '1.0.0',
      });
      expect(store.tokenCache, 'fcm-token');
    },
  );

  test(
    'unregister(deleteRemote: false) clears cache without a request',
    () async {
      final adapter = FakeAdapter((_) => ResponseBody.fromString('', 204));
      final store = _MemoryPushDeviceStore()..tokenCache = 'cached-token';
      final registry = DeviceRegistry(
        dio: Dio(BaseOptions(baseUrl: 'https://api.test'))
          ..httpClientAdapter = adapter,
        store: store,
        appVersion: () async => '1.0.0',
      );

      await registry.unregister(deleteRemote: false);

      expect(adapter.requests, isEmpty);
      expect(store.tokenCache, isNull);
    },
  );

  test('preserves Dio errors and does not cache a rejected token', () async {
    final adapter = FakeAdapter(
      (_) => jsonResponse(503, {'error': 'unavailable'}),
    );
    final store = _MemoryPushDeviceStore();
    final registry = DeviceRegistry(
      dio: Dio(BaseOptions(baseUrl: 'https://api.test'))
        ..httpClientAdapter = adapter,
      store: store,
      appVersion: () async => '1.0.0',
    );

    await expectLater(
      registry.register('fcm-token'),
      throwsA(isA<DioException>()),
    );
    expect(store.tokenCache, isNull);
  });

  test(
    'DELETE /devices/{deviceId} clears local token cache even on error',
    () async {
      final adapter = FakeAdapter(
        (_) => jsonResponse(500, {'error': 'failed'}),
      );
      final store = _MemoryPushDeviceStore()..tokenCache = 'cached-token';
      final registry = DeviceRegistry(
        dio: Dio(BaseOptions(baseUrl: 'https://api.test'))
          ..httpClientAdapter = adapter,
        store: store,
        appVersion: () async => '1.0.0',
      );

      await expectLater(registry.unregister(), throwsA(isA<DioException>()));
      expect(adapter.requests.single.method, 'DELETE');
      expect(adapter.requests.single.path, '/devices/stable-install-id');
      expect(store.tokenCache, isNull);
      expect(store.clearCount, 1);
    },
  );
}
