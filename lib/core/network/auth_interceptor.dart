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
    this.allowRefresh = true,
  });

  static const skipAuthKey = 'skipAuth';
  static const _retriedKey = 'authRetried';
  static const _retryAccessKey = 'authRetryAccess';
  static final _sessions = Expando<_RefreshSession>();
  final Dio dio;
  final Dio refreshDio;
  final TokenStorage tokenStorage;
  final String refreshPath;
  final void Function()? onSessionExpired;
  final bool allowRefresh;
  _RefreshSession get _session => _sessions[tokenStorage] ??= _RefreshSession();

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.extra[skipAuthKey] != true) {
      final tokens = await tokenStorage.read();
      final expected = options.extra[_retryAccessKey];
      if (expected != null && tokens?.accessToken != expected) {
        return handler.reject(
          DioException(
            requestOptions: options,
            type: DioExceptionType.badResponse,
            response: Response<dynamic>(
              requestOptions: options,
              statusCode: 401,
            ),
          ),
        );
      }
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
    if (!allowRefresh ||
        err.response?.statusCode != 401 ||
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
        tokens = await session.reuse(sent, current);
      } else {
        tokens = await session.run(current, () => _refresh(current));
        if (tokens == null && await tokenStorage.read() == current) {
          await tokenStorage.clear();
          onSessionExpired?.call();
        }
      }
      if (tokens == null) return handler.next(err);
      // A multipart body has already been finalized on the first upload.
      final body = request.data;
      if (body is FormData) request.data = body.clone();
      request.headers['Authorization'] = 'Bearer ${tokens.accessToken}';
      request.extra[_retriedKey] = true;
      request.extra[_retryAccessKey] = tokens.accessToken;
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
      // A logout/account switch while refreshing must not resurrect the old session.
      if (await tokenStorage.read() != current) return null;
      await tokenStorage.save(tokens);
      return tokens;
    } on DioException catch (e) {
      if (_isRejected(e)) {
        return null;
      }
      // Transient refresh failures preserve the session and remain retryable offline.
      rethrow;
    }
  }
}

class _RefreshSession {
  final _pending = <AuthTokens, Future<AuthTokens?>>{};
  final _rotated = <String, AuthTokens>{};
  Future<AuthTokens?> reuse(Object? sent, AuthTokens current) async {
    final source = _pending.keys
        .where((tokens) => 'Bearer ${tokens.accessToken}' == sent)
        .firstOrNull;
    final value = source == null ? _rotated[sent] : await _pending[source];
    return value == current ? current : null;
  }

  Future<AuthTokens?> run(
    AuthTokens current,
    Future<AuthTokens?> Function() action,
  ) {
    return _pending[current] ??= action()
        .then((value) {
          if (value != null) {
            _rotated.clear();
            _rotated['Bearer ${current.accessToken}'] = value;
          }
          return value;
        })
        .whenComplete(() {
          _pending.remove(current);
        });
  }
}

bool _isRejected(DioException error) {
  final status = error.response?.statusCode;
  return status != null && status >= 400 && status < 500 && status != 429;
}

/// auth-service returns tokens at the JSON root; older services wrap them in `data`.
Map<dynamic, dynamic>? _tokenPayload(Object? body) {
  if (body is! Map) return null;
  final wrapped = body['data'];
  return wrapped is Map ? wrapped : body;
}
