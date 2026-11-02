import 'package:equatable/equatable.dart';

/// Loại sân (cầu lông, bóng đá mini...) do super admin quản lý, dùng khi chủ sân tạo sân.
class CourtType extends Equatable {
  const CourtType({
    required this.id,
    required this.name,
    required this.active,
    this.nameEn,
    this.description,
    this.icon,
    this.color,
  });

  final int id;
  final String name;
  final bool active;
  final String? nameEn;
  final String? description;
  final String? icon;
  final String? color;

  @override
  List<Object?> get props => [id, name, active, nameEn, description, icon, color];
}
