import 'package:fcourt/features/admin_facility/domain/entities/branch.dart';
import 'package:fcourt/features/admin_facility/domain/entities/clock_time.dart';
import 'package:fcourt/features/admin_facility/domain/entities/court.dart';
import 'package:fcourt/features/admin_facility/domain/entities/court_type.dart';

/// BranchResponse đúng contract facility-service.
Map<String, dynamic> branchJson({
  int id = 1,
  String name = 'FCourt Quận 7',
  int courtCount = 4,
}) => {
  'id': id,
  'adminId': 10,
  'name': name,
  'address': '12 Nguyễn Hữu Thọ',
  'ward': 'Tân Hưng',
  'district': 'Quận 7',
  'city': 'TP. Hồ Chí Minh',
  'latitude': 10.732912,
  'longitude': 106.721133,
  'phone': '0901234567',
  'openTime': '06:00',
  'closeTime': '22:00',
  'slotDurationMinutes': 30,
  'bankName': 'Vietcombank',
  'bankBin': '970436',
  'bankAccountNumber': '0123456789',
  'bankAccountName': 'NGUYEN VAN A',
  'status': 'ACTIVE',
  'courtCount': courtCount,
  'createdAt': '2026-10-01T08:00:00Z',
  'updatedAt': '2026-10-01T08:00:00Z',
};

Branch sampleBranch({int id = 1, String name = 'FCourt Quận 7'}) => Branch(
  id: id,
  name: name,
  address: '12 Nguyễn Hữu Thọ',
  ward: 'Tân Hưng',
  district: 'Quận 7',
  city: 'TP. Hồ Chí Minh',
  latitude: 10.732912,
  longitude: 106.721133,
  phone: '0901234567',
  openTime: const ClockTime(6, 0),
  closeTime: const ClockTime(22, 0),
  bankName: 'Vietcombank',
  bankBin: '970436',
  bankAccountNumber: '0123456789',
  bankAccountName: 'NGUYEN VAN A',
  status: BranchStatus.active,
  courtCount: 4,
);

Map<String, dynamic> courtJson({
  int id = 5,
  int branchId = 1,
  String status = 'ACTIVE',
  Object? price = 120000.0,
}) => {
  'id': id,
  'branchId': branchId,
  'name': 'Sân $id',
  'courtTypeId': 6,
  'description': null,
  'imageUrl': null,
  'defaultPricePerHour': price,
  'status': status,
  'createdAt': '2026-10-01T08:00:00Z',
  'updatedAt': '2026-10-01T08:00:00Z',
};

Court sampleCourt({
  int id = 5,
  int branchId = 1,
  CourtStatus status = CourtStatus.active,
  String? name,
  int? price = 120000,
  String? imageUrl,
}) => Court(
  id: id,
  branchId: branchId,
  name: name ?? 'Sân $id',
  courtTypeId: 6,
  imageUrl: imageUrl,
  defaultPricePerHour: price,
  status: status,
);

const sampleCourtDraft = CourtDraft(
  name: 'Sân 5',
  courtTypeId: 6,
  defaultPricePerHour: 120000,
);

/// Chi nhánh tạo bằng seed SQL V2 (facility_db): không có district, tọa độ,
/// bankBin; JSON đúng như BranchResponse trả về.
Map<String, dynamic> seededBranchJson() => {
  'id': 4,
  'adminId': 4,
  'name': 'Sân Bóng Đá Đống Đa',
  'address': 'Số 101 Đặng Văn Ngữ',
  'ward': 'Trung Tự',
  'district': null,
  'city': 'Hà Nội',
  'latitude': null,
  'longitude': null,
  'phone': '0901234004',
  'openTime': '06:00',
  'closeTime': '22:00',
  'slotDurationMinutes': 30,
  'bankName': 'MB Bank',
  'bankBin': null,
  'bankAccountNumber': '40123456789',
  'bankAccountName': 'NGUYEN VAN FOUR',
  'status': 'ACTIVE',
  'courtCount': 2,
  'createdAt': '2026-10-19T15:13:44.475124Z',
  'updatedAt': '2026-10-19T15:13:44.475124Z',
};

/// Sân seed V2: có ảnh, chưa có giá (`default_price_per_hour` thêm ở V3).
Map<String, dynamic> seededCourtJson({int id = 2, int branchId = 4}) => {
  'id': id,
  'branchId': branchId,
  'name': 'Sân số $id',
  'courtTypeId': 1,
  'description': 'Sân tiêu chuẩn ngoài trời',
  'imageUrl': 'https://images.unsplash.com/photo-1601647998802?w=500',
  'defaultPricePerHour': null,
  'status': 'ACTIVE',
  'createdAt': '2026-10-19T15:13:44.494284Z',
  'updatedAt': '2026-10-19T15:13:44.494284Z',
};

const sampleCourtTypes = [
  CourtType(id: 6, name: 'Cầu lông'),
  CourtType(id: 1, name: 'Pickleball'),
  CourtType(id: 3, name: 'Tennis'),
];
