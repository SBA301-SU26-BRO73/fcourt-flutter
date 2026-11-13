import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../../admin_facility/domain/entities/branch.dart';
import '../../../admin_facility/domain/usecases/branch_usecases.dart';
import '../../domain/entities/analytics.dart';
import '../../domain/entities/dashboard_stats.dart';
import '../../domain/usecases/analytics_usecases.dart';
import '../../domain/usecases/get_dashboard_stats.dart';

part 'dashboard_event.dart';
part 'dashboard_state.dart';

/// SCRUM-13: thống kê tổng quan. Danh sách chi nhánh cho dropdown lấy từ
/// facility-service qua use case của feature `admin_facility`.
class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  DashboardBloc({
    required this._getBranches,
    required this._getStats,
    this._getRevenueChart,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now,
       super(const DashboardState()) {
    on<DashboardStarted>(_onStarted);
    on<DashboardBranchChanged>(_onBranchChanged);
    on<DashboardRefreshed>(_onRefreshed);
  }

  final GetBranches _getBranches;
  final GetDashboardStats _getStats;

  /// Tuỳ chọn: có thì tải thêm doanh thu 7 ngày gần nhất cho biểu đồ cột.
  final GetRevenueChart? _getRevenueChart;
  final DateTime Function() _clock;

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
      final results = await Future.wait([
        _getStats(branchId: branchId),
        _loadWeek(branchId),
      ]);
      if (generation != _generation) return;
      emit(
        state.copyWith(
          status: DashboardStatus.success,
          stats: results[0] as DashboardStats,
          weekRevenue: results[1],
          updatedAt: _clock(),
        ),
      );
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

  /// Doanh thu 7 ngày; lỗi của biểu đồ không làm hỏng cả màn tổng quan.
  Future<RevenueChart?> _loadWeek(int? branchId) async {
    final load = _getRevenueChart;
    if (load == null) return null;
    final today = _clock();
    final to = DateTime(today.year, today.month, today.day);
    try {
      return await load(
        branchId: branchId,
        from: to.subtract(const Duration(days: 6)),
        to: to,
        granularity: RevenueGranularity.day,
      );
    } on Failure {
      return null;
    }
  }
}
