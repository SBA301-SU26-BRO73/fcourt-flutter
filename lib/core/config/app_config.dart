enum AppEnv { dev, prod }

/// Cấu hình theo môi trường, đọc từ `--dart-define` hoặc `--dart-define-from-file`.
/// Xem `env/dev.json` và `env/prod.json`.
///
/// `FACILITY_BASE_URL` và `REPORTING_BASE_URL` là tùy chọn: khi chạy từng
/// service riêng (facility 8083, reporting 8084) thì khai báo, còn khi đi qua
/// gateway thì bỏ trống để dùng `API_BASE_URL`.
class AppConfig {
  const AppConfig({
    required this.env,
    required this.apiBaseUrl,
    this.facilityBaseUrl,
    this.reportingBaseUrl,
  });

  final AppEnv env;
  final String apiBaseUrl;
  final String? facilityBaseUrl;
  final String? reportingBaseUrl;

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
    return AppConfig(
      env: envName == 'prod' ? AppEnv.prod : AppEnv.dev,
      apiBaseUrl: baseUrl,
      facilityBaseUrl: const bool.hasEnvironment('FACILITY_BASE_URL')
          ? const String.fromEnvironment('FACILITY_BASE_URL')
          : null,
      reportingBaseUrl: const bool.hasEnvironment('REPORTING_BASE_URL')
          ? const String.fromEnvironment('REPORTING_BASE_URL')
          : null,
    );
  }
}
