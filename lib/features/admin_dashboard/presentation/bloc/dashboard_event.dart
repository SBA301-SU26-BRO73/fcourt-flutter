part of 'dashboard_bloc.dart';

sealed class DashboardEvent extends Equatable {
  const DashboardEvent();

  @override
  List<Object?> get props => [];
}

/// Tải danh sách chi nhánh và số liệu gộp của tất cả chi nhánh.
class DashboardStarted extends DashboardEvent {
  const DashboardStarted();
}

/// [branchId] `null` = tất cả chi nhánh.
class DashboardBranchChanged extends DashboardEvent {
  const DashboardBranchChanged(this.branchId);

  final int? branchId;

  @override
  List<Object?> get props => [branchId];
}

class DashboardRefreshed extends DashboardEvent {
  const DashboardRefreshed();
}
