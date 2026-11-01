enum AppEnv { dev, prod }

/// Cấu hình theo môi trường, đọc từ `--dart-define` hoặc `--dart-define-from-file`.
/// Xem `env/dev.json` và `env/prod.json`.
class AppConfig {
  const AppConfig({
    required this.env,
    required this.apiBaseUrl,
    String? staffBaseUrl,
    String? facilityBaseUrl,
    String? posBaseUrl,
    String? discoveryBaseUrl,
  }) : staffBaseUrl = staffBaseUrl ?? apiBaseUrl,
       facilityBaseUrl = facilityBaseUrl ?? apiBaseUrl,
       posBaseUrl = posBaseUrl ?? apiBaseUrl,
       discoveryBaseUrl = discoveryBaseUrl ?? apiBaseUrl;

  final AppEnv env;
  final String apiBaseUrl;
  final String staffBaseUrl;
  final String facilityBaseUrl;
  final String posBaseUrl;
  final String discoveryBaseUrl;

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
      staffBaseUrl: const String.fromEnvironment('STAFF_BASE_URL').isEmpty
          ? baseUrl
          : const String.fromEnvironment('STAFF_BASE_URL'),
      facilityBaseUrl: const String.fromEnvironment('FACILITY_BASE_URL').isEmpty
          ? baseUrl
          : const String.fromEnvironment('FACILITY_BASE_URL'),
      posBaseUrl: const String.fromEnvironment('POS_BASE_URL').isEmpty
          ? baseUrl
          : const String.fromEnvironment('POS_BASE_URL'),
      discoveryBaseUrl:
          const String.fromEnvironment('DISCOVERY_BASE_URL').isEmpty
          ? baseUrl
          : const String.fromEnvironment('DISCOVERY_BASE_URL'),
    );
  }
}
