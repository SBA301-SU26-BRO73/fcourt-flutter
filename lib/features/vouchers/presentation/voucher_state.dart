import '../../admin_facility/domain/entities/branch.dart';
import '../domain/voucher.dart';

class VoucherState {
  const VoucherState({
    this.branches = const [],
    this.branchId,
    this.items = const [],
    this.page = 0,
    this.total = 0,
    this.hasMore = false,
    this.loading = true,
    this.loadingMore = false,
    this.busyIds = const {},
    this.error,
  });
  final List<Branch> branches;
  final int? branchId;
  final List<Voucher> items;
  final int page, total;
  final bool hasMore, loading, loadingMore;
  final Set<int> busyIds;
  final String? error;

  VoucherState copyWith({
    List<Branch>? branches,
    int? branchId,
    List<Voucher>? items,
    int? page,
    int? total,
    bool? hasMore,
    bool? loading,
    bool? loadingMore,
    Set<int>? busyIds,
    String? error,
  }) => VoucherState(
    branches: branches ?? this.branches,
    branchId: branchId ?? this.branchId,
    items: items ?? this.items,
    page: page ?? this.page,
    total: total ?? this.total,
    hasMore: hasMore ?? this.hasMore,
    loading: loading ?? this.loading,
    loadingMore: loadingMore ?? this.loadingMore,
    busyIds: busyIds ?? this.busyIds,
    error: error,
  );
}
