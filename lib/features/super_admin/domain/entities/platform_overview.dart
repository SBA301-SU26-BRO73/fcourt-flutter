import 'package:equatable/equatable.dart';

class OwnerCounts extends Equatable {
  const OwnerCounts({
    required this.active,
    required this.pending,
    required this.rejected,
    required this.total,
  });

  final int active;
  final int pending;
  final int rejected;
  final int total;

  @override
  List<Object?> get props => [active, pending, rejected, total];
}

class BranchCounts extends Equatable {
  const BranchCounts({required this.total, required this.active});

  final int total;
  final int active;

  @override
  List<Object?> get props => [total, active];
}

class CustomerCounts extends Equatable {
  const CustomerCounts({required this.total, required this.active});

  final int total;
  final int active;

  @override
  List<Object?> get props => [total, active];
}

/// Một tháng trên biểu đồ tăng trưởng. [month] dạng `yyyy-MM`.
class MonthlyPoint extends Equatable {
  const MonthlyPoint({
    required this.month,
    required this.newAccounts,
    required this.gmv,
    required this.saasRevenue,
  });

  final String month;
  final int newAccounts;
  final int gmv;
  final int saasRevenue;

  @override
  List<Object?> get props => [month, newAccounts, gmv, saasRevenue];
}

class TopOwner extends Equatable {
  const TopOwner({
    required this.ownerId,
    required this.ownerName,
    required this.revenue,
    required this.branches,
  });

  final int ownerId;
  final String ownerName;
  final int revenue;
  final int branches;

  @override
  List<Object?> get props => [ownerId, ownerName, revenue, branches];
}

/// Thống kê vĩ mô toàn nền tảng (SCRUM-78). [gmv] là doanh thu đặt sân,
/// [saasRevenue] là doanh thu bán gói SaaS: hai nguồn riêng, không cộng chung.
class PlatformOverview extends Equatable {
  const PlatformOverview({
    required this.owners,
    required this.branches,
    required this.courts,
    required this.customers,
    required this.gmv,
    required this.saasRevenue,
    required this.monthly,
    required this.topOwners,
  });

  final OwnerCounts owners;
  final BranchCounts branches;
  final int courts;
  final CustomerCounts customers;
  final int gmv;
  final int saasRevenue;
  final List<MonthlyPoint> monthly;
  final List<TopOwner> topOwners;

  @override
  List<Object?> get props => [
    owners,
    branches,
    courts,
    customers,
    gmv,
    saasRevenue,
    monthly,
    topOwners,
  ];
}
