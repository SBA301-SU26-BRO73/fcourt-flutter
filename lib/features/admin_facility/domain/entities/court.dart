import 'package:equatable/equatable.dart';

enum CourtStatus { active, maintenance, inactive }

class Court extends Equatable {
  const Court({
    required this.id,
    required this.branchId,
    required this.name,
    required this.courtTypeId,
    this.description,
    required this.defaultPricePerHour,
    required this.status,
  });

  final int id;
  final int branchId;
  final String name;
  final int courtTypeId;
  final String? description;

  /// Giá mặc định mỗi giờ (VND).
  final int defaultPricePerHour;
  final CourtStatus status;

  CourtDraft toDraft() => CourtDraft(
    name: name,
    courtTypeId: courtTypeId,
    description: description,
    defaultPricePerHour: defaultPricePerHour,
    status: status,
  );

  @override
  List<Object?> get props => [
    id,
    branchId,
    name,
    courtTypeId,
    description,
    defaultPricePerHour,
    status,
  ];
}

/// Dữ liệu tạo/cập nhật sân (CourtRequest).
class CourtDraft extends Equatable {
  const CourtDraft({
    required this.name,
    required this.courtTypeId,
    this.description,
    required this.defaultPricePerHour,
    this.status = CourtStatus.active,
  });

  final String name;
  final int courtTypeId;
  final String? description;
  final int defaultPricePerHour;
  final CourtStatus status;

  @override
  List<Object?> get props => [
    name,
    courtTypeId,
    description,
    defaultPricePerHour,
    status,
  ];
}
