import 'dart:async';

import 'package:fcourt/core/error/failure.dart';
import 'package:fcourt/features/auth/domain/usecases/login.dart';
import 'package:fcourt/features/auth/domain/usecases/logout.dart';
import 'package:fcourt/features/auth/domain/usecases/restore_session.dart';
import 'package:fcourt/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:fcourt/features/auth/presentation/bloc/login_bloc.dart';
import 'package:fcourt/features/auth/presentation/pages/login_page.dart';
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

  Future<void> pumpPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider.value(value: authBloc),
            BlocProvider(create: (_) => LoginBloc(Login(repository))),
          ],
          child: const LoginPage(),
        ),
      ),
    );
  }

  Finder field(String label) => find.widgetWithText(TextFormField, label);
  Finder submitButton() => find.widgetWithText(FilledButton, 'Đăng nhập');

  Future<void> fillAndSubmit(WidgetTester tester) async {
    await tester.enterText(field('Email'), 'customer@demo.com');
    await tester.enterText(field('Mật khẩu'), 'S3cret-pass');
    await tester.tap(submitButton());
    await tester.pump();
  }

  testWidgets('để trống thì báo lỗi từng ô và không gọi BE', (tester) async {
    await pumpPage(tester);

    await tester.tap(submitButton());
    await tester.pump();

    expect(find.text('Vui lòng nhập email'), findsOneWidget);
    expect(find.text('Vui lòng nhập mật khẩu'), findsOneWidget);
    verifyNever(() => repository.login(email: any(named: 'email'), password: any(named: 'password')));
  });

  testWidgets('email sai định dạng thì báo lỗi ngay', (tester) async {
    await pumpPage(tester);

    await tester.enterText(field('Email'), 'not-an-email');
    await tester.enterText(field('Mật khẩu'), 'x');
    await tester.tap(submitButton());
    await tester.pump();

    expect(find.text('Email không hợp lệ'), findsOneWidget);
  });

  testWidgets('đăng nhập đúng thì phiên được mở với vai trò của người dùng', (tester) async {
    when(() => repository.login(email: 'customer@demo.com', password: 'S3cret-pass'))
        .thenAnswer((_) async => adminUser);
    await pumpPage(tester);

    await fillAndSubmit(tester);
    await tester.pump();

    expect(authBloc.state, const AuthState.authenticated(adminUser));
  });

  testWidgets('sai mật khẩu thì hiện thông báo tiếng Việt và không mở phiên', (tester) async {
    when(() => repository.login(email: any(named: 'email'), password: any(named: 'password')))
        .thenThrow(const UnauthorizedFailure('Invalid email or password'));
    await pumpPage(tester);

    await fillAndSubmit(tester);
    await tester.pump();

    expect(find.text('Email hoặc mật khẩu không đúng'), findsOneWidget);
    expect(authBloc.state.status, AuthStatus.unknown);
  });

  testWidgets('tài khoản chủ sân chưa duyệt thì nói rõ lý do', (tester) async {
    when(() => repository.login(email: any(named: 'email'), password: any(named: 'password')))
        .thenThrow(const ServerFailure('Account is awaiting approval', statusCode: 403));
    await pumpPage(tester);

    await fillAndSubmit(tester);
    await tester.pump();

    expect(find.text('Tài khoản đang chờ quản trị viên duyệt'), findsOneWidget);
  });

  testWidgets('lỗi validation của BE hiện ngay dưới ô tương ứng', (tester) async {
    when(() => repository.login(email: any(named: 'email'), password: any(named: 'password')))
        .thenThrow(
      const ServerFailure(
        'Invalid request fields',
        statusCode: 400,
        fieldErrors: {'email': 'Email is already registered'},
      ),
    );
    await pumpPage(tester);

    await fillAndSubmit(tester);
    await tester.pump();

    expect(find.text('Email này đã được đăng ký'), findsOneWidget);
  });

  testWidgets('đang gửi thì nút bị khóa và hiện vòng chờ, không gửi trùng', (tester) async {
    final completer = Completer<void>();
    when(() => repository.login(email: any(named: 'email'), password: any(named: 'password')))
        .thenAnswer((_) async {
      await completer.future;
      return customerUser;
    });
    await pumpPage(tester);

    await fillAndSubmit(tester);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
    completer.complete();
    await tester.pump();
    verify(() => repository.login(email: any(named: 'email'), password: any(named: 'password')))
        .called(1);
  });

  testWidgets('có thể bật tắt hiển thị mật khẩu', (tester) async {
    await pumpPage(tester);
    bool obscured() =>
        tester.widget<TextField>(find.descendant(of: field('Mật khẩu'), matching: find.byType(TextField))).obscureText;

    expect(obscured(), isTrue);
    await tester.tap(find.byTooltip('Hiện mật khẩu'));
    await tester.pump();

    expect(obscured(), isFalse);
  });
}
