import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../../admin_facility/domain/entities/branch.dart';
import '../../../admin_facility/domain/usecases/branch_usecases.dart';
import '../../domain/entities/analytics.dart';
import '../../domain/usecases/analytics_usecases.dart';

part 'analytics_event.dart';
part 'analytics_state.dart';

/// SCRUM-44 / SCRUM-75: biểu đồ doanh thu, tỷ lệ lấp đầy, Top sân và giờ cao
/// điểm. Doanh thu và Top sân/giờ cao điểm tải độc lập: lỗi khối này không che
/// khối kia.
class AnalyticsBloc extends Bloc<AnalyticsEvent, AnalyticsState> {
  AnalyticsBloc({
    required this._getBranches,
    required this._getRevenueChart,
    required this._getInsights,
    DateTime Function()? today,
  }) : _today = today ?? vietnamToday,
       super(const AnalyticsState()) {
    on<AnalyticsStarted>(_onStarted);
    on<AnalyticsBranchChanged>(_onBranchChanged);
    on<AnalyticsRangeChanged>(_onRangeChanged);
    on<AnalyticsPeriodChanged>(_onPeriodChanged);
    on<AnalyticsRefreshed>(_onRefreshed);
  }

  final GetBranches _getBranches;
  final GetRevenueChart _getRevenueChart;
  final GetCourtInsights _getInsights;
  final DateTime Function() _today;

  /// Phản hồi của bộ lọc đã bị đổi đi không được ghi đè số liệu mới.
  int _revenueGeneration = 0;
  int _insightsGeneration = 0;

  /// Ngày hiện tại theo giờ Việt Nam (BE tính theo Asia/Ho_Chi_Minh), không
  /// phụ thuộc múi giờ của thiết bị.
  static DateTime vietnamToday() {
    final now = DateTime.now().toUtc().add(const Duration(hours: 7));
    return DateTime(now.year, now.month, now.day);
  }

  Future<void> _onStarted(
    AnalyticsStarted event,
    Emitter<AnalyticsState> emit,
  ) async {
    await Future.wait([
      _loadBranches(emit),
      _loadRevenue(emit),
      _loadInsights(emit),
    ]);
  }

  Future<void> _onBranchChanged(
    AnalyticsBranchChanged event,
    Emitter<AnalyticsState> emit,
  ) async {
    emit(state.copyWith(selectedBranchId: event.branchId));
    await Future.wait([_loadRevenue(emit), _loadInsights(emit)]);
  }

  Future<void> _onRangeChanged(
    AnalyticsRangeChanged event,
    Emitter<AnalyticsState> emit,
  ) async {
    emit(state.copyWith(range: event.range));
    await _loadRevenue(emit);
  }

  Future<void> _onPeriodChanged(
    AnalyticsPeriodChanged event,
    Emitter<AnalyticsState> emit,
  ) async {
    emit(state.copyWith(period: event.period));
    await _loadInsights(emit);
  }

  Future<void> _onRefreshed(
    AnalyticsRefreshed event,
    Emitter<AnalyticsState> emit,
  ) => Future.wait([_loadRevenue(emit), _loadInsights(emit)]);

  Future<void> _loadBranches(Emitter<AnalyticsState> emit) async {
    try {
      final branches = await _getBranches();
      emit(state.copyWith(branches: branches, branchesMessage: null));
    } on Failure catch (failure) {
      // Không chặn số liệu: vẫn xem được "Tất cả chi nhánh".
      emit(state.copyWith(branchesMessage: failure.message));
    }
  }

  Future<void> _loadRevenue(Emitter<AnalyticsState> emit) async {
    final generation = ++_revenueGeneration;
    final today = _today();
    emit(state.copyWith(revenue: state.revenue.loading()));
    try {
      final chart = await _getRevenueChart(
        branchId: state.selectedBranchId,
        from: state.range.from(today),
        to: today,
        granularity: state.range.granularity,
      );
      if (generation != _revenueGeneration) return;
      emit(state.copyWith(revenue: state.revenue.success(chart)));
    } on Failure catch (failure) {
      if (generation != _revenueGeneration) return;
      emit(state.copyWith(revenue: state.revenue.failure(failure.message)));
    }
  }

  Future<void> _loadInsights(Emitter<AnalyticsState> emit) async {
    final generation = ++_insightsGeneration;
    emit(state.copyWith(insights: state.insights.loading()));
    try {
      final insights = await _getInsights(
        branchId: state.selectedBranchId,
        period: state.period,
        date: _today(),
      );
      if (generation != _insightsGeneration) return;
      emit(state.copyWith(insights: state.insights.success(insights)));
    } on Failure catch (failure) {
      if (generation != _insightsGeneration) return;
      emit(state.copyWith(insights: state.insights.failure(failure.message)));
    }
  }
}
