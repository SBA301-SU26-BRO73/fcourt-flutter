enum AppEnv { dev, prod }

/// Cấu hình theo môi trường, đọc từ `--dart-define` hoặc `--dart-define-from-file`.
/// Xem `env/dev.json` và `env/prod.json`.
class AppConfig {
  const AppConfig({
    required this.env,
    required this.apiBaseUrl,
    String? authBaseUrl,
  }) : authBaseUrl = authBaseUrl ?? apiBaseUrl;

  final AppEnv env;
  final String apiBaseUrl;

  /// auth-service (`AUTH_BASE_URL`), mặc định bằng [apiBaseUrl].
  final String authBaseUrl;

  bool get isDev => env == AppEnv.dev;

  factory AppConfig.fromEnvironment() {
    const envName = String.fromEnvironment('APP_ENV', defaultValue: 'dev');
    const baseUrl = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://10.0.2.2:8080',
    );
    const authUrl = String.fromEnvironment('AUTH_BASE_URL');
    return AppConfig(
      env: envName == 'prod' ? AppEnv.prod : AppEnv.dev,
      apiBaseUrl: baseUrl,
      authBaseUrl: authUrl.isEmpty ? null : authUrl,
    );
  }
}
