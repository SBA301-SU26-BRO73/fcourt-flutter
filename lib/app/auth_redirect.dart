import '../features/auth/domain/entities/user_role.dart';
import '../features/auth/presentation/bloc/auth_bloc.dart';

class AppRoutes {
  const AppRoutes._();

  static const splash = '/splash';
  static const login = '/login';
  static const registerCustomer = '/register';
  static const registerOwner = '/register/owner';
  static const home = '/home';
  static const profile = '/profile';
  static const discover = '/discover';
  static const health = '/health';
}

const superAdminPrefix = '/super-admin';

/// Các màn hình không cần đăng nhập.
const publicRoutes = {
  AppRoutes.login,
  AppRoutes.registerCustomer,
  AppRoutes.registerOwner,
};

/// Quyết định chuyển hướng theo trạng thái đăng nhập; `null` nghĩa là ở lại.
///
/// - Chưa biết trạng thái: giữ ở màn chờ để không nháy màn đăng nhập khi đang khôi phục phiên.
/// - Chưa đăng nhập: chỉ được vào các màn công khai.
/// - Đã đăng nhập: không quay lại màn đăng nhập, đăng ký hay chờ.
String? authRedirect(AuthStatus status, String location, {UserRole? role}) {
  switch (status) {
    case AuthStatus.unknown:
      return location == AppRoutes.splash ? null : AppRoutes.splash;
    case AuthStatus.unauthenticated:
      return publicRoutes.contains(location) ? null : AppRoutes.login;
    case AuthStatus.authenticated:
      if (location.startsWith(superAdminPrefix) && role != UserRole.superAdmin) {
        return AppRoutes.home;
      }
      final isEntryScreen =
          publicRoutes.contains(location) || location == AppRoutes.splash || location == '/';
      return isEntryScreen ? AppRoutes.home : null;
  }
}
