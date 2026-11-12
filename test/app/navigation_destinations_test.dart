import 'package:fcourt/app/widgets/app_navigation.dart';
import 'package:fcourt/app/widgets/skeleton_list.dart';
import 'package:fcourt/features/auth/domain/entities/user_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('each role has four purposeful tabs and no empty Activity tab', () {
    for (final role in UserRole.values) {
      final labels = navDestinations(role).map((d) => d.label).toList();
      expect(labels, hasLength(4), reason: role.name);
      expect(labels, isNot(contains('Hoạt động')), reason: role.name);
      expect(labels.last, 'Tài khoản');
    }
    expect(navDestinations(UserRole.customer).map((d) => d.label), [
      'Khám phá',
      'Đơn của tôi',
      'Thông báo',
      'Tài khoản',
    ]);
    expect(navDestinations(UserRole.admin).map((d) => d.label), [
      'Việc cần làm',
      'Đơn',
      'Chi nhánh',
      'Tài khoản',
    ]);
  });

  test('sub pages keep their tab highlighted', () {
    expect(navSelectedIndex(UserRole.customer, '/bookings'), 1);
    expect(navSelectedIndex(UserRole.customer, '/payments/history'), 1);
    expect(navSelectedIndex(UserRole.customer, '/notifications'), 2);
    expect(navSelectedIndex(UserRole.admin, '/admin/bookings'), 1);
    expect(navSelectedIndex(UserRole.admin, '/admin/branches/3/payments'), 2);
    expect(navSelectedIndex(UserRole.staff, '/staff/schedule'), 1);
    expect(navSelectedIndex(UserRole.superAdmin, '/home'), 0);
  });

  testWidgets('skeleton list renders placeholders', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SkeletonList(count: 3))),
    );
    expect(find.byKey(const ValueKey('skeleton-list')), findsOneWidget);
    expect(find.byType(DecoratedBox), findsAtLeastNWidgets(3));
    await tester.pumpWidget(const SizedBox());
  });
}
