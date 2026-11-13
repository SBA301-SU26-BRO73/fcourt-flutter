part of 'dashboard_bloc.dart';

enum DashboardStatus { loading, success, failure }

const _keep = Object();

class DashboardState extends Equatable {
  const DashboardState({
    this.status = DashboardStatus.loading,
    this.branches = const [],
    this.branchesMessage,
    this.selectedBranchId,
    this.stats,
    this.weekRevenue,
    this.updatedAt,
    this.message,
  });

  final DashboardStatus status;
  final List<Branch> branches;

  /// Lỗi tải danh sách chi nhánh (dropdown chỉ còn "Tất cả chi nhánh").
  final String? branchesMessage;

  /// `null` = tất cả chi nhánh.
  final int? selectedBranchId;
  final DashboardStats? stats;

  /// Doanh thu theo ngày của 7 ngày gần nhất; null khi chưa có hoặc lỗi.
  final RevenueChart? weekRevenue;

  /// Lúc số liệu được tải xong (hiện ở chân biểu đồ).
  final DateTime? updatedAt;
  final String? message;

  DashboardState copyWith({
    DashboardStatus? status,
    List<Branch>? branches,
    Object? branchesMessage = _keep,
    Object? selectedBranchId = _keep,
    DashboardStats? stats,
    Object? weekRevenue = _keep,
    DateTime? updatedAt,
    Object? message = _keep,
  }) => DashboardState(
    status: status ?? this.status,
    branches: branches ?? this.branches,
    branchesMessage: identical(branchesMessage, _keep)
        ? this.branchesMessage
        : branchesMessage as String?,
    selectedBranchId: identical(selectedBranchId, _keep)
        ? this.selectedBranchId
        : selectedBranchId as int?,
    stats: stats ?? this.stats,
    weekRevenue: identical(weekRevenue, _keep)
        ? this.weekRevenue
        : weekRevenue as RevenueChart?,
    updatedAt: updatedAt ?? this.updatedAt,
    message: identical(message, _keep) ? this.message : message as String?,
  );

  @override
  List<Object?> get props => [
    status,
    branches,
    branchesMessage,
    selectedBranchId,
    stats,
    weekRevenue,
    updatedAt,
    message,
  ];
}
