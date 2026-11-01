import '../../domain/entities/auth_user.dart';
import '../../domain/entities/user_role.dart';

class UserModel {
  const UserModel({
    required this.id,
    required this.email,
    required this.role,
    required this.status,
    this.fullName,
    this.phone,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: (json['id'] as num).toInt(),
        email: json['email'] as String,
        role: json['role'] as String?,
        status: (json['status'] as String?) ?? '',
        fullName: json['fullName'] as String?,
        phone: json['phone'] as String?,
      );

  final int id;
  final String email;
  final String? role;
  final String status;
  final String? fullName;
  final String? phone;

  AuthUser toEntity() => AuthUser(
        id: id,
        email: email,
        role: UserRole.fromApi(role),
        status: status,
        fullName: fullName,
        phone: phone,
      );
}
