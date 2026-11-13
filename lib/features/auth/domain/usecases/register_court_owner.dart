import '../entities/upload_document.dart';
import '../repositories/auth_repository.dart';

class RegisterCourtOwner {
  const RegisterCourtOwner(this._repository);

  final AuthRepository _repository;

  Future<void> call({
    required String fullName,
    required String email,
    required String phone,
    required String password,
    required List<UploadDocument> legalDocuments,
    List<UploadDocument> courtImages = const [],
  }) => _repository.registerCourtOwner(
    fullName: fullName.trim(),
    email: email.trim(),
    phone: phone.trim(),
    password: password,
    legalDocuments: legalDocuments,
    courtImages: courtImages,
  );
}
