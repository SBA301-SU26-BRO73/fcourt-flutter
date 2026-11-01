import 'package:dio/dio.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/storage/token_storage.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/entities/upload_document.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';
import '../models/auth_session_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl(this._remote, this._tokens);

  final AuthRemoteDataSource _remote;
  final TokenStorage _tokens;

  @override
  Future<AuthUser?> restoreSession() async {
    if (await _tokens.read() == null) return null;
    try {
      return (await _remote.fetchProfile()).toEntity();
    } on DioException catch (e) {
      final failure = failureFromDio(e);
      if (_isDeadSession(failure)) {
        await _tokens.clear();
        return null;
      }
      throw failure;
    }
  }

  @override
  Future<AuthUser> login({required String email, required String password}) =>
      _openSession(() => _remote.login(email, password));

  @override
  Future<AuthUser> registerCustomer({
    required String fullName,
    required String email,
    required String phone,
    required String password,
  }) =>
      _openSession(
        () => _remote.registerCustomer(
          fullName: fullName,
          email: email,
          phone: phone,
          password: password,
        ),
      );

  @override
  Future<void> registerCourtOwner({
    required String fullName,
    required String email,
    required String phone,
    required String password,
    required List<UploadDocument> legalDocuments,
    List<UploadDocument> courtImages = const [],
  }) async {
    try {
      await _remote.registerCourtOwner(
        fullName: fullName,
        email: email,
        phone: phone,
        password: password,
        legalDocuments: legalDocuments,
        courtImages: courtImages,
      );
    } on DioException catch (e) {
      throw failureFromDio(e);
    }
  }

  @override
  Future<AuthUser> updateProfile({
    required String fullName,
    required String phone,
  }) async {
    try {
      return (await _remote.updateProfile(fullName, phone)).toEntity();
    } on DioException catch (e) {
      throw failureFromDio(e);
    }
  }

  @override
  Future<void> logout() async {
    final tokens = await _tokens.read();
    try {
      if (tokens != null) await _remote.logout(tokens.refreshToken);
    } on DioException {
      // Thu hồi phía BE là cố gắng tối đa: người dùng vẫn phải thoát được khi mất mạng.
    } finally {
      await _tokens.clear();
    }
  }

  Future<AuthUser> _openSession(Future<AuthSessionModel> Function() call) async {
    try {
      final session = await call();
      await _tokens.save(
        AuthTokens(
          accessToken: session.accessToken,
          refreshToken: session.refreshToken,
        ),
      );
      return session.user.toEntity();
    } on DioException catch (e) {
      throw failureFromDio(e);
    }
  }

  /// 401 sau khi interceptor đã thử refresh, hoặc 403 vì tài khoản bị khóa.
  bool _isDeadSession(Failure failure) =>
      failure is UnauthorizedFailure ||
      (failure is ServerFailure && failure.statusCode == 403);
}
