import 'package:dio/dio.dart';

import '../storage/token_storage.dart';
import 'api_endpoints.dart';

/// Authenticate requests and retry once after a session-wide refresh.
/// Plain Interceptor avoids waiting on its own error queue during replay.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required this.dio,
    required this.refreshDio,
    required this.tokenStorage,
    this.refreshPath = ApiEndpoints.authRefresh,
    this.onSessionExpired,
  });

  static const skipAuthKey = 'skipAuth';
  static const _retriedKey = 'authRetried';
  static final _sessions = Expando<_RefreshSession>();
  final Dio dio;
  final Dio refreshDio;
  final TokenStorage tokenStorage;
  final String refreshPath;
  final void Function()? onSessionExpired;
  _RefreshSession get _session => _sessions[tokenStorage] ??= _RefreshSession();

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.extra[skipAuthKey] != true) {
      final tokens = await tokenStorage.read();
      if (tokens != null) {
        options.headers['Authorization'] = 'Bearer ${tokens.accessToken}';
      } else {
        options.headers.remove('Authorization');
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
    if (err.response?.statusCode != 401 ||
        request.extra[skipAuthKey] == true ||
        request.extra[_retriedKey] == true) {
      return handler.next(err);
    }
    final current = await tokenStorage.read();
    if (current == null) return handler.next(err);
    try {
      final sent = request.headers['Authorization'];
      final session = _session;
      final AuthTokens? tokens;
      if (sent != 'Bearer ${current.accessToken}') {
        // Never replay an old account's operation under a newly signed-in account.
        tokens = session.previousAccess == sent && session.result == current
            ? current
            : null;
      } else {
        tokens = await session.run(current, () => _refresh(current));
        if (tokens == null && await tokenStorage.read() == current) {
          await tokenStorage.clear();
          onSessionExpired?.call();
        }
      }
      if (tokens == null) return handler.next(err);
      request.headers['Authorization'] = 'Bearer ${tokens.accessToken}';
      request.extra[_retriedKey] = true;
      handler.resolve(await dio.fetch<dynamic>(request));
    } on DioException catch (error) {
      handler.next(error);
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
      // A logout/account switch while refreshing must not resurrect the old session.
      if (await tokenStorage.read() != current) return null;
      await tokenStorage.save(tokens);
      return tokens;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        return null;
      }
      // Transient refresh failures preserve the session and remain retryable offline.
      rethrow;
    }
  }
}

class _RefreshSession {
  Future<AuthTokens?>? _pending;
  String? previousAccess;
  AuthTokens? result;
  Future<AuthTokens?> run(
    AuthTokens current,
    Future<AuthTokens?> Function() action,
  ) {
    if (_pending != null) return _pending!;
    previousAccess = 'Bearer ${current.accessToken}';
    return _pending = action()
        .then((value) => result = value)
        .whenComplete(() => _pending = null);
  }
}
