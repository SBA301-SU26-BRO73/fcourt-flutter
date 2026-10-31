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
  final String? phone;
  final ClockTime openTime;
  final ClockTime closeTime;
  final int slotDurationMinutes;
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
    phone: phone,
    openTime: openTime,
    closeTime: closeTime,
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

/// Dữ liệu người dùng nhập để tạo/cập nhật chi nhánh (BranchRequest).
class BranchDraft extends Equatable {
  const BranchDraft({
    required this.name,
    required this.address,
    this.ward,
    this.district,
    required this.city,
    this.phone,
    required this.openTime,
    required this.closeTime,
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
  final String? phone;
  final ClockTime openTime;
  final ClockTime closeTime;
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
    phone,
    openTime,
    closeTime,
    bankName,
    bankBin,
    bankAccountNumber,
    bankAccountName,
  ];
}
