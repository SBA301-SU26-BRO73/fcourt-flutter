part of 'analytics_bloc.dart';

sealed class AnalyticsEvent extends Equatable {
  const AnalyticsEvent();

  @override
  List<Object?> get props => [];
}

/// Tải danh sách chi nhánh, doanh thu và top sân/giờ cao điểm.
class AnalyticsStarted extends AnalyticsEvent {
  const AnalyticsStarted();
}

/// [branchId] `null` = tất cả chi nhánh.
class AnalyticsBranchChanged extends AnalyticsEvent {
  const AnalyticsBranchChanged(this.branchId);

  final int? branchId;

  @override
  List<Object?> get props => [branchId];
}

class AnalyticsRangeChanged extends AnalyticsEvent {
  const AnalyticsRangeChanged(this.range);

  final RevenueRange range;

  @override
  List<Object?> get props => [range];
}

class AnalyticsPeriodChanged extends AnalyticsEvent {
  const AnalyticsPeriodChanged(this.period);

  final AnalyticsPeriod period;

  @override
  List<Object?> get props => [period];
}

class AnalyticsRefreshed extends AnalyticsEvent {
  const AnalyticsRefreshed();
}
