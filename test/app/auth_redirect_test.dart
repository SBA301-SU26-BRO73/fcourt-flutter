import 'package:fcourt/app/auth_redirect.dart';
import 'package:fcourt/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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

    test('quên mật khẩu là màn công khai: chưa đăng nhập vào được, đã đăng nhập thì về trang chủ', () {
      expect(authRedirect(AuthStatus.unauthenticated, AppRoutes.forgotPassword), isNull);
      expect(authRedirect(AuthStatus.authenticated, AppRoutes.forgotPassword), AppRoutes.home);
    });

    test('link đặt lại mật khẩu mở được ở mọi trạng thái và không bị mất khi đang khôi phục phiên', () {
      for (final status in AuthStatus.values) {
        expect(authRedirect(status, AppRoutes.resetPassword), isNull, reason: status.name);
      }
    });

    test('đã đăng nhập: các màn trong app ở nguyên chỗ', () {
      expect(authRedirect(AuthStatus.authenticated, AppRoutes.home), isNull);
      expect(authRedirect(AuthStatus.authenticated, AppRoutes.profile), isNull);
    });
  });
}
