import 'package:dio/dio.dart';

import '../storage/token_storage.dart';
import 'api_endpoints.dart';

/// Gắn Bearer token vào request và tự refresh khi gặp 401.
///
/// - Kế thừa [QueuedInterceptor] nên các request lỗi 401 đồng thời được xử lý
///   lần lượt: request đầu refresh token, các request sau dùng lại token mới.
///   Nhờ vậy refresh token (chỉ dùng được một lần, BE thu hồi mọi phiên khi thấy
///   token cũ bị dùng lại) không bao giờ bị gửi hai lần.
/// - Mỗi request chỉ được thử lại tối đa một lần.
/// - BE từ chối refresh (4xx: token sai, hết hạn, tài khoản bị khóa) thì xóa token
///   và gọi [onSessionExpired]. Mất mạng hoặc BE lỗi 5xx thì giữ token và trả lỗi
///   đó, để người dùng không bị đăng xuất chỉ vì mạng chập chờn.
///
/// Đặt `extra: {AuthInterceptor.skipAuthKey: true}` cho request không cần token
/// (đăng nhập, đăng ký...).
class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor({
    required this.refreshDio,
    required this.tokenStorage,
    this.refreshPath = ApiEndpoints.authRefresh,
    this.onSessionExpired,
  });

  static const skipAuthKey = 'skipAuth';
  static const _retriedKey = 'authRetried';

  /// Dio riêng không gắn interceptor này, dùng để refresh và để gửi lại request.
  ///
  /// Không gửi lại qua Dio chính: lỗi của request gửi lại sẽ xếp hàng sau chính
  /// [onError] đang chờ nó, làm hàng đợi của [QueuedInterceptor] kẹt vĩnh viễn.
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

    AuthTokens? tokens = current;
    if (!alreadyRefreshed) {
      try {
        tokens = await _refresh(current);
      } on DioException catch (refreshError) {
        if (!_isRejected(refreshError)) {
          // Lỗi tạm thời: giữ phiên, trả lỗi thật để UI báo mất mạng hoặc máy chủ bận.
          return handler.next(refreshError);
        }
        tokens = null;
      }
    }
    if (tokens == null) {
      await tokenStorage.clear();
      onSessionExpired?.call();
      return handler.next(err);
    }

    try {
      request.headers['Authorization'] = 'Bearer ${tokens.accessToken}';
      request.extra[_retriedKey] = true;
      handler.resolve(await refreshDio.fetch<dynamic>(request));
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  /// Trả `null` khi BE trả 2xx nhưng không có access token. Ném [DioException]
  /// khi gọi refresh thất bại.
  Future<AuthTokens?> _refresh(AuthTokens current) async {
    final response = await refreshDio.post<dynamic>(
      refreshPath,
      data: {'refreshToken': current.refreshToken},
      options: Options(extra: {skipAuthKey: true}),
    );
    final data = _tokenPayload(response.data);
    if (data == null) return null;
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
  }

  /// BE đã trả lời và từ chối refresh token (400, 401, 403...): phiên không cứu được.
  static bool _isRejected(DioException error) {
    final status = error.response?.statusCode;
    return status != null && status >= 400 && status < 500;
  }
}

/// auth-service trả token ở gốc JSON; các service cũ bọc trong `data`. Chấp nhận cả hai.
Map<dynamic, dynamic>? _tokenPayload(Object? body) {
  if (body is! Map) return null;
  final wrapped = body['data'];
  return wrapped is Map ? wrapped : body;
}
