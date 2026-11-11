/// Vai trò tài khoản, khớp `users.role` của auth-service. `admin` là chủ sân.
enum UserRole {
  customer('CUSTOMER', 'Khách hàng'),
  staff('STAFF', 'Nhân viên'),
  admin('ADMIN', 'Chủ sân'),
  superAdmin('SUPER_ADMIN', 'Quản trị hệ thống');

  const UserRole(this.apiValue, this.label);

  final String apiValue;
  final String label;

  /// Vai trò lạ (BE thêm role mới) rơi về [customer], là quyền thấp nhất.
  static UserRole fromApi(String? value) => UserRole.values.firstWhere(
    (role) => role.apiValue == value,
    orElse: () => UserRole.customer,
  );
}
