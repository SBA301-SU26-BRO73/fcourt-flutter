import 'package:bloc_test/bloc_test.dart';
import 'package:fcourt/core/error/failure.dart';
import 'package:fcourt/features/auth/domain/usecases/update_profile.dart';
import 'package:fcourt/features/auth/presentation/bloc/profile_bloc.dart';
import 'package:fcourt/features/auth/presentation/bloc/submission_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers.dart';

void main() {
  late MockAuthRepository repository;

  setUp(() => repository = MockAuthRepository());

  ProfileBloc build() => ProfileBloc(UpdateProfile(repository));

  blocTest<ProfileBloc, SubmissionState>(
    'lưu thành công thì success kèm người dùng đã cập nhật',
    setUp: () => when(() => repository.updateProfile(fullName: 'New Name', phone: '0911222333'))
        .thenAnswer((_) async => customerUser.copyWith(fullName: 'New Name', phone: '0911222333')),
    build: build,
    act: (bloc) => bloc.add(const ProfileSubmitted(fullName: 'New Name', phone: '0911222333')),
    expect: () => [
      const SubmissionState.submitting(),
      SubmissionState.success(customerUser.copyWith(fullName: 'New Name', phone: '0911222333')),
    ],
  );

  blocTest<ProfileBloc, SubmissionState>(
    'số điện thoại đã có người dùng thì failure',
    setUp: () => when(
      () => repository.updateProfile(fullName: any(named: 'fullName'), phone: any(named: 'phone')),
    ).thenThrow(const ServerFailure('Phone number is already registered', statusCode: 409)),
    build: build,
    act: (bloc) => bloc.add(const ProfileSubmitted(fullName: 'New Name', phone: '0911222333')),
    expect: () => [
      const SubmissionState.submitting(),
      const SubmissionState.failure('Phone number is already registered'),
    ],
  );

  blocTest<ProfileBloc, SubmissionState>(
    'phiên hết hạn khi đang lưu thì failure với thông báo hết phiên',
    setUp: () => when(
      () => repository.updateProfile(fullName: any(named: 'fullName'), phone: any(named: 'phone')),
    ).thenThrow(const UnauthorizedFailure()),
    build: build,
    act: (bloc) => bloc.add(const ProfileSubmitted(fullName: 'New Name', phone: '0911222333')),
    expect: () => [
      const SubmissionState.submitting(),
      const SubmissionState.failure('Phiên đăng nhập đã hết hạn'),
    ],
  );
}
