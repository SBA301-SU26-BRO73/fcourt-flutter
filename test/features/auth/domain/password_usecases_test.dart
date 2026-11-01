import 'package:fcourt/features/auth/domain/usecases/change_password.dart';
import 'package:fcourt/features/auth/domain/usecases/request_password_reset.dart';
import 'package:fcourt/features/auth/domain/usecases/reset_password.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers.dart';

void main() {
  late MockAuthRepository repository;

  setUp(() => repository = MockAuthRepository());

  test('RequestPasswordReset cắt khoảng trắng quanh email', () async {
    when(() => repository.requestPasswordReset('customer@demo.com')).thenAnswer((_) async {});

    await RequestPasswordReset(repository)('  customer@demo.com ');

    verify(() => repository.requestPasswordReset('customer@demo.com')).called(1);
  });

  test('ResetPassword cắt khoảng trắng và xuống dòng dính theo token dán từ email', () async {
    when(() => repository.resetPassword(token: 'abc123', newPassword: ' new pass '))
        .thenAnswer((_) async {});

    await ResetPassword(repository)(token: '  abc123\n', newPassword: ' new pass ');

    verify(() => repository.resetPassword(token: 'abc123', newPassword: ' new pass ')).called(1);
  });

  test('ChangePassword chuyển nguyên hai mật khẩu và trả người dùng', () async {
    when(() => repository.changePassword(currentPassword: 'old-pass-1', newPassword: 'new-pass-2'))
        .thenAnswer((_) async => customerUser);

    final user = await ChangePassword(repository)(
      currentPassword: 'old-pass-1',
      newPassword: 'new-pass-2',
    );

    expect(user, customerUser);
  });
}
