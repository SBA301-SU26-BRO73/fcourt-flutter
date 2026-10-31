part of 'court_list_bloc.dart';

sealed class CourtListEvent extends Equatable {
  const CourtListEvent();

  @override
  List<Object?> get props => [];
}

/// Tải danh sách chi nhánh (cho bộ lọc), loại sân và sân của [branchId].
class CourtListStarted extends CourtListEvent {
  const CourtListStarted(this.branchId);

  final int branchId;

  @override
  List<Object?> get props => [branchId];
}

class CourtBranchSelected extends CourtListEvent {
  const CourtBranchSelected(this.branchId);

  final int branchId;

  @override
  List<Object?> get props => [branchId];
}

class CourtMaintenanceToggled extends CourtListEvent {
  const CourtMaintenanceToggled(this.courtId, {required this.maintenance});

  final int courtId;
  final bool maintenance;

  @override
  List<Object?> get props => [courtId, maintenance];
}

/// Màn hình form trả về sân vừa tạo/sửa: cập nhật lưới ngay, không gọi lại API.
class CourtSaved extends CourtListEvent {
  const CourtSaved(this.court);

  final Court court;

  @override
  List<Object?> get props => [court];
}
