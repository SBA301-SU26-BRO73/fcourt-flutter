import 'package:fcourt/app/auth_redirect.dart';
import 'package:fcourt/features/auth/domain/entities/user_role.dart';
import 'package:fcourt/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  adminRoleGuardTests();
  roleGuardTests();
  group('authRedirect', () {
    test(
      'chưa biết trạng thái: mọi màn hình đều về màn chờ, màn chờ thì ở lại',
      () {
        expect(
          authRedirect(AuthStatus.unknown, AppRoutes.home),
          AppRoutes.splash,
        );
        expect(
          authRedirect(AuthStatus.unknown, AppRoutes.login),
          AppRoutes.splash,
        );
        expect(authRedirect(AuthStatus.unknown, AppRoutes.splash), isNull);
      },
    );

    test('chưa đăng nhập: chỉ vào được các màn công khai', () {
      expect(authRedirect(AuthStatus.unauthenticated, AppRoutes.login), isNull);
      expect(
        authRedirect(AuthStatus.unauthenticated, AppRoutes.registerCustomer),
        isNull,
      );
      expect(
        authRedirect(AuthStatus.unauthenticated, AppRoutes.registerOwner),
        isNull,
      );
    });

    test('chưa đăng nhập: các màn khác (kể cả màn chờ) đều về đăng nhập', () {
      expect(
        authRedirect(AuthStatus.unauthenticated, AppRoutes.home),
        AppRoutes.login,
      );
      expect(
        authRedirect(AuthStatus.unauthenticated, AppRoutes.profile),
        AppRoutes.login,
      );
      expect(
        authRedirect(AuthStatus.unauthenticated, AppRoutes.splash),
        AppRoutes.login,
      );
      expect(
        authRedirect(AuthStatus.unauthenticated, AppRoutes.health),
        AppRoutes.login,
      );
    });

    test(
      'đã đăng nhập: không quay lại màn đăng nhập, đăng ký hoặc màn chờ',
      () {
        expect(
          authRedirect(AuthStatus.authenticated, AppRoutes.login),
          AppRoutes.home,
        );
        expect(
          authRedirect(AuthStatus.authenticated, AppRoutes.registerCustomer),
          AppRoutes.home,
        );
        expect(
          authRedirect(AuthStatus.authenticated, AppRoutes.registerOwner),
          AppRoutes.home,
        );
        expect(
          authRedirect(AuthStatus.authenticated, AppRoutes.splash),
          AppRoutes.home,
        );
        expect(authRedirect(AuthStatus.authenticated, '/'), AppRoutes.home);
      },
    );

    test('quên mật khẩu là màn công khai: chưa đăng nhập vào được, đã đăng nhập thì về trang chủ', () {
      expect(
        authRedirect(AuthStatus.unauthenticated, AppRoutes.forgotPassword),
        isNull,
      );
      expect(
        authRedirect(AuthStatus.authenticated, AppRoutes.forgotPassword),
        AppRoutes.home,
      );
    });

    test('guest lookup is public and login can restore the selected customer route', () {
      expect(authRedirect(AuthStatus.unauthenticated, '/lookup'), isNull);
      expect(
        authRedirect(
          AuthStatus.authenticated,
          AppRoutes.login,
          role: UserRole.customer,
          returnTo: '/courts/9/slots?date=2030-01-01',
        ),
        '/courts/9/slots?date=2030-01-01',
      );
      expect(
        authRedirect(
          AuthStatus.authenticated,
          AppRoutes.login,
          role: UserRole.customer,
          returnTo: 'https://example.com',
        ),
        AppRoutes.home,
      );
    });

    test('link đặt lại mật khẩu mở được ở mọi trạng thái và không bị mất khi đang khôi phục phiên', () {
      for (final status in AuthStatus.values) {
        expect(
          authRedirect(status, AppRoutes.resetPassword),
          isNull,
          reason: status.name,
        );
      }
    });

    test('danh mục chỉ dành cho super admin, vai trò khác về trang chủ', () {
      expect(
        authRedirect(
          AuthStatus.authenticated,
          AppRoutes.catalog,
          role: UserRole.superAdmin,
        ),
        isNull,
      );
      for (final role in [UserRole.customer, UserRole.staff, UserRole.admin]) {
        expect(
          authRedirect(AuthStatus.authenticated, AppRoutes.catalog, role: role),
          AppRoutes.home,
          reason: role.name,
        );
      }
      expect(
        authRedirect(AuthStatus.authenticated, AppRoutes.catalog),
        AppRoutes.home,
      );
    });

    test(
      'danh mục: chưa đăng nhập về đăng nhập, đang khôi phục phiên về màn chờ',
      () {
        expect(
          authRedirect(AuthStatus.unauthenticated, AppRoutes.catalog),
          AppRoutes.login,
        );
        expect(
          authRedirect(AuthStatus.unknown, AppRoutes.catalog),
          AppRoutes.splash,
        );
      },
    );

    test('đã đăng nhập: các màn trong app ở nguyên chỗ', () {
      expect(authRedirect(AuthStatus.authenticated, AppRoutes.home), isNull);
      expect(authRedirect(AuthStatus.authenticated, AppRoutes.profile), isNull);
    });

    test('khách chưa đăng nhập xem được chi nhánh, sân và lưới slot nhưng không đặt được', () {
      for (final path in [
        '/branches',
        '/branches/12',
        '/branches/12/slots',
        '/courts/9/slots',
      ]) {
        expect(
          authRedirect(AuthStatus.unauthenticated, path),
          isNull,
          reason: path,
        );
      }
      for (final path in [
        '/bookings',
        '/bookings/5',
        '/payments/history',
        '/branches/abc',
        '/courts/9/slots/x',
      ]) {
        expect(
          authRedirect(AuthStatus.unauthenticated, path),
          AppRoutes.login,
          reason: path,
        );
      }
    });

    test('guest can walk the booking and payment routes without logging in', () {
      for (final path in [
        '/booking/summary',
        '/booking/confirm',
        '/payments/checkout',
        '/payments/receipt',
        '/payments/ticket',
      ]) {
        expect(
          authRedirect(AuthStatus.unauthenticated, path),
          isNull,
          reason: path,
        );
      }
    });

    test('quản lý nhân viên chỉ dành cho chủ sân', () {
      expect(
        authRedirect(
          AuthStatus.authenticated,
          AppRoutes.staff,
          role: UserRole.admin,
        ),
        isNull,
      );
      for (final role in [
        UserRole.customer,
        UserRole.staff,
        UserRole.superAdmin,
      ]) {
        expect(
          authRedirect(AuthStatus.authenticated, AppRoutes.staff, role: role),
          AppRoutes.home,
          reason: role.name,
        );
      }
    });
  });
}

