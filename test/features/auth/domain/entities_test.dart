import 'package:fcourt/features/auth/domain/entities/auth_user.dart';
import 'package:fcourt/features/auth/domain/entities/user_role.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserRole.fromApi', () {
    test('đổi đủ bốn vai trò của BE', () {
      expect(UserRole.fromApi('CUSTOMER'), UserRole.customer);
      expect(UserRole.fromApi('STAFF'), UserRole.staff);
      expect(UserRole.fromApi('ADMIN'), UserRole.admin);
      expect(UserRole.fromApi('SUPER_ADMIN'), UserRole.superAdmin);
    });

    test('vai trò lạ hoặc thiếu rơi về quyền thấp nhất', () {
      expect(UserRole.fromApi('ROOT'), UserRole.customer);
      expect(UserRole.fromApi(null), UserRole.customer);
    });
  });

  group('AuthUser', () {
    const user = AuthUser(
      id: 1,
      email: 'a@demo.com',
      role: UserRole.customer,
      status: 'ACTIVE',
      fullName: 'An Nguyen',
    );

    test('displayName là họ tên, hoặc email khi họ tên trống', () {
      expect(user.displayName, 'An Nguyen');
      expect(
        const AuthUser(id: 1, email: 'a@demo.com', role: UserRole.customer, status: 'ACTIVE')
            .displayName,
        'a@demo.com',
      );
      expect(user.copyWith(fullName: '  ').displayName, 'a@demo.com');
    });

    test('copyWith chỉ đổi họ tên và số điện thoại', () {
      final updated = user.copyWith(fullName: 'New', phone: '0911222333');

      expect(updated.fullName, 'New');
      expect(updated.phone, '0911222333');
      expect(updated.email, user.email);
      expect(updated.role, user.role);
    });
  });
}
