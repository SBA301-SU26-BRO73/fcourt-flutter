import 'package:equatable/equatable.dart';

import '../../domain/entities/auth_user.dart';

enum SubmissionStatus { idle, submitting, success, failure }

/// Trạng thái dùng chung cho các form gửi lên BE (đăng nhập, đăng ký, sửa profile).
class SubmissionState extends Equatable {
  const SubmissionState({
    this.status = SubmissionStatus.idle,
    this.user,
    this.message,
    this.fieldErrors = const {},
  });

  const SubmissionState.submitting() : this(status: SubmissionStatus.submitting);

  const SubmissionState.success([AuthUser? user])
      : this(status: SubmissionStatus.success, user: user);

  /// [fieldErrors] là lỗi validation của BE theo tên field, hiển thị ngay dưới ô nhập.
  const SubmissionState.failure(
    String message, {
    Map<String, String> fieldErrors = const {},
  }) : this(
          status: SubmissionStatus.failure,
          message: message,
          fieldErrors: fieldErrors,
        );

  final SubmissionStatus status;

  /// Người dùng vừa xác thực hoặc vừa cập nhật; `null` khi đăng ký chủ sân (chờ duyệt).
  final AuthUser? user;
  final String? message;
  final Map<String, String> fieldErrors;

  bool get isSubmitting => status == SubmissionStatus.submitting;

  @override
  List<Object?> get props => [status, user, message, fieldErrors];
}
