import 'package:equatable/equatable.dart';

import 'clock_time.dart';

enum BranchStatus { active, inactive }

class Branch extends Equatable {
  const Branch({
    required this.id,
    required this.name,
    required this.address,
    this.ward,
    this.district,
    required this.city,
    this.latitude,
    this.longitude,
    this.phone,
    required this.openTime,
    required this.closeTime,
    this.slotDurationMinutes = 30,
    required this.bankName,
    required this.bankBin,
    required this.bankAccountNumber,
    required this.bankAccountName,
    required this.status,
    required this.courtCount,
  });

  final int id;
  final String name;
  final String address;
  final String? ward;
  final String? district;
  final String city;

  /// Tọa độ có thể trống (chi nhánh tạo bằng seed SQL). App chưa cho sửa,
  /// nhưng phải gửi lại khi cập nhật vì PUT thay thế toàn bộ bản ghi.
  final double? latitude;
  final double? longitude;
  final String? phone;
  final ClockTime openTime;
  final ClockTime closeTime;
  final int slotDurationMinutes;

  /// Thông tin VietQR; chuỗi rỗng = chưa thiết lập (seed SQL không có `bankBin`).
  final String bankName;
  final String bankBin;
  final String bankAccountNumber;
  final String bankAccountName;
  final BranchStatus status;
  final int courtCount;

  /// Địa chỉ đầy đủ để hiển thị trên thẻ chi nhánh.
  String get fullAddress => [
    address,
    ward,
    district,
    city,
  ].whereType<String>().where((part) => part.trim().isNotEmpty).join(', ');

  BranchDraft toDraft() => BranchDraft(
    name: name,
    address: address,
    ward: ward,
    district: district,
    city: city,
    latitude: latitude,
    longitude: longitude,
    phone: phone,
    openTime: openTime,
    closeTime: closeTime,
    slotDurationMinutes: slotDurationMinutes,
    bankName: bankName,
    bankBin: bankBin,
    bankAccountNumber: bankAccountNumber,
    bankAccountName: bankAccountName,
  );

  @override
  List<Object?> get props => [
    id,
    name,
    address,
    ward,
    district,
    city,
    latitude,
    longitude,
    phone,
    openTime,
    closeTime,
    slotDurationMinutes,
    bankName,
    bankBin,
    bankAccountNumber,
    bankAccountName,
    status,
    courtCount,
  ];
}

/// Dữ liệu tạo/cập nhật chi nhánh (BranchRequest). Backend thay thế toàn bộ
/// bản ghi khi PUT, nên các trường form không sửa (tọa độ, thời lượng slot)
/// vẫn phải mang giá trị cũ.
class BranchDraft extends Equatable {
  const BranchDraft({
    required this.name,
    required this.address,
    this.ward,
    this.district,
    required this.city,
    this.latitude,
    this.longitude,
    this.phone,
    required this.openTime,
    required this.closeTime,
    this.slotDurationMinutes = 30,
    required this.bankName,
    required this.bankBin,
    required this.bankAccountNumber,
    required this.bankAccountName,
  });

  final String name;
  final String address;
  final String? ward;
  final String? district;
  final String city;
  final double? latitude;
  final double? longitude;
  final String? phone;
  final ClockTime openTime;
  final ClockTime closeTime;
  final int slotDurationMinutes;
  final String bankName;
  final String bankBin;
  final String bankAccountNumber;
  final String bankAccountName;

  @override
  List<Object?> get props => [
    name,
    address,
    ward,
    district,
    city,
    latitude,
    longitude,
    phone,
    openTime,
    closeTime,
    slotDurationMinutes,
    bankName,
    bankBin,
    bankAccountNumber,
    bankAccountName,
  ];
}
