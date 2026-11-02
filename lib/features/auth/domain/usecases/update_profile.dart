import '../entities/auth_user.dart';
import '../repositories/auth_repository.dart';

class UpdateProfile {
  const UpdateProfile(this._repository);

  final AuthRepository _repository;

  Future<AuthUser> call({required String fullName, required String phone}) =>
      _repository.updateProfile(fullName: fullName.trim(), phone: phone.trim());
}
