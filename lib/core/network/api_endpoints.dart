/// Đường dẫn API dùng chung. Mỗi feature tự khai báo đường dẫn riêng của mình
/// trong data source; chỉ những endpoint cấp hạ tầng mới đặt ở đây.
class ApiEndpoints {
  const ApiEndpoints._();

  static const authRefresh = '/api/auth/refresh';
  static const health = '/api/v1/health';
}
