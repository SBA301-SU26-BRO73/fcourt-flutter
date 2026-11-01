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

  /// Gửi email đặt lại mật khẩu. BE luôn trả cùng một kết quả dù email có đăng ký hay không.
  Future<void> requestPasswordReset(String email);

  /// Đặt mật khẩu mới bằng token trong email. Ném `Failure` khi token sai, đã dùng hoặc hết hạn.
  /// Mọi phiên đăng nhập của tài khoản bị BE thu hồi.
  Future<void> resetPassword({required String token, required String newPassword});

  /// Đổi mật khẩu khi đang đăng nhập. BE thu hồi mọi phiên và trả cặp token mới; repository lưu
  /// cặp này để thiết bị hiện tại vẫn đăng nhập, các thiết bị khác phải đăng nhập lại.
  Future<AuthUser> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  /// Không bao giờ ném lỗi: token cục bộ luôn bị xóa dù BE không trả lời.
  Future<void> logout();
}
