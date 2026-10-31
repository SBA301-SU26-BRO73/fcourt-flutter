import '../../domain/entities/branch.dart';
import 'json_readers.dart';

/// Chuyển đổi BranchResponse / BranchRequest của facility-service.
class BranchModel {
  const BranchModel._();

  static Branch fromJson(Map<String, dynamic> json) => Branch(
    id: json.readInt('id'),
    name: json.readString('name'),
    address: json.readString('address'),
    ward: json.readStringOrNull('ward'),
    district: json.readStringOrNull('district'),
    city: json.readStringOrNull('city') ?? '',
    phone: json.readStringOrNull('phone'),
    openTime: json.readTime('openTime'),
    closeTime: json.readTime('closeTime'),
    slotDurationMinutes: json.readIntOrNull('slotDurationMinutes') ?? 30,
    bankName: json.readStringOrNull('bankName') ?? '',
    bankBin: json.readStringOrNull('bankBin') ?? '',
    bankAccountNumber: json.readStringOrNull('bankAccountNumber') ?? '',
    bankAccountName: json.readStringOrNull('bankAccountName') ?? '',
    status: json['status'] == 'INACTIVE'
        ? BranchStatus.inactive
        : BranchStatus.active,
    courtCount: json.readIntOrNull('courtCount') ?? 0,
  );

  static Map<String, dynamic> toJson(BranchDraft draft) => {
    'name': draft.name.trim(),
    'address': draft.address.trim(),
    'ward': _blankToNull(draft.ward),
    'district': _blankToNull(draft.district),
    'city': draft.city.trim(),
    'phone': _blankToNull(draft.phone),
    'openTime': draft.openTime.format(),
    'closeTime': draft.closeTime.format(),
    'slotDurationMinutes': 30,
    'bankName': draft.bankName,
    'bankBin': draft.bankBin,
    'bankAccountNumber': draft.bankAccountNumber.trim(),
    'bankAccountName': draft.bankAccountName.trim(),
  };

  static String? _blankToNull(String? value) {
    final text = value?.trim();
    return text == null || text.isEmpty ? null : text;
  }
}
