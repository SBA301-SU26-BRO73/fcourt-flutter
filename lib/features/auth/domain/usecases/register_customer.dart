import '../entities/auth_user.dart';
import '../repositories/auth_repository.dart';

class RegisterCustomer {
  const RegisterCustomer(this._repository);

  final AuthRepository _repository;

  Future<AuthUser> call({
    required String fullName,
    required String email,
    required String phone,
    required String password,
  }) => _repository.registerCustomer(
    fullName: fullName.trim(),
    email: email.trim(),
    phone: phone.trim(),
    password: password,
  );
}
