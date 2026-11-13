import '../../domain/entities/branch.dart';
import 'json_readers.dart';

/// Chuyển đổi BranchResponse / BranchRequest của facility-service.
///
/// Cột NOT NULL ở DB (`name`, `address`, `city`, giờ mở/đóng, `status`) là bắt
/// buộc; các cột khác có thể `null` với chi nhánh tạo bằng seed SQL
/// (`ward`, `district`, tọa độ, `phone`, toàn bộ thông tin ngân hàng).
class BranchModel {
  const BranchModel._();

  static Branch fromJson(Map<String, dynamic> json) => Branch(
    id: json.readInt('id'),
    name: json.readString('name'),
    address: json.readString('address'),
    ward: json.readStringOrNull('ward'),
    district: json.readStringOrNull('district'),
    city: json.readString('city'),
    latitude: json.readDoubleOrNull('latitude'),
    longitude: json.readDoubleOrNull('longitude'),
    phone: json.readStringOrNull('phone'),
    openTime: json.readTime('openTime'),
    closeTime: json.readTime('closeTime'),
    slotDurationMinutes: json.readIntOrNull('slotDurationMinutes') ?? 30,
    bankName: json.readStringOrNull('bankName') ?? '',
    bankBin: json.readStringOrNull('bankBin') ?? '',
    bankAccountNumber: json.readStringOrNull('bankAccountNumber') ?? '',
    bankAccountName: json.readStringOrNull('bankAccountName') ?? '',
    status: switch (json['status']) {
      'ACTIVE' => BranchStatus.active,
      'INACTIVE' => BranchStatus.inactive,
      final other => throw FormatException('Trạng thái chi nhánh lạ', other),
    },
    courtCount: json.readIntOrNull('courtCount') ?? 0,
  );

  /// Không gửi `status`: backend giữ nguyên trạng thái khi trường này vắng.
  static Map<String, dynamic> toJson(BranchDraft draft) => {
    'name': draft.name.trim(),
    'address': draft.address.trim(),
    'ward': _blankToNull(draft.ward),
    'district': _blankToNull(draft.district),
    'city': draft.city.trim(),
    'latitude': draft.latitude,
    'longitude': draft.longitude,
    'phone': _blankToNull(draft.phone),
    'openTime': draft.openTime.format(),
    'closeTime': draft.closeTime.format(),
    'slotDurationMinutes': draft.slotDurationMinutes,
    'bankName': draft.bankName.trim(),
    'bankBin': draft.bankBin,
    'bankAccountNumber': draft.bankAccountNumber.trim(),
    'bankAccountName': draft.bankAccountName.trim(),
  };

  static String? _blankToNull(String? value) {
    final text = value?.trim();
    return text == null || text.isEmpty ? null : text;
  }
}
