import '../entities/auth_user.dart';
import '../entities/upload_document.dart';

abstract class AuthRepository {
  /// Khôi phục phiên từ token đã lưu. Trả `null` khi chưa đăng nhập hoặc phiên hết hạn.
  /// Ném `Failure` khi không hỏi được máy chủ (ví dụ mất mạng), token vẫn được giữ.
  Future<AuthUser?> restoreSession();

  /// Ném `Failure` khi sai thông tin hoặc tài khoản chưa được phép đăng nhập.
  Future<AuthUser> login({required String email, required String password});

  /// Đăng ký khách hàng, đăng nhập luôn.
  Future<AuthUser> registerCustomer({
    required String fullName,
    required String email,
    required String phone,
    required String password,
  });

  /// Đăng ký chủ sân: chưa đăng nhập được cho tới khi super admin duyệt.
  Future<void> registerCourtOwner({
    required String fullName,
    required String email,
    required String phone,
    required String password,
    required List<UploadDocument> legalDocuments,
    List<UploadDocument> courtImages = const [],
  });

  Future<AuthUser> updateProfile({
    required String fullName,
    required String phone,
  });

  /// Không bao giờ ném lỗi: token cục bộ luôn bị xóa dù BE không trả lời.
  Future<void> logout();
}
