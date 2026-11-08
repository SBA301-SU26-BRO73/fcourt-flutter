import '../../admin_facility/domain/entities/branch.dart';
import '../../admin_facility/domain/entities/court.dart';
import '../domain/admin_booking.dart';
import '../domain/admin_booking_query.dart';

const _keep = Object();

class AdminBookingState {
  const AdminBookingState({
    this.branches = const [],
    this.courts = const [],
    this.query,
    this.items = const [],
    this.page = 0,
    this.total = 0,
    this.hasMore = false,
    this.loading = false,
    this.loadingMore = false,
    this.branchesLoading = true,
    this.courtsLoading = false,
    this.error,
    this.courtsError,
  });
  final List<Branch> branches;
  final List<Court> courts;
  final AdminBookingQuery? query;
  final List<AdminBooking> items;
  final int page, total;
  final bool hasMore, loading, loadingMore, branchesLoading, courtsLoading;
  final String? error, courtsError;

  AdminBookingState copyWith({
    List<Branch>? branches,
    List<Court>? courts,
    AdminBookingQuery? query,
    List<AdminBooking>? items,
    int? page,
    int? total,
    bool? hasMore,
    bool? loading,
    bool? loadingMore,
    bool? branchesLoading,
    bool? courtsLoading,
    Object? error = _keep,
    Object? courtsError = _keep,
  }) => AdminBookingState(
    branches: branches ?? this.branches,
    courts: courts ?? this.courts,
    query: query ?? this.query,
    items: items ?? this.items,
    page: page ?? this.page,
    total: total ?? this.total,
    hasMore: hasMore ?? this.hasMore,
    loading: loading ?? this.loading,
    loadingMore: loadingMore ?? this.loadingMore,
    branchesLoading: branchesLoading ?? this.branchesLoading,
    courtsLoading: courtsLoading ?? this.courtsLoading,
    error: identical(error, _keep) ? this.error : error as String?,
    courtsError: identical(courtsError, _keep)
        ? this.courtsError
        : courtsError as String?,
  );
}
