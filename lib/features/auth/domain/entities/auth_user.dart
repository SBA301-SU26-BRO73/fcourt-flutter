import 'package:equatable/equatable.dart';

import 'user_role.dart';

class AuthUser extends Equatable {
  const AuthUser({
    required this.id,
    required this.email,
    required this.role,
    required this.status,
    this.fullName,
    this.phone,
  });

  final int id;
  final String email;
  final UserRole role;
  final String status;
  final String? fullName;
  final String? phone;

  /// Tên hiển thị: họ tên nếu có, không thì email.
  String get displayName =>
      (fullName == null || fullName!.trim().isEmpty) ? email : fullName!;

  AuthUser copyWith({String? fullName, String? phone}) => AuthUser(
        id: id,
        email: email,
        role: role,
        status: status,
        fullName: fullName ?? this.fullName,
        phone: phone ?? this.phone,
      );

  @override
  List<Object?> get props => [id, email, role, status, fullName, phone];
}
