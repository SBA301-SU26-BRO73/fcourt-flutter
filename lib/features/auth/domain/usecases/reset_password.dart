import '../repositories/auth_repository.dart';

class ResetPassword {
  const ResetPassword(this._repository);

  final AuthRepository _repository;

  /// Token dán từ email hay bị dính khoảng trắng hoặc xuống dòng nên được cắt trước khi gửi.
  Future<void> call({required String token, required String newPassword}) =>
      _repository.resetPassword(token: token.trim(), newPassword: newPassword);
}
