import 'package:equatable/equatable.dart';

enum CourtStatus { active, maintenance, inactive }

class Court extends Equatable {
  const Court({
    required this.id,
    required this.branchId,
    required this.name,
    required this.courtTypeId,
    this.description,
    this.imageUrl,
    this.defaultPricePerHour,
    required this.status,
  });

  final int id;
  final int branchId;
  final String name;
  final int courtTypeId;
  final String? description;

  /// Ảnh sân; app chưa cho sửa nhưng phải gửi lại khi PUT (thay toàn bộ).
  final String? imageUrl;

  /// Giá mặc định mỗi giờ (VND). `null` với sân tạo bằng seed SQL (cột được
  /// thêm sau ở V3); chủ sân phải đặt giá khi sửa sân.
  final int? defaultPricePerHour;
  final CourtStatus status;

  @override
  List<Object?> get props => [
    id,
    branchId,
    name,
    courtTypeId,
    description,
    imageUrl,
    defaultPricePerHour,
    status,
  ];
}

/// Dữ liệu tạo/cập nhật sân (CourtRequest). Backend bắt buộc giá > 0.
class CourtDraft extends Equatable {
  const CourtDraft({
    required this.name,
    required this.courtTypeId,
    this.description,
    this.imageUrl,
    required this.defaultPricePerHour,
    this.status = CourtStatus.active,
  });

  final String name;
  final int courtTypeId;
  final String? description;
  final String? imageUrl;
  final int defaultPricePerHour;
  final CourtStatus status;

  @override
  List<Object?> get props => [
    name,
    courtTypeId,
    description,
    imageUrl,
    defaultPricePerHour,
    status,
  ];
}
