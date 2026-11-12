import 'package:fcourt/core/error/failure.dart';
import 'package:fcourt/features/auth/domain/entities/auth_user.dart';
import 'package:fcourt/features/auth/domain/usecases/logout.dart';
import 'package:fcourt/features/auth/domain/usecases/register_court_owner.dart';
import 'package:fcourt/features/auth/domain/usecases/register_customer.dart';
import 'package:fcourt/features/auth/domain/usecases/restore_session.dart';
import 'package:fcourt/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:fcourt/features/auth/presentation/bloc/register_bloc.dart';
import 'package:fcourt/features/auth/presentation/pages/register_customer_page.dart';
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
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider.value(value: authBloc),
            BlocProvider(
              create: (_) => RegisterBloc(
                RegisterCustomer(repository),
                RegisterCourtOwner(repository),
              ),
            ),
          ],
          child: const RegisterCustomerPage(),
        ),
      ),
    );
  }

  Finder field(String label) => find.byKey(ValueKey('auth-field-$label'));

  Future<void> fillForm(WidgetTester tester, {String confirm = 'S3cret-pass'}) async {
    await tester.enterText(field('Họ và tên'), 'An Nguyen');
    await tester.enterText(field('Email'), 'customer@demo.com');
    await tester.enterText(field('Số điện thoại'), '0909000001');
    await tester.enterText(field('Mật khẩu'), 'S3cret-pass');
    await tester.enterText(field('Nhập lại mật khẩu'), confirm);
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Đăng ký'));
    await tester.pump();
  }

  When<Future<AuthUser>> stubRegister() => when(
        () => repository.registerCustomer(
          fullName: any(named: 'fullName'),
          email: any(named: 'email'),
          phone: any(named: 'phone'),
          password: any(named: 'password'),
        ),
      );

  testWidgets('để trống thì báo lỗi các ô bắt buộc và không gọi BE', (tester) async {
    await pumpPage(tester);

    await submit(tester);

    expect(find.text('Vui lòng nhập họ tên'), findsOneWidget);
    expect(find.text('Vui lòng nhập email'), findsOneWidget);
    expect(find.text('Vui lòng nhập số điện thoại'), findsOneWidget);
    expect(find.text('Vui lòng nhập mật khẩu'), findsOneWidget);
    expect(find.text('Vui lòng nhập lại mật khẩu'), findsOneWidget);
  });

  testWidgets('mật khẩu nhập lại không khớp thì không gửi', (tester) async {
    await pumpPage(tester);

    await fillForm(tester, confirm: 'khac-hoan-toan');
    await submit(tester);

    expect(find.text('Mật khẩu nhập lại không khớp'), findsOneWidget);
    verifyNever(
      () => repository.registerCustomer(
        fullName: any(named: 'fullName'),
        email: any(named: 'email'),
        phone: any(named: 'phone'),
        password: any(named: 'password'),
      ),
    );
  });

  testWidgets('đăng ký thành công thì đăng nhập luôn', (tester) async {
    stubRegister().thenAnswer((_) async => customerUser);
    await pumpPage(tester);

    await fillForm(tester);
    await submit(tester);
    await tester.pump();

    verify(
      () => repository.registerCustomer(
        fullName: 'An Nguyen',
        email: 'customer@demo.com',
        phone: '0909000001',
        password: 'S3cret-pass',
      ),
    ).called(1);
    expect(authBloc.state, const AuthState.authenticated(customerUser));
  });

  testWidgets('email trùng thì hiện thông báo chung bằng tiếng Việt', (tester) async {
    stubRegister().thenThrow(const ServerFailure('Email is already registered', statusCode: 409));
    await pumpPage(tester);

    await fillForm(tester);
    await submit(tester);
    await tester.pump();

    expect(find.text('Email này đã được đăng ký'), findsOneWidget);
    expect(authBloc.state.status, AuthStatus.unknown);
  });

  testWidgets('lỗi validation của BE hiện dưới đúng ô và không hiện banner', (tester) async {
    stubRegister().thenThrow(
      const ServerFailure(
        'Invalid request fields',
        statusCode: 400,
        fieldErrors: {'phone': 'Phone number is already registered'},
      ),
    );
    await pumpPage(tester);

    await fillForm(tester);
    await submit(tester);
    await tester.pump();

    expect(find.text('Số điện thoại này đã được đăng ký'), findsOneWidget);
    expect(find.text('Invalid request fields'), findsNothing);
  });
}
