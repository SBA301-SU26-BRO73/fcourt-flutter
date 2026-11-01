import 'dart:convert';

/// Kiểm tra sớm ở phía app để người dùng sửa ngay; BE vẫn là nơi kiểm tra cuối cùng.
class AuthValidators {
  const AuthValidators._();

  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final _phone = RegExp(r'^(0|\+84)\d{8,10}$');

  static const passwordMinLength = 8;

  /// BCrypt chỉ băm 72 byte đầu nên BE từ chối mật khẩu dài hơn 72 ký tự hoặc 72 byte
  /// UTF-8 (chữ có dấu chiếm 2 đến 3 byte).
  static const passwordMaxLength = 72;

  static String? fullName(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Vui lòng nhập họ tên';
    if (text.length > 150) return 'Họ tên tối đa 150 ký tự';
    return null;
  }

  static String? email(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Vui lòng nhập email';
    if (!_email.hasMatch(text)) return 'Email không hợp lệ';
    return null;
  }

  static String? phone(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Vui lòng nhập số điện thoại';
    if (!_phone.hasMatch(text)) {
      return 'Số điện thoại không hợp lệ (ví dụ 0909000001)';
    }
    return null;
  }

  static String? password(String? value) {
    final text = value ?? '';
    if (text.isEmpty) return 'Vui lòng nhập mật khẩu';
    if (text.length < passwordMinLength) {
      return 'Mật khẩu tối thiểu $passwordMinLength ký tự';
    }
    if (text.length > passwordMaxLength) {
      return 'Mật khẩu tối đa $passwordMaxLength ký tự';
    }
    if (utf8.encode(text).length > passwordMaxLength) {
      return 'Mật khẩu quá dài: tối đa $passwordMaxLength byte, chữ có dấu tính 2 đến 3 byte';
    }
    return null;
  }

  /// Ô đăng nhập chỉ cần có nội dung: không lộ quy tắc đặt mật khẩu.
  static String? loginPassword(String? value) =>
      (value == null || value.isEmpty) ? 'Vui lòng nhập mật khẩu' : null;

  static String? Function(String?) confirmPassword(String Function() original) {
    return (value) {
      if (value == null || value.isEmpty) return 'Vui lòng nhập lại mật khẩu';
      if (value != original()) return 'Mật khẩu nhập lại không khớp';
      return null;
    };
  }
}
