import 'package:fcourt/features/auth/presentation/messages.dart';
import 'package:fcourt/features/auth/presentation/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthValidators', () {
    test('họ tên bắt buộc và tối đa 150 ký tự', () {
      expect(AuthValidators.fullName(null), isNotNull);
      expect(AuthValidators.fullName('   '), isNotNull);
      expect(AuthValidators.fullName('a' * 151), isNotNull);
      expect(AuthValidators.fullName('An Nguyen'), isNull);
      expect(AuthValidators.fullName('a' * 150), isNull);
    });

    test('email phải có dạng a@b.c', () {
      expect(AuthValidators.email(''), isNotNull);
      expect(AuthValidators.email('not-an-email'), isNotNull);
      expect(AuthValidators.email('a@b'), isNotNull);
      expect(AuthValidators.email('a b@demo.com'), isNotNull);
      expect(AuthValidators.email(' customer@demo.com '), isNull);
    });

    test('số điện thoại theo quy tắc của BE: 0 hoặc +84 rồi 8 đến 10 chữ số', () {
      expect(AuthValidators.phone(''), isNotNull);
      expect(AuthValidators.phone('12345'), isNotNull);
      expect(AuthValidators.phone('0909 000 001'), isNotNull);
      expect(AuthValidators.phone('090900000'), isNull);
      expect(AuthValidators.phone('0909000001'), isNull);
      expect(AuthValidators.phone('+84909000001'), isNull);
      expect(AuthValidators.phone('09090000011'), isNull);
      expect(AuthValidators.phone('090900000011'), isNotNull);
      expect(AuthValidators.phone('0909000'), isNotNull);
    });

    test('mật khẩu từ 8 đến 72 ký tự', () {
      expect(AuthValidators.password(''), isNotNull);
      expect(AuthValidators.password('1234567'), isNotNull);
      expect(AuthValidators.password('12345678'), isNull);
      expect(AuthValidators.password('x' * 72), isNull);
      expect(AuthValidators.password('x' * 73), isNotNull);
    });

    test('ô mật khẩu đăng nhập chỉ cần có nội dung', () {
      expect(AuthValidators.loginPassword(''), isNotNull);
      expect(AuthValidators.loginPassword(null), isNotNull);
      expect(AuthValidators.loginPassword('1'), isNull);
    });

    test('nhập lại mật khẩu phải khớp mật khẩu hiện tại', () {
      var password = 'S3cret-pass';
      final validate = AuthValidators.confirmPassword(() => password);

      expect(validate(''), isNotNull);
      expect(validate('other-pass'), isNotNull);
      expect(validate('S3cret-pass'), isNull);

      password = 'changed-pass';
      expect(validate('S3cret-pass'), isNotNull);
    });
  });

  group('AuthMessages', () {
    test('đổi các lỗi BE đã biết sang tiếng Việt', () {
      expect(
        AuthMessages.localize('Invalid email or password'),
        'Email hoặc mật khẩu không đúng',
      );
      expect(AuthMessages.localize('Account is locked'), 'Tài khoản đã bị khóa');
      expect(
        AuthMessages.localize('Account is awaiting approval'),
        'Tài khoản đang chờ quản trị viên duyệt',
      );
    });

    test('đổi các lỗi của luồng mật khẩu sang tiếng Việt', () {
      expect(
        AuthMessages.localize('Reset token is invalid or has expired'),
        'Liên kết đặt lại mật khẩu không hợp lệ hoặc đã hết hạn',
      );
      expect(
        AuthMessages.localize('Current password is incorrect'),
        'Mật khẩu hiện tại không đúng',
      );
      expect(
        AuthMessages.localize('New password must differ from the current password'),
        'Mật khẩu mới phải khác mật khẩu hiện tại',
      );
    });

    test('lỗi chưa biết giữ nguyên để không mất thông tin', () {
      expect(AuthMessages.localize('something new'), 'something new');
    });

    test('localizeAll đổi từng lỗi theo field và giữ tên field', () {
      expect(
        AuthMessages.localizeAll({
          'email': 'Email is already registered',
          'password': 'password must be 8 to 72 characters',
        }),
        {
          'email': 'Email này đã được đăng ký',
          'password': 'password must be 8 to 72 characters',
        },
      );
    });
  });
}
