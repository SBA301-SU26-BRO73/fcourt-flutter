import 'package:dio/dio.dart';

import '../storage/token_storage.dart';
import 'api_endpoints.dart';

/// Gắn Bearer token vào request và tự refresh khi gặp 401.
///
/// - Kế thừa [QueuedInterceptor] nên các request lỗi 401 đồng thời được xử lý
///   lần lượt: request đầu refresh token, các request sau dùng lại token mới.
/// - Mỗi request chỉ được thử lại tối đa một lần.
/// - Refresh thất bại thì xóa token và gọi [onSessionExpired] (ví dụ về màn đăng nhập).
///
/// Đặt `extra: {AuthInterceptor.skipAuthKey: true}` cho request không cần token
/// (đăng nhập, đăng ký...).
class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor({
    required this.dio,
    required this.refreshDio,
    required this.tokenStorage,
    this.refreshPath = ApiEndpoints.authRefresh,
    this.onSessionExpired,
  });

  static const skipAuthKey = 'skipAuth';
  static const _retriedKey = 'authRetried';

  /// Dio chính, dùng để gửi lại request sau khi refresh.
  final Dio dio;

  /// Dio riêng không gắn interceptor này, dùng cho request refresh để tránh lặp vô hạn.
  final Dio refreshDio;
  final TokenStorage tokenStorage;
  final String refreshPath;
  final void Function()? onSessionExpired;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.extra[skipAuthKey] != true) {
      final tokens = await tokenStorage.read();
      if (tokens != null) {
        options.headers['Authorization'] = 'Bearer ${tokens.accessToken}';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final request = err.requestOptions;
    final isUnauthorized = err.response?.statusCode == 401;
    final canRetry =
        request.extra[skipAuthKey] != true && request.extra[_retriedKey] != true;
    if (!isUnauthorized || !canRetry) {
      return handler.next(err);
    }

    final current = await tokenStorage.read();
    if (current == null) {
      return handler.next(err);
    }

    // Request trước đó trong hàng đợi có thể đã refresh xong: dùng lại token mới.
    final sentHeader = request.headers['Authorization'];
    final alreadyRefreshed = sentHeader != 'Bearer ${current.accessToken}';

    final tokens = alreadyRefreshed ? current : await _refresh(current);
    if (tokens == null) {
      await tokenStorage.clear();
      onSessionExpired?.call();
      return handler.next(err);
    }

    try {
      request.headers['Authorization'] = 'Bearer ${tokens.accessToken}';
      request.extra[_retriedKey] = true;
      handler.resolve(await dio.fetch<dynamic>(request));
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  Future<AuthTokens?> _refresh(AuthTokens current) async {
    try {
      final response = await refreshDio.post<dynamic>(
        refreshPath,
        data: {'refreshToken': current.refreshToken},
        options: Options(extra: {skipAuthKey: true}),
      );
      final body = response.data;
      final data = body is Map ? body['data'] : null;
      if (data is! Map) return null;
      final access = data['accessToken'];
      if (access is! String || access.isEmpty) return null;
      final refresh = data['refreshToken'];
      final tokens = AuthTokens(
        accessToken: access,
        refreshToken: refresh is String && refresh.isNotEmpty
            ? refresh
            : current.refreshToken,
      );
      await tokenStorage.save(tokens);
      return tokens;
    } on DioException {
      return null;
    }
  }
}
