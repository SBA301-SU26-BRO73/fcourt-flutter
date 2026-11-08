import 'package:fcourt/app/auth_redirect.dart';
import 'package:fcourt/features/auth/domain/entities/user_role.dart';
import 'package:fcourt/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('thống kê nền tảng chỉ dành cho super admin', () {
    expect(
      authRedirect(
        AuthStatus.authenticated,
        AppRoutes.superAdminOverview,
        role: UserRole.superAdmin,
      ),
      isNull,
    );
    for (final role in [UserRole.customer, UserRole.staff, UserRole.admin]) {
      expect(
        authRedirect(AuthStatus.authenticated, AppRoutes.superAdminOverview, role: role),
        AppRoutes.home,
        reason: role.name,
      );
    }
    expect(
      authRedirect(AuthStatus.unauthenticated, AppRoutes.superAdminOverview),
      AppRoutes.login,
    );
  });
}
