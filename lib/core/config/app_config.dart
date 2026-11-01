enum AppEnv { dev, prod }

/// Cấu hình theo môi trường, đọc từ `--dart-define` hoặc `--dart-define-from-file`.
/// Xem `env/dev.json` và `env/prod.json`.
class AppConfig {
  const AppConfig({
    required this.env,
    required this.apiBaseUrl,
    this.discoveryBaseUrl,
    this.facilityBaseUrl,
    this.reportingBaseUrl,
    String? authBaseUrl,
  }) : authBaseUrl = authBaseUrl ?? apiBaseUrl;

  final AppEnv env;
  final String apiBaseUrl;
  final String? discoveryBaseUrl;
  final String? facilityBaseUrl;
  final String? reportingBaseUrl;
  String get discoveryUrl => discoveryBaseUrl ?? apiBaseUrl;

  /// auth-service (`AUTH_BASE_URL`), mặc định bằng [apiBaseUrl].
  final String authBaseUrl;

  bool get isDev => env == AppEnv.dev;

  String get facilityUrl => _orApi(facilityBaseUrl);
  String get reportingUrl => _orApi(reportingBaseUrl);

  String _orApi(String? url) =>
      url == null || url.trim().isEmpty ? apiBaseUrl : url;

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
      discoveryBaseUrl: const bool.hasEnvironment('DISCOVERY_BASE_URL')
          ? const String.fromEnvironment('DISCOVERY_BASE_URL')
          : null,
      facilityBaseUrl: const bool.hasEnvironment('FACILITY_BASE_URL')
          ? const String.fromEnvironment('FACILITY_BASE_URL')
          : null,
      reportingBaseUrl: const bool.hasEnvironment('REPORTING_BASE_URL')
          ? const String.fromEnvironment('REPORTING_BASE_URL')
          : null,
    );
  }
}
