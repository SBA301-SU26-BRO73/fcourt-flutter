import 'package:fcourt/app/theme/theme_controller.dart';
import 'package:fcourt/features/auth/domain/usecases/logout.dart';
import 'package:fcourt/features/auth/domain/usecases/restore_session.dart';
import 'package:fcourt/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:fcourt/features/auth/presentation/pages/profile_page.dart';
import 'package:fcourt/features/settings/presentation/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/wp3b_shots.dart';
import '../helpers.dart';

void main() {
  for (final b in Brightness.values) {
    for (final entry in {
      'account': const ProfilePage(),
      'settings': const SettingsPage(),
    }.entries) {
      testWidgets('${entry.key} matches the WP3b look (${b.name})', (
        tester,
      ) async {
        final repository = MockAuthRepository();
        final auth = AuthBloc(RestoreSession(repository), Logout(repository))
          ..add(const AuthSignedIn(customerUser));
        addTearDown(auth.close);
        final theme = ThemeController(write: (_) async {});
        addTearDown(theme.dispose);
        await pumpShot(
          tester,
          b,
          entry.value,
          name: entry.key,
          wrap: (child) => BlocProvider.value(
            value: auth,
            child: ThemeScope(controller: theme, child: child),
          ),
        );
        expect(find.text('Cài đặt'), findsWidgets);
      });
    }
  }
}
