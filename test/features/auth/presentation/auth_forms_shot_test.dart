import 'package:fcourt/features/auth/domain/usecases/logout.dart';
import 'package:fcourt/features/auth/domain/usecases/register_court_owner.dart';
import 'package:fcourt/features/auth/domain/usecases/register_customer.dart';
import 'package:fcourt/features/auth/domain/usecases/request_password_reset.dart';
import 'package:fcourt/features/auth/domain/usecases/restore_session.dart';
import 'package:fcourt/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:fcourt/features/auth/presentation/bloc/forgot_password_bloc.dart';
import 'package:fcourt/features/auth/presentation/bloc/register_bloc.dart';
import 'package:fcourt/features/auth/presentation/pages/forgot_password_page.dart';
import 'package:fcourt/features/auth/presentation/pages/register_customer_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/wp3b_shots.dart';
import '../helpers.dart';

void main() {
  for (final b in Brightness.values) {
    testWidgets('register customer matches the WP3b look (${b.name})', (
      tester,
    ) async {
      final repository = MockAuthRepository();
      final auth = AuthBloc(RestoreSession(repository), Logout(repository));
      addTearDown(auth.close);
      await pumpShot(
        tester,
        b,
        const RegisterCustomerPage(),
        name: 'register',
        wrap: (child) => MultiBlocProvider(
          providers: [
            BlocProvider.value(value: auth),
            BlocProvider(
              create: (_) => RegisterBloc(
                RegisterCustomer(repository),
                RegisterCourtOwner(repository),
              ),
            ),
          ],
          child: child,
        ),
      );
      expect(find.text('Đăng ký khách hàng'), findsOneWidget);
    });

    testWidgets('forgot password matches the WP3b look (${b.name})', (
      tester,
    ) async {
      final repository = MockAuthRepository();
      await pumpShot(
        tester,
        b,
        const ForgotPasswordPage(),
        name: 'forgot-password',
        wrap: (child) => BlocProvider(
          create: (_) => ForgotPasswordBloc(RequestPasswordReset(repository)),
          child: child,
        ),
      );
      expect(find.text('Quên mật khẩu'), findsWidgets);
    });
  }
}
