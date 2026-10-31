import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../../admin_facility/domain/entities/branch.dart';
import '../../../admin_facility/domain/usecases/branch_usecases.dart';
import '../../domain/entities/dashboard_stats.dart';
import '../../domain/usecases/get_dashboard_stats.dart';

part 'dashboard_event.dart';
part 'dashboard_state.dart';

/// SCRUM-13: thống kê tổng quan. Danh sách chi nhánh cho dropdown lấy từ
/// facility-service qua use case của feature `admin_facility`.
class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  DashboardBloc({required this._getBranches, required this._getStats})
    : super(const DashboardState()) {
    on<DashboardStarted>(_onStarted);
    on<DashboardBranchChanged>(_onBranchChanged);
    on<DashboardRefreshed>(_onRefreshed);
  }

  final GetBranches _getBranches;
  final GetDashboardStats _getStats;

  /// Phản hồi của chi nhánh đã bị đổi đi trước đó không được ghi đè số liệu mới.
  int _generation = 0;

  Future<void> _onStarted(
    DashboardStarted event,
    Emitter<DashboardState> emit,
  ) async {
    await Future.wait([
      _loadBranches(emit),
      _loadStats(emit, state.selectedBranchId),
    ]);
  }

  Future<void> _onBranchChanged(
    DashboardBranchChanged event,
    Emitter<DashboardState> emit,
  ) async {
    if (event.branchId == state.selectedBranchId &&
        state.status == DashboardStatus.success) {
      return;
    }
    await _loadStats(emit, event.branchId);
  }

  Future<void> _onRefreshed(
    DashboardRefreshed event,
    Emitter<DashboardState> emit,
  ) => _loadStats(emit, state.selectedBranchId);

  Future<void> _loadBranches(Emitter<DashboardState> emit) async {
    try {
      final branches = await _getBranches();
      emit(state.copyWith(branches: branches, branchesMessage: null));
    } on Failure catch (failure) {
      // Không chặn số liệu tổng: vẫn xem được "Tất cả chi nhánh".
      emit(state.copyWith(branchesMessage: failure.message));
    }
  }

  Future<void> _loadStats(Emitter<DashboardState> emit, int? branchId) async {
    final generation = ++_generation;
    emit(
      state.copyWith(
        status: DashboardStatus.loading,
        selectedBranchId: branchId,
        message: null,
      ),
    );
    try {
      final stats = await _getStats(branchId: branchId);
      if (generation != _generation) return;
      emit(state.copyWith(status: DashboardStatus.success, stats: stats));
    } on Failure catch (failure) {
      if (generation != _generation) return;
      emit(
        state.copyWith(
          status: DashboardStatus.failure,
          message: failure.message,
        ),
      );
    }
  }
}
