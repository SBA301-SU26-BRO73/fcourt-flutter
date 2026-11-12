import '../features/auth/domain/entities/user_role.dart';
import '../features/auth/presentation/bloc/auth_bloc.dart';

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
  static const settings = '/settings';
  static const catalog = '/catalog';
  static const superAdminOverview = '/super-admin/overview';
  static const discover = '/discover';
  static const health = '/health';
  static const staff = '/admin/staff';
  static const offlineCheckIn = '/staff/offline';
}

/// Các màn hình không cần đăng nhập.
const publicRoutes = {
  AppRoutes.login,
  AppRoutes.registerCustomer,
  AppRoutes.registerOwner,
  AppRoutes.forgotPassword,
  '/lookup',
};

/// Khách chưa đăng nhập được xem chi nhánh, sân và lưới slot (BE mở `GET /api/public/**`);
/// giữ chỗ và đặt sân vẫn bắt đăng nhập.
bool isGuestBrowseRoute(String location) =>
    location == '/branches' ||
    RegExp(r'^/branches/[0-9]+$').hasMatch(location) ||
    RegExp(r'^/courts/[0-9]+/slots$').hasMatch(location);

/// Quyết định chuyển hướng theo trạng thái đăng nhập; `null` nghĩa là ở lại.
///
/// - [AppRoutes.resetPassword] mở được ở mọi trạng thái: link trong email có thể đến khi app
///   đang khôi phục phiên, đang đăng nhập sẵn hoặc chưa đăng nhập, và không được làm mất link.
/// - Chưa biết trạng thái: giữ ở màn chờ để không nháy màn đăng nhập khi đang khôi phục phiên.
/// - Chưa đăng nhập: chỉ được vào các màn công khai.
/// - Đã đăng nhập: không quay lại màn đăng nhập, đăng ký hay chờ.
/// - Màn hình của một vai trò (ví dụ danh mục của super admin): vai trò khác bị đưa về trang chủ.
String? authRedirect(
  AuthStatus status,
  String location, {
  UserRole? role,
  String? returnTo,
}) {
  if (location == AppRoutes.resetPassword) return null;
  switch (status) {
    case AuthStatus.unknown:
      return location == AppRoutes.splash ? null : AppRoutes.splash;
    case AuthStatus.unauthenticated:
      return publicRoutes.contains(location) || isGuestBrowseRoute(location)
          ? null
          : AppRoutes.login;
    case AuthStatus.offlineStaff:
      return location == AppRoutes.offlineCheckIn
          ? null
          : AppRoutes.offlineCheckIn;
    case AuthStatus.authenticated:
      if (location == AppRoutes.login && returnTo != null) {
        final candidate = Uri.tryParse(returnTo);
        if (candidate != null &&
            candidate.hasAuthority == false &&
            candidate.path.startsWith('/') &&
            !candidate.path.startsWith('//') &&
            !publicRoutes.contains(candidate.path) &&
            candidate.path != AppRoutes.splash) {
          final redirect = authRedirect(
            AuthStatus.authenticated,
            candidate.path,
            role: role,
          );
          if (redirect == null) return candidate.toString();
        }
      }
      final isEntryScreen =
          publicRoutes.contains(location) ||
          location == AppRoutes.splash ||
          location == '/';
      if (isEntryScreen) return AppRoutes.home;
      return _isForbidden(location, role) ? AppRoutes.home : null;
  }
}

/// Màn hình chỉ dành cho một vai trò. BE vẫn là nơi chặn cuối cùng (403), đây chỉ để không
/// cho người không có quyền thấy màn hình rồi nhận lỗi.
bool _isForbidden(String location, UserRole? role) => switch (location) {
  AppRoutes.catalog => role != UserRole.superAdmin,
  _ when location.startsWith('/super-admin') => role != UserRole.superAdmin,
  _ when location.startsWith('/admin') => role != UserRole.admin,
  _ when location.startsWith('/staff') => role != UserRole.staff,
  _
      when location == AppRoutes.discover ||
          location == '/branches' ||
          location.startsWith('/branches/') ||
          location.startsWith('/courts/') ||
          location == '/bookings' ||
          location.startsWith('/bookings/') ||
          location.startsWith('/booking/') ||
          location.startsWith('/payments/') =>
    role != UserRole.customer,
  _ => false,
};
