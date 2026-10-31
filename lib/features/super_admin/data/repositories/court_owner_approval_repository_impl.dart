import 'package:dio/dio.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/court_owner.dart';
import '../../domain/repositories/court_owner_approval_repository.dart';
import '../datasources/super_admin_remote_data_source.dart';
import '../models/court_owner_model.dart';

class CourtOwnerApprovalRepositoryImpl implements CourtOwnerApprovalRepository {
  const CourtOwnerApprovalRepositoryImpl(this._remote);

  final SuperAdminRemoteDataSource _remote;

  static const invalidDataMessage = 'Dữ liệu hồ sơ từ máy chủ không hợp lệ';
  static const unverifiedMessage =
      'Chưa xác minh được kết quả. Vui lòng tải lại danh sách.';

  @override
  Future<List<CourtOwner>> pendingOwners() => _guard(() async {
    final body = await _remote.pendingOwners();
    if (body is! List) {
      throw const FormatException('Danh sách hồ sơ không phải mảng');
    }
    // Endpoint đã lọc PENDING_APPROVAL; lọc lại để màn hình chỉ hiển thị đúng
    // hồ sơ chờ duyệt kể cả khi backend trả lẫn trạng thái khác.
    return body
        .map(CourtOwnerModel.fromJson)
        .where((owner) => owner.isPending)
        .toList();
  });

  @override
  Future<CourtOwner> ownerDetail(int ownerId) => _guard(() async {
    final owner = CourtOwnerModel.fromJson(await _remote.ownerDetail(ownerId));
    if (owner.id != ownerId) {
      throw const FormatException('id trong response không khớp');
    }
    return owner;
  });

  @override
  Future<CourtOwner> approve(int ownerId, {String? reason}) => _decision(
    ownerId,
    OwnerStatus.active,
    () => _remote.approve(ownerId, reason: reason),
  );

  @override
  Future<CourtOwner> reject(int ownerId, String reason) => _decision(
    ownerId,
    OwnerStatus.rejected,
    () => _remote.reject(ownerId, reason),
  );

  Future<CourtOwner> _decision(
    int ownerId,
    OwnerStatus expected,
    Future<Object?> Function() send,
  ) async {
    final owner = await _guard(
      () async => CourtOwnerModel.fromJson(await send()),
    );
    if (owner.id != ownerId || owner.status != expected) {
      throw const UnknownFailure(unverifiedMessage);
    }
    return owner;
  }

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on DioException catch (e) {
      throw ownerApprovalFailure(e);
    } on FormatException {
      throw const UnknownFailure(invalidDataMessage);
    }
  }
}

/// Đổi lỗi HTTP (RFC 7807 ProblemDetail, `detail` là message an toàn) thành
/// [Failure] với thông điệp tiếng Việt cho màn hình duyệt hồ sơ.
Failure ownerApprovalFailure(DioException e) {
  final status = e.response?.statusCode;
  final body = e.response?.data;
  final detail = body is Map && body['detail'] is String
      ? (body['detail'] as String).trim()
      : '';
  return switch (status) {
    401 => const UnauthorizedFailure(),
    403 => const ServerFailure(
      'Tài khoản không có quyền SuperAdmin',
      statusCode: 403,
    ),
    404 => const ServerFailure('Không tìm thấy hồ sơ chủ sân', statusCode: 404),
    409 => const ServerFailure(
      'Hồ sơ đã được xử lý. Vui lòng tải lại danh sách.',
      statusCode: 409,
    ),
    400 => ServerFailure(
      detail.isEmpty ? 'Thông tin duyệt chưa hợp lệ' : detail,
      statusCode: 400,
    ),
    _ => failureFromDio(e),
  };
}
