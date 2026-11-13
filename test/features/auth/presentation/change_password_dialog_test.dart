import 'package:fcourt/core/error/failure.dart';
import 'package:fcourt/features/auth/domain/usecases/change_password.dart';
import 'package:fcourt/features/auth/domain/usecases/logout.dart';
import 'package:fcourt/features/auth/domain/usecases/restore_session.dart';
import 'package:fcourt/features/auth/domain/usecases/update_profile.dart';
import 'package:fcourt/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:fcourt/features/auth/presentation/bloc/change_password_bloc.dart';
import 'package:fcourt/features/auth/presentation/bloc/profile_bloc.dart';
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
    authBloc = AuthBloc(RestoreSession(repository), Logout(repository))
      ..add(const AuthSignedIn(customerUser));
  });

  tearDown(() => authBloc.close());

  Future<void> openDialog(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider.value(value: authBloc),
            BlocProvider(create: (_) => ProfileBloc(UpdateProfile(repository))),
            BlocProvider(
              create: (_) => ChangePasswordBloc(ChangePassword(repository)),
            ),
          ],
          child: const ProfilePage(editMode: true),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Đổi mật khẩu'));
    await tester.pumpAndSettle();
  }

  Finder field(String label) => find.byKey(ValueKey('auth-field-$label'));
  Finder dialogButton() => find.widgetWithText(FilledButton, 'Đổi mật khẩu');

  Future<void> fill(
    WidgetTester tester, {
    String confirm = 'new-pass-2',
  }) async {
    await tester.enterText(field('Mật khẩu hiện tại'), 'old-pass-1');
    await tester.enterText(field('Mật khẩu mới'), 'new-pass-2');
    await tester.enterText(field('Nhập lại mật khẩu mới'), confirm);
  }

  When<Future<dynamic>> stubChange() => when(
    () => repository.changePassword(
      currentPassword: any(named: 'currentPassword'),
      newPassword: any(named: 'newPassword'),
    ),
  );

  testWidgets('mở hộp thoại từ trang tài khoản', (tester) async {
    await openDialog(tester);

    expect(find.text('Mật khẩu hiện tại'), findsOneWidget);
    expect(find.text('Mật khẩu mới'), findsOneWidget);
    expect(find.text('Hủy'), findsOneWidget);
  });

  testWidgets('để trống hoặc nhập lại không khớp thì báo lỗi và không gọi BE', (
    tester,
  ) async {
    await openDialog(tester);

    await tester.tap(dialogButton());
    await tester.pump();
    expect(find.text('Vui lòng nhập mật khẩu'), findsNWidgets(2));

    await fill(tester, confirm: 'khac-hoan-toan');
    await tester.tap(dialogButton());
    await tester.pump();

    expect(find.text('Mật khẩu nhập lại không khớp'), findsOneWidget);
    verifyNever(
      () => repository.changePassword(
        currentPassword: any(named: 'currentPassword'),
        newPassword: any(named: 'newPassword'),
      ),
    );
  });

  testWidgets('mật khẩu mới quá ngắn thì báo ngay, không cần hỏi BE', (
    tester,
  ) async {
    await openDialog(tester);

    await tester.enterText(field('Mật khẩu hiện tại'), 'old-pass-1');
    await tester.enterText(field('Mật khẩu mới'), 'short');
    await tester.enterText(field('Nhập lại mật khẩu mới'), 'short');
    await tester.tap(dialogButton());
    await tester.pump();

    expect(find.text('Mật khẩu tối thiểu 8 ký tự'), findsOneWidget);
  });

  testWidgets(
    'đổi thành công thì đóng hộp thoại, báo các thiết bị khác phải đăng nhập lại, vẫn đăng nhập ở đây',
    (tester) async {
      stubChange().thenAnswer((_) async => customerUser);
      await openDialog(tester);

      await fill(tester);
      await tester.tap(dialogButton());
      await tester.pump();
      await tester.pumpAndSettle();

      verify(
        () => repository.changePassword(
          currentPassword: 'old-pass-1',
          newPassword: 'new-pass-2',
        ),
      ).called(1);
      expect(find.text('Hủy'), findsNothing);
      expect(
        find.textContaining('Các thiết bị khác cần đăng nhập lại'),
        findsOneWidget,
      );
      expect(authBloc.state, const AuthState.authenticated(customerUser));
    },
  );

  testWidgets(
    'sai mật khẩu hiện tại thì báo bằng tiếng Việt và hộp thoại vẫn mở',
    (tester) async {
      stubChange().thenThrow(
        const ServerFailure('Current password is incorrect', statusCode: 400),
      );
      await openDialog(tester);

      await fill(tester);
      await tester.tap(dialogButton());
      await tester.pump();
      await tester.pump();

      expect(find.text('Mật khẩu hiện tại không đúng'), findsOneWidget);
      expect(find.text('Hủy'), findsOneWidget);
    },
  );

  testWidgets('mật khẩu mới trùng mật khẩu cũ thì hiện lý do của BE', (
    tester,
  ) async {
    stubChange().thenThrow(
      const ServerFailure(
        'New password must differ from the current password',
        statusCode: 400,
      ),
    );
    await openDialog(tester);

    await fill(tester);
    await tester.tap(dialogButton());
    await tester.pump();
    await tester.pump();

    expect(
      find.text('Mật khẩu mới phải khác mật khẩu hiện tại'),
      findsOneWidget,
    );
  });

  testWidgets('mở lại sau khi lỗi thì không hiện lỗi cũ', (tester) async {
    stubChange().thenThrow(
      const ServerFailure('Current password is incorrect', statusCode: 400),
    );
    await openDialog(tester);
    await fill(tester);
    await tester.tap(dialogButton());
    await tester.pump();
    await tester.pump();
    expect(find.text('Mật khẩu hiện tại không đúng'), findsOneWidget);

    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Đổi mật khẩu'));
    await tester.pumpAndSettle();

    expect(find.text('Mật khẩu hiện tại'), findsOneWidget);
    expect(find.text('Mật khẩu hiện tại không đúng'), findsNothing);
  });

  testWidgets('hủy thì đóng hộp thoại mà không gọi BE', (tester) async {
    await openDialog(tester);

    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();

    expect(find.text('Mật khẩu hiện tại'), findsNothing);
    verifyNever(
      () => repository.changePassword(
        currentPassword: any(named: 'currentPassword'),
        newPassword: any(named: 'newPassword'),
      ),
    );
  });
}
