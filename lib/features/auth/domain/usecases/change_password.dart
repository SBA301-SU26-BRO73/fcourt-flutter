import '../entities/auth_user.dart';
import '../repositories/auth_repository.dart';

class ChangePassword {
  const ChangePassword(this._repository);

  final AuthRepository _repository;

  Future<AuthUser> call({
    required String currentPassword,
    required String newPassword,
  }) =>
      _repository.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
}
