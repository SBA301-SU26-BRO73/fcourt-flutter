import 'package:fcourt/app/auth_redirect.dart';
import 'package:fcourt/features/auth/domain/entities/user_role.dart';
import 'package:fcourt/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  roleGuardTests();
  group('authRedirect', () {
    test('chưa biết trạng thái: mọi màn hình đều về màn chờ, màn chờ thì ở lại', () {
      expect(authRedirect(AuthStatus.unknown, AppRoutes.home), AppRoutes.splash);
      expect(authRedirect(AuthStatus.unknown, AppRoutes.login), AppRoutes.splash);
      expect(authRedirect(AuthStatus.unknown, AppRoutes.splash), isNull);
    });

    test('chưa đăng nhập: chỉ vào được các màn công khai', () {
      expect(authRedirect(AuthStatus.unauthenticated, AppRoutes.login), isNull);
      expect(authRedirect(AuthStatus.unauthenticated, AppRoutes.registerCustomer), isNull);
      expect(authRedirect(AuthStatus.unauthenticated, AppRoutes.registerOwner), isNull);
    });

    test('chưa đăng nhập: các màn khác (kể cả màn chờ) đều về đăng nhập', () {
      expect(authRedirect(AuthStatus.unauthenticated, AppRoutes.home), AppRoutes.login);
      expect(authRedirect(AuthStatus.unauthenticated, AppRoutes.profile), AppRoutes.login);
      expect(authRedirect(AuthStatus.unauthenticated, AppRoutes.splash), AppRoutes.login);
      expect(authRedirect(AuthStatus.unauthenticated, AppRoutes.health), AppRoutes.login);
    });

    test('đã đăng nhập: không quay lại màn đăng nhập, đăng ký hoặc màn chờ', () {
      expect(authRedirect(AuthStatus.authenticated, AppRoutes.login), AppRoutes.home);
      expect(authRedirect(AuthStatus.authenticated, AppRoutes.registerCustomer), AppRoutes.home);
      expect(authRedirect(AuthStatus.authenticated, AppRoutes.registerOwner), AppRoutes.home);
      expect(authRedirect(AuthStatus.authenticated, AppRoutes.splash), AppRoutes.home);
      expect(authRedirect(AuthStatus.authenticated, '/'), AppRoutes.home);
    });

    test('đã đăng nhập: các màn trong app ở nguyên chỗ', () {
      expect(authRedirect(AuthStatus.authenticated, AppRoutes.home), isNull);
      expect(authRedirect(AuthStatus.authenticated, AppRoutes.profile), isNull);
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
