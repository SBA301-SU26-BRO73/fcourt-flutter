import '../features/auth/presentation/bloc/auth_bloc.dart';
import '../features/auth/domain/entities/user_role.dart';

class AppRoutes {
  const AppRoutes._();

  static const splash = '/splash';
  static const login = '/login';
  static const registerCustomer = '/register';
  static const registerOwner = '/register/owner';
  static const forgotPassword = '/forgot-password';
  static const resetPassword = '/reset-password';
  static const home = '/home';
  static const profile = '/profile';
  static const catalog = '/catalog';
  static const discover = '/discover';
  static const health = '/health';
  static const staff = '/admin/staff';
}

/// Các màn hình không cần đăng nhập.
const publicRoutes = {
  AppRoutes.login,
  AppRoutes.registerCustomer,
  AppRoutes.registerOwner,
  AppRoutes.forgotPassword,
};

/// Quyết định chuyển hướng theo trạng thái đăng nhập; `null` nghĩa là ở lại.
///
/// - [AppRoutes.resetPassword] mở được ở mọi trạng thái: link trong email có thể đến khi app
///   đang khôi phục phiên, đang đăng nhập sẵn hoặc chưa đăng nhập, và không được làm mất link.
/// - Chưa biết trạng thái: giữ ở màn chờ để không nháy màn đăng nhập khi đang khôi phục phiên.
/// - Chưa đăng nhập: chỉ được vào các màn công khai.
/// - Đã đăng nhập: không quay lại màn đăng nhập, đăng ký hay chờ.
/// - Màn hình của một vai trò (ví dụ danh mục của super admin): vai trò khác bị đưa về trang chủ.
String? authRedirect(AuthStatus status, String location, {UserRole? role}) {
  if (location == AppRoutes.resetPassword) return null;
  switch (status) {
    case AuthStatus.unknown:
      return location == AppRoutes.splash ? null : AppRoutes.splash;
    case AuthStatus.unauthenticated:
      return publicRoutes.contains(location) ? null : AppRoutes.login;
    case AuthStatus.authenticated:
      final isEntryScreen =
          publicRoutes.contains(location) || location == AppRoutes.splash || location == '/';
      if (isEntryScreen) return AppRoutes.home;
      return _isForbidden(location, role) ? AppRoutes.home : null;
  }
}

/// Màn hình chỉ dành cho một vai trò. BE vẫn là nơi chặn cuối cùng (403), đây chỉ để không
/// cho người không có quyền thấy màn hình rồi nhận lỗi.
bool _isForbidden(String location, UserRole? role) =>
    ((location == AppRoutes.catalog || location.startsWith('/super-admin')) &&
        role != UserRole.superAdmin) ||
    (location == AppRoutes.staff && role != UserRole.admin);
