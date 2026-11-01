import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../storage/token_storage.dart';
import 'auth_interceptor.dart';

Dio createDio(
  AppConfig config,
  TokenStorage tokenStorage, {
  void Function()? onSessionExpired,
  String? baseUrl,
}) {
  final options = BaseOptions(
    baseUrl: baseUrl ?? config.apiBaseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 20),
    headers: const {'Accept': 'application/json'},
  );

  final dio = Dio(options);
  final refreshDio = Dio(options.copyWith(baseUrl: config.apiBaseUrl));

  dio.interceptors.add(
    AuthInterceptor(
      dio: dio,
      refreshDio: refreshDio,
      tokenStorage: tokenStorage,
      onSessionExpired: onSessionExpired,
    ),
  );

  if (config.isDev) {
    // Không log header để tránh lộ token.
    dio.interceptors.add(
      LogInterceptor(
        requestHeader: false,
        requestBody: false,
        responseBody: false,
      ),
    );
  }
  return dio;
}
