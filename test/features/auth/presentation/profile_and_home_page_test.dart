import 'package:fcourt/core/error/failure.dart';
import 'package:fcourt/features/auth/domain/entities/auth_user.dart';
import 'package:fcourt/features/auth/domain/entities/user_role.dart';
import 'package:fcourt/features/auth/domain/usecases/logout.dart';
import 'package:fcourt/features/auth/domain/usecases/restore_session.dart';
import 'package:fcourt/features/auth/domain/usecases/update_profile.dart';
import 'package:fcourt/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:fcourt/features/auth/presentation/bloc/profile_bloc.dart';
import 'package:fcourt/features/auth/presentation/pages/home_page.dart';
import 'package:fcourt/features/auth/presentation/pages/profile_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers.dart';

void main() {
  late MockAuthRepository repository;
  late AuthBloc authBloc;

  setUp(() {
    repository = MockAuthRepository();
    authBloc = AuthBloc(RestoreSession(repository), Logout(repository));
  });

  tearDown(() => authBloc.close());

  Future<void> pumpScreen(WidgetTester tester, Widget page, {AuthUser? signedIn}) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    if (signedIn != null) authBloc.add(AuthSignedIn(signedIn));
    await tester.pumpWidget(
      MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider.value(value: authBloc),
            BlocProvider(create: (_) => ProfileBloc(UpdateProfile(repository))),
          ],
          child: page,
        ),
      ),
    );
    await tester.pump();
  }

  Finder field(String label) => find.widgetWithText(TextFormField, label);

  group('ProfilePage', () {
    testWidgets('hiện email, vai trò và điền sẵn họ tên, số điện thoại hiện tại', (tester) async {
      await pumpScreen(tester, const ProfilePage(), signedIn: customerUser);

      expect(find.text('customer@demo.com'), findsOneWidget);
      expect(find.text('Khách hàng'), findsOneWidget);
      expect(tester.widget<TextFormField>(field('Họ và tên')).controller?.text, 'An Nguyen');
      expect(tester.widget<TextFormField>(field('Số điện thoại')).controller?.text, '0909000001');
    });

    testWidgets('lưu thành công thì cập nhật phiên và báo đã lưu', (tester) async {
      final updated = customerUser.copyWith(fullName: 'New Name', phone: '0911222333');
      when(() => repository.updateProfile(fullName: 'New Name', phone: '0911222333'))
          .thenAnswer((_) async => updated);
      await pumpScreen(tester, const ProfilePage(), signedIn: customerUser);

      await tester.enterText(field('Họ và tên'), 'New Name');
      await tester.enterText(field('Số điện thoại'), '0911222333');
      await tester.tap(find.widgetWithText(FilledButton, 'Lưu thay đổi'));
      await tester.pump();
      await tester.pump();

      expect(authBloc.state, AuthState.authenticated(updated));
      expect(find.text('Đã cập nhật thông tin'), findsOneWidget);
    });

    testWidgets('số điện thoại sai định dạng thì báo lỗi và không gọi BE', (tester) async {
      await pumpScreen(tester, const ProfilePage(), signedIn: customerUser);

      await tester.enterText(field('Số điện thoại'), 'abc');
      await tester.tap(find.widgetWithText(FilledButton, 'Lưu thay đổi'));
      await tester.pump();

      expect(find.textContaining('Số điện thoại không hợp lệ'), findsOneWidget);
      verifyNever(() => repository.updateProfile(fullName: any(named: 'fullName'), phone: any(named: 'phone')));
    });

    testWidgets('số điện thoại đã có người dùng thì hiện thông báo tiếng Việt', (tester) async {
      when(() => repository.updateProfile(fullName: any(named: 'fullName'), phone: any(named: 'phone')))
          .thenThrow(const ServerFailure('Phone number is already registered', statusCode: 409));
      await pumpScreen(tester, const ProfilePage(), signedIn: customerUser);

      await tester.tap(find.widgetWithText(FilledButton, 'Lưu thay đổi'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Số điện thoại này đã được đăng ký'), findsOneWidget);
      expect(authBloc.state, const AuthState.authenticated(customerUser));
    });

    testWidgets('đăng xuất thu hồi phiên và chuyển sang chưa đăng nhập', (tester) async {
      when(() => repository.logout()).thenAnswer((_) async {});
      await pumpScreen(tester, const ProfilePage(), signedIn: customerUser);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Đăng xuất'));
      // Bloc xử lý sự kiện qua stream, cần một nhịp event loop thật; pump giả không đủ.
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();

      verify(() => repository.logout()).called(1);
      expect(authBloc.state, const AuthState.unauthenticated());
    });
  });

  group('HomePage', () {
    for (final (role, title) in [
      (UserRole.customer, 'Đặt sân'),
      (UserRole.staff, 'Vận hành chi nhánh'),
      (UserRole.admin, 'Quản lý cụm sân'),
      (UserRole.superAdmin, 'Quản trị hệ thống'),
    ]) {
      testWidgets('vai trò ${role.name} thấy trang chủ "$title"', (tester) async {
        final user = AuthUser(
          id: 1,
          email: 'user@demo.com',
          role: role,
          status: 'ACTIVE',
          fullName: 'Tên Người Dùng',
        );
        await pumpScreen(tester, const HomePage(), signedIn: user);

        expect(find.descendant(of: find.byType(AppBar), matching: find.text(title)), findsOneWidget);
        expect(find.text('Xin chào, Tên Người Dùng'), findsOneWidget);
        expect(find.byTooltip('Tài khoản'), findsOneWidget);
      });
    }

    testWidgets('chỉ super admin thấy nút quản lý danh mục', (tester) async {
      await pumpScreen(tester, const HomePage(), signedIn: superAdminUser);

      expect(find.text('Quản lý danh mục'), findsOneWidget);
    });

    for (final user in [customerUser, adminUser]) {
      testWidgets('vai trò ${user.role.name} không thấy nút quản lý danh mục', (tester) async {
        await pumpScreen(tester, const HomePage(), signedIn: user);

        expect(find.text('Quản lý danh mục'), findsNothing);
      });
    }

    testWidgets('chưa có người dùng thì không dựng gì', (tester) async {
      await pumpScreen(tester, const HomePage());

      expect(find.byType(AppBar), findsNothing);
    });
  });
}
