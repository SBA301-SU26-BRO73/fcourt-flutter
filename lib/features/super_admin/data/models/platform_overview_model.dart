import '../../domain/entities/platform_overview.dart';

/// Chuyển đổi response `GET /api/super-admin/dashboard/overview`. Thiếu khối hoặc sai
/// kiểu thì báo [FormatException] thay vì hiển thị số 0 giả.
class PlatformOverviewModel {
  const PlatformOverviewModel._();

  static PlatformOverview fromJson(Object? body) {
    final json = _map(body, 'response');
    final owners = _map(json['owners'], 'owners');
    final branches = _map(json['branches'], 'branches');
    final customers = _map(json['customers'], 'customers');
    return PlatformOverview(
      owners: OwnerCounts(
        active: _int(owners, 'active'),
        pending: _int(owners, 'pending'),
        rejected: _int(owners, 'rejected'),
        total: _int(owners, 'total'),
      ),
      branches: BranchCounts(
        total: _int(branches, 'total'),
        active: _int(branches, 'active'),
      ),
      courts: _int(json, 'courts'),
      customers: CustomerCounts(
        total: _int(customers, 'total'),
        active: _int(customers, 'active'),
      ),
      gmv: _int(json, 'gmv'),
      saasRevenue: _int(json, 'saasRevenue'),
      monthly: [
        for (final item in _list(json['monthly'], 'monthly'))
          _monthly(_map(item, 'monthly[]')),
      ],
      topOwners: [
        for (final item in _list(json['topOwners'], 'topOwners'))
          _topOwner(_map(item, 'topOwners[]')),
      ],
    );
  }

  static MonthlyPoint _monthly(Map<String, dynamic> json) {
    final month = json['month'];
    if (month is! String || !RegExp(r'^\d{4}-(0[1-9]|1[0-2])$').hasMatch(month)) {
      throw FormatException('month không hợp lệ', month);
    }
    return MonthlyPoint(
      month: month,
      newAccounts: _int(json, 'newAccounts'),
      gmv: _int(json, 'gmv'),
      saasRevenue: _int(json, 'saasRevenue'),
    );
  }

  static TopOwner _topOwner(Map<String, dynamic> json) {
    final name = json['ownerName'];
    if (name is! String || name.trim().isEmpty) {
      throw FormatException('ownerName không hợp lệ', name);
    }
    return TopOwner(
      ownerId: _int(json, 'ownerId'),
      ownerName: name,
      revenue: _int(json, 'revenue'),
      branches: _int(json, 'branches'),
    );
  }

  static Map<String, dynamic> _map(Object? value, String name) {
    if (value is Map<String, dynamic>) return value;
    throw FormatException('$name phải là đối tượng JSON', value);
  }

  static List<Object?> _list(Object? value, String name) {
    if (value is List) return value;
    throw FormatException('$name phải là mảng', value);
  }

  /// Số tiền VND/đếm: không âm, hữu hạn; số thực được làm tròn về đồng.
  static int _int(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is num && value.isFinite && value >= 0) return value.round();
    throw FormatException('Trường "$key" không hợp lệ', value);
  }
}
