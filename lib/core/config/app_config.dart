enum AppEnv { dev, prod }

/// Cấu hình theo môi trường, đọc từ `--dart-define` hoặc `--dart-define-from-file`.
/// Xem `env/dev.json` và `env/prod.json`.
class AppConfig {
  const AppConfig({
    required this.env,
    required this.apiBaseUrl,
    this.discoveryBaseUrl,
  });

  final AppEnv env;
  final String apiBaseUrl;
  final String? discoveryBaseUrl;
  String get discoveryUrl => discoveryBaseUrl ?? apiBaseUrl;

  bool get isDev => env == AppEnv.dev;

  factory AppConfig.fromEnvironment() {
    const envName = String.fromEnvironment('APP_ENV', defaultValue: 'dev');
    const baseUrl = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://10.0.2.2:8080',
    );
    return AppConfig(
      env: envName == 'prod' ? AppEnv.prod : AppEnv.dev,
      apiBaseUrl: baseUrl,
      discoveryBaseUrl: const bool.hasEnvironment('DISCOVERY_BASE_URL')
          ? const String.fromEnvironment('DISCOVERY_BASE_URL')
          : null,
    );
  }
}
