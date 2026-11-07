import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:fcourt/app/auth_redirect.dart';
import 'package:fcourt/core/error/failure.dart';
import 'package:fcourt/features/auth/domain/entities/auth_user.dart';
import 'package:fcourt/features/auth/domain/entities/user_role.dart';
import 'package:fcourt/features/auth/domain/usecases/logout.dart';
import 'package:fcourt/features/auth/domain/usecases/restore_session.dart';
import 'package:fcourt/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers.dart';

const staff = AuthUser(
  id: 100,
  email: '',
  role: UserRole.staff,
  status: 'ACTIVE',
);

void main() {
  late MockAuthRepository repository;
  setUp(() => repository = MockAuthRepository());
  AuthBloc build(Future<AuthUser?> Function() cached) => AuthBloc(
    RestoreSession(repository),
    Logout(repository),
    restoreOfflineStaff: cached,
  );

  blocTest<AuthBloc, AuthState>(
    'network failure opens only an offline staff capability',
    setUp: () =>
        when(() => repository.restoreSession())
            .thenThrow(const NetworkFailure()),
    build: () => build(() async => staff),
    act: (bloc) => bloc.add(const AuthStarted()),
    expect: () => [const AuthState.offlineStaff(staff)],
  );

  blocTest<AuthBloc, AuthState>(
    'authorization rejection never falls back to cache',
    setUp: () =>
        when(() => repository.restoreSession())
            .thenThrow(const UnauthorizedFailure()),
    build: () => build(() async => throw StateError('must not read cache')),
    act: (bloc) => bloc.add(const AuthStarted()),
    expect: () => [const AuthState.unauthenticated()],
  );

  for (final cached in [
    null,
    adminUser,
    const AuthUser(
      id: 100,
      email: '',
      role: UserRole.staff,
      status: 'INACTIVE',
    ),
  ]) {
    blocTest<AuthBloc, AuthState>(
      'missing or unauthorized cached identity fails closed: $cached',
      setUp: () =>
          when(() => repository.restoreSession())
              .thenThrow(const NetworkFailure()),
      build: () => build(() async => cached),
      act: (bloc) => bloc.add(const AuthStarted()),
      expect: () => [const AuthState.unauthenticated()],
    );
  }

  test('expired session event prevents a late offline restore from reopening access', () async {
    when(() => repository.restoreSession()).thenThrow(const NetworkFailure());
    final pending = Completer<AuthUser?>();
    final started = Completer<void>();
    final bloc = build(() {
      started.complete();
      return pending.future;
    });
    bloc.add(const AuthStarted());
    await started.future;
    final expired = bloc.stream.firstWhere(
      (s) => s.status == AuthStatus.unauthenticated,
    );
    bloc.add(const AuthSessionExpired());
    await expired;
    pending.complete(staff);
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state, const AuthState.unauthenticated());
    await bloc.close();
  });

  test('offline capability cannot open protected online routes', () {
    for (final path in [
      AppRoutes.home,
      '/staff/schedule',
      '/staff/pos',
      '/admin/staff',
      '/super-admin/owners',
      '/bookings',
      AppRoutes.profile,
    ]) {
      expect(
        authRedirect(AuthStatus.offlineStaff, path, role: UserRole.staff),
        AppRoutes.offlineCheckIn,
      );
    }
    expect(
      authRedirect(
        AuthStatus.offlineStaff,
        AppRoutes.offlineCheckIn,
        role: UserRole.staff,
      ),
      isNull,
    );
  });

  blocTest<AuthBloc, AuthState>(
    'reconnect replaces offline access with a server-verified session',
    setUp: () =>
        when(() => repository.restoreSession()).thenAnswer((_) async => staff),
    build: () => build(() async => throw StateError('cache must not be used')),
    seed: () => const AuthState.offlineStaff(staff),
    act: (bloc) => bloc.add(const AuthStarted()),
    expect: () => [
      const AuthState.unknown(),
      const AuthState.authenticated(staff),
    ],
  );

  blocTest<AuthBloc, AuthState>(
    'logout still exits offline mode if remote logout fails',
    setUp: () =>
        when(() => repository.logout()).thenThrow(const NetworkFailure()),
    build: () => build(() async => staff),
    seed: () => const AuthState.offlineStaff(staff),
    act: (bloc) => bloc.add(const AuthLogoutRequested()),
    expect: () => [const AuthState.unauthenticated()],
  );
}
