import 'package:bloc_test/bloc_test.dart';
import 'package:fcourt/core/error/failure.dart';
import 'package:fcourt/features/auth/domain/usecases/change_password.dart';
import 'package:fcourt/features/auth/domain/usecases/request_password_reset.dart';
import 'package:fcourt/features/auth/domain/usecases/reset_password.dart';
import 'package:fcourt/features/auth/presentation/bloc/change_password_bloc.dart';
import 'package:fcourt/features/auth/presentation/bloc/forgot_password_bloc.dart';
import 'package:fcourt/features/auth/presentation/bloc/reset_password_bloc.dart';
import 'package:fcourt/features/auth/presentation/bloc/submission_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers.dart';

void main() {
  late MockAuthRepository repository;

  setUp(() => repository = MockAuthRepository());

  group('ForgotPasswordBloc', () {
    ForgotPasswordBloc build() => ForgotPasswordBloc(RequestPasswordReset(repository));

    blocTest<ForgotPasswordBloc, SubmissionState>(
      'gửi yêu cầu thành công thì submitting rồi success không kèm người dùng',
      setUp: () => when(() => repository.requestPasswordReset('customer@demo.com'))
          .thenAnswer((_) async {}),
      build: build,
      act: (bloc) => bloc.add(const ForgotPasswordSubmitted('customer@demo.com')),
      expect: () => [const SubmissionState.submitting(), const SubmissionState.success()],
    );

    blocTest<ForgotPasswordBloc, SubmissionState>(
      'mất mạng thì failure để người dùng thử lại',
      setUp: () => when(() => repository.requestPasswordReset(any())).thenThrow(const NetworkFailure()),
      build: build,
      act: (bloc) => bloc.add(const ForgotPasswordSubmitted('customer@demo.com')),
      expect: () => [
        const SubmissionState.submitting(),
        const SubmissionState.failure('Không kết nối được máy chủ'),
      ],
    );

    blocTest<ForgotPasswordBloc, SubmissionState>(
      'bấm gửi hai lần liên tiếp chỉ gọi BE một lần',
      setUp: () => when(() => repository.requestPasswordReset(any()))
          .thenAnswer((_) => Future<void>.delayed(const Duration(milliseconds: 10))),
      build: build,
      act: (bloc) {
        bloc.add(const ForgotPasswordSubmitted('customer@demo.com'));
        bloc.add(const ForgotPasswordSubmitted('customer@demo.com'));
      },
      wait: const Duration(milliseconds: 50),
      verify: (_) => verify(() => repository.requestPasswordReset(any())).called(1),
    );
  });

  group('ResetPasswordBloc', () {
    ResetPasswordBloc build() => ResetPasswordBloc(ResetPassword(repository));

    blocTest<ResetPasswordBloc, SubmissionState>(
      'token đúng thì success',
      setUp: () => when(() => repository.resetPassword(token: 'abc123', newPassword: 'new-pass-2'))
          .thenAnswer((_) async {}),
      build: build,
      act: (bloc) => bloc.add(
        const ResetPasswordSubmitted(token: 'abc123', newPassword: 'new-pass-2'),
      ),
      expect: () => [const SubmissionState.submitting(), const SubmissionState.success()],
    );

    blocTest<ResetPasswordBloc, SubmissionState>(
      'token sai hoặc hết hạn thì failure kèm lý do của BE',
      setUp: () => when(
        () => repository.resetPassword(token: any(named: 'token'), newPassword: any(named: 'newPassword')),
      ).thenThrow(
        const ServerFailure('Reset token is invalid or has expired', statusCode: 400),
      ),
      build: build,
      act: (bloc) => bloc.add(
        const ResetPasswordSubmitted(token: 'bad', newPassword: 'new-pass-2'),
      ),
      expect: () => [
        const SubmissionState.submitting(),
        const SubmissionState.failure('Reset token is invalid or has expired'),
      ],
    );

    blocTest<ResetPasswordBloc, SubmissionState>(
      'lỗi validation theo field được chuyển cho form',
      setUp: () => when(
        () => repository.resetPassword(token: any(named: 'token'), newPassword: any(named: 'newPassword')),
      ).thenThrow(
        const ServerFailure(
          'Invalid request fields',
          statusCode: 400,
          fieldErrors: {'newPassword': 'newPassword must be 8 to 72 characters'},
        ),
      ),
      build: build,
      act: (bloc) => bloc.add(
        const ResetPasswordSubmitted(token: 'abc', newPassword: 'short'),
      ),
      expect: () => [
        const SubmissionState.submitting(),
        const SubmissionState.failure(
          'Invalid request fields',
          fieldErrors: {'newPassword': 'newPassword must be 8 to 72 characters'},
        ),
      ],
    );
  });

  group('ChangePasswordBloc', () {
    ChangePasswordBloc build() => ChangePasswordBloc(ChangePassword(repository));

    blocTest<ChangePasswordBloc, SubmissionState>(
      'đổi thành công thì success kèm người dùng, phiên vẫn còn',
      setUp: () => when(
        () => repository.changePassword(currentPassword: 'old-pass-1', newPassword: 'new-pass-2'),
      ).thenAnswer((_) async => customerUser),
      build: build,
      act: (bloc) => bloc.add(
        const ChangePasswordSubmitted(currentPassword: 'old-pass-1', newPassword: 'new-pass-2'),
      ),
      expect: () => [
        const SubmissionState.submitting(),
        const SubmissionState.success(customerUser),
      ],
    );

    blocTest<ChangePasswordBloc, SubmissionState>(
      'sai mật khẩu hiện tại thì failure',
      setUp: () => when(
        () => repository.changePassword(
          currentPassword: any(named: 'currentPassword'),
          newPassword: any(named: 'newPassword'),
        ),
      ).thenThrow(const ServerFailure('Current password is incorrect', statusCode: 400)),
      build: build,
      act: (bloc) => bloc.add(
        const ChangePasswordSubmitted(currentPassword: 'wrong', newPassword: 'new-pass-2'),
      ),
      expect: () => [
        const SubmissionState.submitting(),
        const SubmissionState.failure('Current password is incorrect'),
      ],
    );

    blocTest<ChangePasswordBloc, SubmissionState>(
      'gửi hai lần liên tiếp chỉ gọi BE một lần',
      setUp: () => when(
        () => repository.changePassword(
          currentPassword: any(named: 'currentPassword'),
          newPassword: any(named: 'newPassword'),
        ),
      ).thenAnswer((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return customerUser;
      }),
      build: build,
      act: (bloc) {
        const event = ChangePasswordSubmitted(currentPassword: 'old-pass-1', newPassword: 'new-pass-2');
        bloc.add(event);
        bloc.add(event);
      },
      wait: const Duration(milliseconds: 50),
      verify: (_) => verify(
        () => repository.changePassword(
          currentPassword: any(named: 'currentPassword'),
          newPassword: any(named: 'newPassword'),
        ),
      ).called(1),
    );
  });
}
