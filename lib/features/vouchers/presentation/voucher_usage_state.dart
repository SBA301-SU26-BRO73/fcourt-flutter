import '../domain/voucher_usage.dart';

class VoucherUsageState {
  const VoucherUsageState({
    this.query = '',
    this.items = const [],
    this.page = -1,
    this.total = 0,
    this.totalDiscountMinor,
    this.loading = true,
    this.loadingMore = false,
    this.hasMore = false,
    this.error,
    this.failedPage,
  });
  final String query;
  final List<VoucherUsage> items;
  final int page, total;
  final int? totalDiscountMinor, failedPage;
  final bool loading, loadingMore, hasMore;
  final String? error;

  VoucherUsageState copyWith({
    List<VoucherUsage>? items,
    int? page,
    int? total,
    int? totalDiscountMinor,
    bool? loading,
    bool? loadingMore,
    bool? hasMore,
    String? error,
    int? failedPage,
  }) => VoucherUsageState(
    query: query,
    items: items ?? this.items,
    page: page ?? this.page,
    total: total ?? this.total,
    totalDiscountMinor: totalDiscountMinor ?? this.totalDiscountMinor,
    loading: loading ?? this.loading,
    loadingMore: loadingMore ?? this.loadingMore,
    hasMore: hasMore ?? this.hasMore,
    error: error,
    failedPage: failedPage,
  );
}
