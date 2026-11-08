import 'package:dio/dio.dart';

import '../../../../core/network/auth_interceptor.dart';
import '../../domain/entities/upload_document.dart';
import '../models/auth_session_model.dart';
import '../models/user_model.dart';

class AuthRemoteDataSource {
  const AuthRemoteDataSource(this._dio);

  static const _base = '/api/auth';

  final Dio _dio;

  /// Request công khai: không gắn Bearer và không kích hoạt refresh khi gặp 401.
  Options get _public => Options(extra: {AuthInterceptor.skipAuthKey: true});

  Future<AuthSessionModel> login(String email, String password) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '$_base/login',
      data: {'email': email, 'password': password},
      options: _public,
    );
    return AuthSessionModel.fromJson(response.data ?? const {});
  }

  Future<AuthSessionModel> loginWithGoogle(String idToken) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '$_base/google',
      data: {'idToken': idToken},
      options: _public,
    );
    return AuthSessionModel.fromJson(response.data ?? const {});
  }

  Future<AuthSessionModel> registerCustomer({
    required String fullName,
    required String email,
    required String phone,
    required String password,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '$_base/register/customer',
      data: {
        'fullName': fullName,
        'email': email,
        'phone': phone,
        'password': password,
      },
      options: _public,
    );
    return AuthSessionModel.fromJson(response.data ?? const {});
  }

  Future<void> registerCourtOwner({
    required String fullName,
    required String email,
    required String phone,
    required String password,
    required List<UploadDocument> legalDocuments,
    required List<UploadDocument> courtImages,
  }) async {
    final form = FormData()
      ..fields.addAll([
        MapEntry('fullName', fullName),
        MapEntry('email', email),
        MapEntry('phone', phone),
        MapEntry('password', password),
      ]);
    await _addFiles(form, 'legalDocuments', legalDocuments);
    await _addFiles(form, 'courtImages', courtImages);
    await _dio.post<dynamic>(
      '$_base/register/court-owner',
      data: form,
      options: _public,
    );
  }

  Future<UserModel> fetchProfile() async {
    final response = await _dio.get<Map<String, dynamic>>('$_base/profile');
    return UserModel.fromJson(response.data ?? const {});
  }

  Future<UserModel> updateProfile(String fullName, String phone) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '$_base/profile',
      data: {'fullName': fullName, 'phone': phone},
    );
    return UserModel.fromJson(response.data ?? const {});
  }

  Future<void> logout(String refreshToken) async {
    await _dio.post<dynamic>(
      '$_base/logout',
      data: {'refreshToken': refreshToken},
      options: _public,
    );
  }

  Future<void> forgotPassword(String email) async {
    await _dio.post<dynamic>(
      '$_base/password/forgot',
      data: {'email': email},
      options: _public,
    );
  }

  Future<void> resetPassword(String token, String newPassword) async {
    await _dio.post<dynamic>(
      '$_base/password/reset',
      data: {'token': token, 'newPassword': newPassword},
      options: _public,
    );
  }

  /// Cần token. BE trả cặp token mới vì mọi phiên cũ (kể cả phiên này) đã bị thu hồi.
  Future<AuthSessionModel> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '$_base/password',
      data: {'currentPassword': currentPassword, 'newPassword': newPassword},
    );
    return AuthSessionModel.fromJson(response.data ?? const {});
  }

  Future<void> _addFiles(
    FormData form,
    String field,
    List<UploadDocument> documents,
  ) async {
    for (final document in documents) {
      form.files.add(
        MapEntry(
          field,
          await MultipartFile.fromFile(
            document.path,
            filename: document.name,
            contentType: DioMediaType.parse(contentTypeOf(document.name)),
          ),
        ),
      );
    }
  }

  /// Loại tệp BE chấp nhận; đuôi lạ gửi `application/octet-stream` để BE từ chối rõ ràng.
  static String contentTypeOf(String fileName) {
    final dot = fileName.lastIndexOf('.');
    final extension = dot < 0 ? '' : fileName.substring(dot + 1).toLowerCase();
    return switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'pdf' => 'application/pdf',
      _ => 'application/octet-stream',
    };
  }
}
