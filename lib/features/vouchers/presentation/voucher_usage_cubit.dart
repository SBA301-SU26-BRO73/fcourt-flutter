import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/failure.dart';
import '../domain/voucher_usage.dart';
import '../domain/voucher_usage_repository.dart';
import 'voucher_usage_state.dart';

class VoucherUsageCubit extends Cubit<VoucherUsageState> {
  VoucherUsageCubit(this.repository, this.voucherId)
    : super(const VoucherUsageState());
  final VoucherUsageRepository repository;
  final int voucherId;
  Timer? _debounce;
  int _revision = 0;

  void search(String query) {
    _debounce?.cancel();
    _revision++;
    emit(
      VoucherUsageState(
        query: query,
        totalDiscountMinor: state.totalDiscountMinor,
      ),
    );
    _debounce = Timer(const Duration(milliseconds: 300), refresh);
  }

  Future<void> refresh() async {
    _debounce?.cancel();
    final revision = ++_revision;
    emit(state.copyWith(loading: true, loadingMore: false));
    await _load(revision, 0);
  }

  Future<void> loadMore() async {
    if (state.loading || state.loadingMore || !state.hasMore) return;
    emit(state.copyWith(loadingMore: true));
    await _load(_revision, state.page + 1);
  }

  Future<void> retry() => state.failedPage == 0 ? refresh() : loadMore();

  Future<void> _load(int revision, int page) async {
    final query = state.query;
    try {
      final result = await repository.list(
        voucherId,
        page: page,
        search: query,
      );
      if (isClosed || revision != _revision) return;
      final rows = <String, VoucherUsage>{
        if (page > 0)
          for (final row in state.items) row.id: row,
        for (final row in result.items) row.id: row,
      };
      emit(
        state.copyWith(
          items: List.unmodifiable(rows.values),
          page: result.page,
          total: result.total,
          totalDiscountMinor: result.totalDiscountMinor,
          hasMore: result.hasMore,
          loading: false,
          loadingMore: false,
        ),
      );
    } catch (error) {
      if (isClosed || revision != _revision) return;
      final message = error is Failure
          ? error.message
          : 'Không tải được lịch sử voucher. Vui lòng thử lại.';
      final forbidden =
          error is UnauthorizedFailure ||
          (error is ServerFailure && {403, 404}.contains(error.statusCode));
      emit(
        forbidden
            ? VoucherUsageState(
                query: query,
                loading: false,
                error: message,
                failedPage: 0,
              )
            : state.copyWith(
                loading: false,
                loadingMore: false,
                error: message,
                failedPage: page,
              ),
      );
    }
  }

  @override
  Future<void> close() {
    _revision++;
    _debounce?.cancel();
    return super.close();
  }
}
