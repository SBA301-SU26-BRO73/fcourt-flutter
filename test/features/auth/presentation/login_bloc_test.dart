import 'package:bloc_test/bloc_test.dart';
import 'package:fcourt/core/error/failure.dart';
import 'package:fcourt/features/auth/domain/usecases/login.dart';
import 'package:fcourt/features/auth/presentation/bloc/login_bloc.dart';
import 'package:fcourt/features/auth/presentation/bloc/submission_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers.dart';

void main() {
  late MockAuthRepository repository;

  setUp(() => repository = MockAuthRepository());

  LoginBloc build() => LoginBloc(Login(repository));

  blocTest<LoginBloc, SubmissionState>(
    'đăng nhập đúng thì submitting rồi success kèm người dùng',
    setUp: () => when(() => repository.login(email: 'customer@demo.com', password: 'S3cret-pass'))
        .thenAnswer((_) async => customerUser),
    build: build,
    act: (bloc) => bloc.add(
      const LoginSubmitted(email: 'customer@demo.com', password: 'S3cret-pass'),
    ),
    expect: () => [
      const SubmissionState.submitting(),
      const SubmissionState.success(customerUser),
    ],
  );

  blocTest<LoginBloc, SubmissionState>(
    'sai mật khẩu thì failure kèm lý do của BE',
    setUp: () => when(() => repository.login(email: any(named: 'email'), password: any(named: 'password')))
        .thenThrow(const UnauthorizedFailure('Invalid email or password')),
    build: build,
    act: (bloc) => bloc.add(const LoginSubmitted(email: 'a@demo.com', password: 'x')),
    expect: () => [
      const SubmissionState.submitting(),
      const SubmissionState.failure('Invalid email or password'),
    ],
  );

  blocTest<LoginBloc, SubmissionState>(
    'giữ lỗi validation theo field mà BE trả về',
    setUp: () => when(() => repository.login(email: any(named: 'email'), password: any(named: 'password')))
        .thenThrow(
      const ServerFailure(
        'Invalid request fields',
        statusCode: 400,
        fieldErrors: {'email': 'email is invalid'},
      ),
    ),
    build: build,
    act: (bloc) => bloc.add(const LoginSubmitted(email: 'bad', password: 'x')),
    expect: () => [
      const SubmissionState.submitting(),
      const SubmissionState.failure(
        'Invalid request fields',
        fieldErrors: {'email': 'email is invalid'},
      ),
    ],
  );

  blocTest<LoginBloc, SubmissionState>(
    'mất mạng thì failure với thông báo mạng',
    setUp: () => when(() => repository.login(email: any(named: 'email'), password: any(named: 'password')))
        .thenThrow(const NetworkFailure()),
    build: build,
    act: (bloc) => bloc.add(const LoginSubmitted(email: 'a@demo.com', password: 'x')),
    expect: () => [
      const SubmissionState.submitting(),
      const SubmissionState.failure('Không kết nối được máy chủ'),
    ],
  );

  blocTest<LoginBloc, SubmissionState>(
    'bấm đăng nhập lần nữa khi đang gửi thì bỏ qua, chỉ gọi BE một lần',
    setUp: () => when(() => repository.login(email: any(named: 'email'), password: any(named: 'password')))
        .thenAnswer((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      return customerUser;
    }),
    build: build,
    act: (bloc) {
      bloc.add(const LoginSubmitted(email: 'a@demo.com', password: 'x'));
      bloc.add(const LoginSubmitted(email: 'a@demo.com', password: 'x'));
    },
    wait: const Duration(milliseconds: 50),
    verify: (_) => verify(
      () => repository.login(email: any(named: 'email'), password: any(named: 'password')),
    ).called(1),
  );
}
