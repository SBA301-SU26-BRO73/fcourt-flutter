import 'package:fcourt/features/auth/domain/usecases/login.dart';
import 'package:fcourt/features/auth/domain/usecases/logout.dart';
import 'package:fcourt/features/auth/domain/usecases/restore_session.dart';
import 'package:fcourt/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:fcourt/features/auth/presentation/bloc/login_bloc.dart';
import 'package:fcourt/features/auth/presentation/pages/login_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/wp3b_shots.dart';
import '../helpers.dart';

void main() {
  for (final b in Brightness.values) {
    testWidgets('login page matches the WP3b layout (${b.name})', (
      tester,
    ) async {
      final repository = MockAuthRepository();
      final authBloc = AuthBloc(RestoreSession(repository), Logout(repository));
      addTearDown(authBloc.close);
      await pumpShot(
        tester,
        b,
        const LoginPage(),
        name: 'login',
        prepare: (t) async {
          await t.enterText(
            find.byKey(const ValueKey('auth-field-Email')),
            'ban@email.com',
          );
          await t.enterText(
            find.byKey(const ValueKey('auth-field-Mật khẩu')),
            'abcdefgh',
          );
        },
        wrap: (child) => MultiBlocProvider(
          providers: [
            BlocProvider.value(value: authBloc),
            BlocProvider(create: (_) => LoginBloc(Login(repository))),
          ],
          child: child,
        ),
      );
      expect(find.text('Chào bạn trở lại'), findsOneWidget);
      expect(find.text('Tiếp tục với Google'), findsOneWidget);
    });
  }
}
