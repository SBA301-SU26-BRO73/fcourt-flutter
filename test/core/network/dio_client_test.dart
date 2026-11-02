import 'package:fcourt/core/config/app_config.dart';
import 'package:fcourt/core/network/auth_interceptor.dart';
import 'package:fcourt/core/network/dio_client.dart';
import 'package:fcourt/core/storage/token_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('service clients refresh tokens against the auth service', () {
    final dio = createDio(
      const AppConfig(
        env: AppEnv.prod,
        apiBaseUrl: 'https://api.test',
        authBaseUrl: 'https://auth.test',
      ),
      InMemoryTokenStorage(null),
      baseUrl: 'https://staff.test',
    );

    final interceptor = dio.interceptors.whereType<AuthInterceptor>().single;

    expect(dio.options.baseUrl, 'https://staff.test');
    expect(interceptor.refreshDio.options.baseUrl, 'https://auth.test');
  });
}
