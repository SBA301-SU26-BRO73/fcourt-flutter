import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../storage/token_storage.dart';
import 'auth_interceptor.dart';

/// [baseUrl] cho phép trỏ tới một service riêng (ví dụ facility-service);
/// mặc định là `API_BASE_URL`. Request refresh token luôn đi qua
/// `API_BASE_URL` vì endpoint refresh thuộc auth/gateway, không thuộc service đó.
Dio createDio(
  AppConfig config,
  TokenStorage tokenStorage, {
  String? baseUrl,
  void Function()? onSessionExpired,
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
