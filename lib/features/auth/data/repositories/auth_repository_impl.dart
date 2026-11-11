import 'package:dio/dio.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/storage/token_storage.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/entities/upload_document.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';
import '../models/auth_session_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._remote, this._tokens, {this._beforeLogout});

  final AuthRemoteDataSource _remote;
  final TokenStorage _tokens;
  final Future<void> Function()? _beforeLogout;
  Future<void>? _googleInitialization;

  @override
  Future<AuthUser?> restoreSession() async {
    if (await _tokens.read() == null) return null;
    try {
      return await _guard(
        () async => (await _remote.fetchProfile()).toEntity(),
      );
    } on Failure catch (failure) {
      if (_isDeadSession(failure)) {
        await _tokens.clear();
        return null;
      }
      rethrow;
    }
  }

  @override
  Future<AuthUser> login({required String email, required String password}) =>
      _openSession(() => _remote.login(email, password));

  @override
  Future<AuthUser?> loginWithGoogle() async {
    const clientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
    if (clientId.isEmpty) {
      throw const UnknownFailure('Thiếu cấu hình Google Web Client ID');
    }
    try {
      final google = GoogleSignIn.instance;
      await (_googleInitialization ??= google.initialize(
        serverClientId: clientId,
      ));
      final account = await google.authenticate();
      final token = account.authentication.idToken;
      if (token == null || token.isEmpty) {
        throw const UnknownFailure('Google không trả về ID token');
      }
      return await _openSession(() => _remote.loginWithGoogle(token));
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) return null;
      throw const UnknownFailure('Đăng nhập Google thất bại, vui lòng thử lại');
    }
  }

  @override
  Future<AuthUser> registerCustomer({
    required String fullName,
    required String email,
    required String phone,
    required String password,
  }) => _openSession(
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
  }) => _guard(
    () => _remote.registerCourtOwner(
      fullName: fullName,
      email: email,
      phone: phone,
      password: password,
      legalDocuments: legalDocuments,
      courtImages: courtImages,
    ),
  );

  @override
  Future<AuthUser> updateProfile({
    required String fullName,
    required String phone,
  }) => _guard(
    () async => (await _remote.updateProfile(fullName, phone)).toEntity(),
  );

  @override
  Future<void> requestPasswordReset(String email) =>
      _guard(() => _remote.forgotPassword(email));

  @override
  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) => _guard(() => _remote.resetPassword(token, newPassword));

  @override
  Future<AuthUser> changePassword({
    required String currentPassword,
    required String newPassword,
  }) =>
      _openSession(() => _remote.changePassword(currentPassword, newPassword));

  @override
  Future<void> logout() async {
    final tokens = await _tokens.read();
    try {
      if (tokens != null && _beforeLogout != null) {
        try {
          await _beforeLogout().timeout(const Duration(seconds: 3));
        } catch (_) {
          // Push cleanup is best effort; logout must proceed even if it fails.
        }
      }
      if (tokens != null) await _remote.logout(tokens.refreshToken);
    } on DioException {
      // Thu hồi phía BE là cố gắng tối đa: người dùng vẫn phải thoát được khi mất mạng.
    } finally {
      await _tokens.clear();
    }
  }

  Future<AuthUser> _openSession(Future<AuthSessionModel> Function() call) =>
      _guard(() async {
        final session = await call();
        await _tokens.save(
          AuthTokens(
            accessToken: session.accessToken,
            refreshToken: session.refreshToken,
          ),
        );
        return session.user.toEntity();
      });

  /// Đổi lỗi Dio thành [Failure]; body sai hợp đồng (thiếu field, sai kiểu) thành
  /// [UnknownFailure] để bloc không bị kẹt ở trạng thái đang gửi.
  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw failureFromDio(e);
    } on TypeError {
      throw const UnknownFailure();
    }
  }

  /// 401 sau khi interceptor đã thử refresh, 403 vì tài khoản bị khóa, hoặc 404 vì
  /// tài khoản không còn tồn tại.
  bool _isDeadSession(Failure failure) =>
      failure is UnauthorizedFailure ||
      (failure is ServerFailure &&
          (failure.statusCode == 403 || failure.statusCode == 404));
}
