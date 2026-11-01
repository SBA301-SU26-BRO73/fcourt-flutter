import 'package:bloc_test/bloc_test.dart';
import 'package:fcourt/core/error/failure.dart';
import 'package:fcourt/features/auth/domain/entities/user_role.dart';
import 'package:fcourt/features/auth/domain/usecases/logout.dart';
import 'package:fcourt/features/auth/domain/usecases/restore_session.dart';
import 'package:fcourt/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers.dart';

void main() {
  late MockAuthRepository repository;

  setUp(() => repository = MockAuthRepository());

  AuthBloc build() => AuthBloc(RestoreSession(repository), Logout(repository));

  test('bắt đầu ở trạng thái chưa biết', () {
    expect(build().state, const AuthState.unknown());
  });

  group('AuthStarted', () {
    blocTest<AuthBloc, AuthState>(
      'có phiên cũ thì đăng nhập với vai trò của người dùng',
      setUp: () => when(() => repository.restoreSession()).thenAnswer((_) async => adminUser),
      build: build,
      act: (bloc) => bloc.add(const AuthStarted()),
      expect: () => [const AuthState.authenticated(adminUser)],
      verify: (bloc) => expect(bloc.state.role, UserRole.admin),
    );

    blocTest<AuthBloc, AuthState>(
      'không có phiên thì chưa đăng nhập',
      setUp: () => when(() => repository.restoreSession()).thenAnswer((_) async => null),
      build: build,
      act: (bloc) => bloc.add(const AuthStarted()),
      expect: () => [const AuthState.unauthenticated()],
    );

    blocTest<AuthBloc, AuthState>(
      'không hỏi được BE (mất mạng) thì về màn đăng nhập thay vì kẹt ở màn chờ',
      setUp: () => when(() => repository.restoreSession()).thenThrow(const NetworkFailure()),
      build: build,
      act: (bloc) => bloc.add(const AuthStarted()),
      expect: () => [const AuthState.unauthenticated()],
    );

    blocTest<AuthBloc, AuthState>(
      'lỗi bất ngờ (Keystore hỏng) vẫn rời màn chờ',
      setUp: () => when(() => repository.restoreSession())
          .thenThrow(StateError('keystore unavailable')),
      build: build,
      act: (bloc) => bloc.add(const AuthStarted()),
      expect: () => [const AuthState.unauthenticated()],
    );
  });

  blocTest<AuthBloc, AuthState>(
    'AuthSignedIn lưu người dùng và vai trò',
    build: build,
    act: (bloc) => bloc.add(const AuthSignedIn(customerUser)),
    expect: () => [const AuthState.authenticated(customerUser)],
  );

  group('AuthUserUpdated', () {
    blocTest<AuthBloc, AuthState>(
      'cập nhật người dùng khi đang đăng nhập',
      build: build,
      seed: () => const AuthState.authenticated(customerUser),
      act: (bloc) => bloc.add(AuthUserUpdated(customerUser.copyWith(fullName: 'New Name'))),
      expect: () => [AuthState.authenticated(customerUser.copyWith(fullName: 'New Name'))],
    );

    blocTest<AuthBloc, AuthState>(
      'bỏ qua khi chưa đăng nhập, không tự đăng nhập lại',
      build: build,
      seed: () => const AuthState.unauthenticated(),
      act: (bloc) => bloc.add(const AuthUserUpdated(customerUser)),
      expect: () => <AuthState>[],
    );
  });

  blocTest<AuthBloc, AuthState>(
    'AuthLogoutRequested đăng xuất rồi chuyển sang chưa đăng nhập',
    setUp: () => when(() => repository.logout()).thenAnswer((_) async {}),
    build: build,
    seed: () => const AuthState.authenticated(customerUser),
    act: (bloc) => bloc.add(const AuthLogoutRequested()),
    expect: () => [const AuthState.unauthenticated()],
    verify: (_) => verify(() => repository.logout()).called(1),
  );

  blocTest<AuthBloc, AuthState>(
    'AuthSessionExpired đưa người dùng về chưa đăng nhập mà không gọi BE',
    build: build,
    seed: () => const AuthState.authenticated(customerUser),
    act: (bloc) => bloc.add(const AuthSessionExpired()),
    expect: () => [const AuthState.unauthenticated()],
    verify: (_) => verifyNever(() => repository.logout()),
  );
}
