part of 'analytics_bloc.dart';

enum AnalyticsLoadStatus { loading, success, failure }

const _keep = Object();

/// Trạng thái tải của một khối dữ liệu. Khi đang tải lại vẫn giữ [data] cũ để
/// biểu đồ chuyển động mượt sang số liệu mới.
class AnalyticsSection<T> extends Equatable {
  const AnalyticsSection({
    this.status = AnalyticsLoadStatus.loading,
    this.data,
    this.message,
  });

  final AnalyticsLoadStatus status;
  final T? data;
  final String? message;

  AnalyticsSection<T> loading() =>
      AnalyticsSection(status: AnalyticsLoadStatus.loading, data: data);

  AnalyticsSection<T> success(T data) =>
      AnalyticsSection(status: AnalyticsLoadStatus.success, data: data);

  AnalyticsSection<T> failure(String message) => AnalyticsSection(
    status: AnalyticsLoadStatus.failure,
    data: data,
    message: message,
  );

  @override
  List<Object?> get props => [status, data, message];
}

class AnalyticsState extends Equatable {
  const AnalyticsState({
    this.branches = const [],
    this.branchesMessage,
    this.selectedBranchId,
    this.range = RevenueRange.last30Days,
    this.period = AnalyticsPeriod.month,
    this.revenue = const AnalyticsSection(),
    this.insights = const AnalyticsSection(),
  });

  final List<Branch> branches;
  final String? branchesMessage;

  /// `null` = tất cả chi nhánh.
  final int? selectedBranchId;
  final RevenueRange range;
  final AnalyticsPeriod period;
  final AnalyticsSection<RevenueChart> revenue;
  final AnalyticsSection<CourtInsights> insights;

  AnalyticsState copyWith({
    List<Branch>? branches,
    Object? branchesMessage = _keep,
    Object? selectedBranchId = _keep,
    RevenueRange? range,
    AnalyticsPeriod? period,
    AnalyticsSection<RevenueChart>? revenue,
    AnalyticsSection<CourtInsights>? insights,
  }) => AnalyticsState(
    branches: branches ?? this.branches,
    branchesMessage: identical(branchesMessage, _keep)
        ? this.branchesMessage
        : branchesMessage as String?,
    selectedBranchId: identical(selectedBranchId, _keep)
        ? this.selectedBranchId
        : selectedBranchId as int?,
    range: range ?? this.range,
    period: period ?? this.period,
    revenue: revenue ?? this.revenue,
    insights: insights ?? this.insights,
  );

  @override
  List<Object?> get props => [
    branches,
    branchesMessage,
    selectedBranchId,
    range,
    period,
    revenue,
    insights,
  ];
}
