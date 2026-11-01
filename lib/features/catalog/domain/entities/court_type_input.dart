import 'package:equatable/equatable.dart';

/// Dữ liệu form tạo hoặc sửa loại sân. Sửa là thay thế toàn bộ nên luôn gửi đủ các trường.
class CourtTypeInput extends Equatable {
  const CourtTypeInput({
    required this.name,
    this.nameEn,
    this.description,
    this.icon,
    this.color,
    this.active = true,
  });

  final String name;
  final String? nameEn;
  final String? description;
  final String? icon;
  final String? color;
  final bool active;

  @override
  List<Object?> get props => [name, nameEn, description, icon, color, active];
}
