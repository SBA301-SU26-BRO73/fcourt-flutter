import '../../domain/entities/court.dart';
import 'json_readers.dart';

/// Chuyển đổi CourtResponse / CourtRequest của facility-service.
class CourtModel {
  const CourtModel._();

  static Court fromJson(Map<String, dynamic> json) => Court(
    id: json.readInt('id'),
    branchId: json.readInt('branchId'),
    name: json.readString('name'),
    courtTypeId: json.readInt('courtTypeId'),
    description: json.readStringOrNull('description'),
    defaultPricePerHour: json.readMoney('defaultPricePerHour'),
    status: statusFromJson(json['status']),
  );

  static Map<String, dynamic> toJson(CourtDraft draft) {
    final description = draft.description?.trim();
    return {
      'name': draft.name.trim(),
      'courtTypeId': draft.courtTypeId,
      'description': description == null || description.isEmpty
          ? null
          : description,
      'defaultPricePerHour': draft.defaultPricePerHour,
      'status': statusToJson(draft.status),
    };
  }

  static CourtStatus statusFromJson(Object? value) => switch (value) {
    'ACTIVE' => CourtStatus.active,
    'MAINTENANCE' => CourtStatus.maintenance,
    'INACTIVE' => CourtStatus.inactive,
    _ => throw FormatException('Trạng thái sân không hợp lệ', value),
  };

  static String statusToJson(CourtStatus status) => switch (status) {
    CourtStatus.active => 'ACTIVE',
    CourtStatus.maintenance => 'MAINTENANCE',
    CourtStatus.inactive => 'INACTIVE',
  };
}
