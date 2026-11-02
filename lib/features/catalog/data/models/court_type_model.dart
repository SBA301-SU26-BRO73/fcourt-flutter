import '../../domain/entities/court_type.dart';
import '../../domain/entities/court_type_input.dart';

class CourtTypeModel {
  const CourtTypeModel({
    required this.id,
    required this.name,
    required this.active,
    this.nameEn,
    this.description,
    this.icon,
    this.color,
  });

  factory CourtTypeModel.fromJson(Map<String, dynamic> json) => CourtTypeModel(
        id: (json['id'] as num).toInt(),
        name: json['name'] as String,
        active: json['active'] as bool? ?? true,
        nameEn: json['nameEn'] as String?,
        description: json['description'] as String?,
        icon: json['icon'] as String?,
        color: json['color'] as String?,
      );

  /// Body của `CourtTypeRequest`; trường rỗng gửi `null` để BE lưu null.
  static Map<String, Object?> requestBody(CourtTypeInput input) => {
        'name': input.name,
        'nameEn': input.nameEn,
        'description': input.description,
        'icon': input.icon,
        'color': input.color,
        'active': input.active,
      };

  final int id;
  final String name;
  final bool active;
  final String? nameEn;
  final String? description;
  final String? icon;
  final String? color;

  CourtType toEntity() => CourtType(
        id: id,
        name: name,
        active: active,
        nameEn: nameEn,
        description: description,
        icon: icon,
        color: color,
      );
}