void roleGuardTests() {
  group('authRedirect theo role', () {
    const path = '/super-admin/owners/pending';

    test('chỉ SUPER_ADMIN được vào màn duyệt chủ sân', () {
      expect(
        authRedirect(AuthStatus.authenticated, path, role: UserRole.superAdmin),
        isNull,
      );
      for (final role in [UserRole.customer, UserRole.staff, UserRole.admin]) {
        expect(
          authRedirect(AuthStatus.authenticated, path, role: role),
          AppRoutes.home,
        );
        expect(
          authRedirect(AuthStatus.authenticated, '$path/5', role: role),
          AppRoutes.home,
        );
      }
    });

    test('chưa đăng nhập vẫn về màn đăng nhập', () {
      expect(authRedirect(AuthStatus.unauthenticated, path), AppRoutes.login);
    });
  });
}

void adminRoleGuardTests() {
  group('authRedirect màn hình chủ sân', () {
    test('chỉ ADMIN được vào /admin', () {
      expect(
        authRedirect(
          AuthStatus.authenticated,
          '/admin/branches',
          role: UserRole.admin,
        ),
        isNull,
      );
      for (final role in [
        UserRole.customer,
        UserRole.staff,
        UserRole.superAdmin,
      ]) {
        expect(
          authRedirect(
            AuthStatus.authenticated,
            '/admin/dashboard',
            role: role,
          ),
          AppRoutes.home,
        );
      }
    });

    test('chỉ STAFF được vào /staff', () {
      expect(
        authRedirect(
          AuthStatus.authenticated,
          '/staff/schedule',
          role: UserRole.staff,
        ),
        isNull,
      );
      for (final role in [
        UserRole.customer,
        UserRole.admin,
        UserRole.superAdmin,
      ]) {
        expect(
          authRedirect(AuthStatus.authenticated, '/staff/schedule', role: role),
          AppRoutes.home,
        );
      }
    });
  });
}
