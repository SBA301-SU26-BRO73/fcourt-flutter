import 'package:dio/dio.dart';

import 'device_store.dart';

class DeviceRegistry {
  const DeviceRegistry({
    required this._dio,
    required this._store,
    required this._appVersion,
  });

  final Dio _dio;
  final PushDeviceStore _store;
  final Future<String> Function() _appVersion;

  Future<void> register(String token) async {
    if (await _store.readToken() == token) return;
    final deviceId = await _store.deviceId();
    final appVersion = await _appVersion();
    await _dio.put<void>(
      '/devices',
      data: {
        'deviceId': deviceId,
        'token': token,
        'platform': 'ANDROID',
        'appVersion': appVersion,
      },
    );
    await _store.saveToken(token);
  }

  Future<void> unregister({bool deleteRemote = true}) async {
    try {
      if (deleteRemote) {
        final deviceId = await _store.deviceId();
        await _dio.delete<void>('/devices/$deviceId');
      }
    } finally {
      await _store.clearToken();
    }
  }
}
