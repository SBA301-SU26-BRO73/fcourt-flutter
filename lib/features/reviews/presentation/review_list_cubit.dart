import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/failure.dart';
import '../domain/review.dart';

class ReviewListState {
  const ReviewListState({
    this.items = const [],
    this.summary,
    this.page = -1,
    this.loading = true,
    this.moreLoading = false,
    this.error,
  });
  final List<CourtReview> items;
  final ReviewPage? summary;
  final int page;
  final bool loading, moreLoading;
  final String? error;
  bool get hasMore =>
      summary != null && (page + 1) * ReviewPage.size < summary!.total;
}

class ReviewListCubit extends Cubit<ReviewListState> {
  ReviewListCubit(this.repository, this.branchId)
    : super(const ReviewListState()) {
    _subscription = repository.changes.listen((id) {
      if (id == branchId) refresh();
    });
  }
  final ReviewRepository repository;
  final int branchId;
  late final StreamSubscription<int> _subscription;
  int _revision = 0;
  Future<void> refresh() async {
    final revision = ++_revision;
    emit(const ReviewListState());
    await _load(revision, 0);
  }

  Future<void> more() async {
    if (state.loading || state.moreLoading || !state.hasMore) return;
    emit(
      ReviewListState(
        items: state.items,
        summary: state.summary,
        page: state.page,
        loading: false,
        moreLoading: true,
      ),
    );
    await _load(_revision, state.page + 1);
  }

  Future<void> retry() => state.items.isEmpty ? refresh() : more();
  Future<void> _load(int revision, int page) async {
    try {
      final result = await repository.list(branchId, page: page);
      if (isClosed || revision != _revision) return;
      final rows = <int, CourtReview>{
        if (page > 0)
          for (final row in state.items) row.id: row,
        for (final row in result.items) row.id: row,
      };
      emit(
        ReviewListState(
          items: List.unmodifiable(rows.values),
          summary: result,
          page: page,
          loading: false,
        ),
      );
    } catch (error) {
      if (isClosed || revision != _revision) return;
      final revoked =
          error is ServerFailure && {403, 404}.contains(error.statusCode);
      emit(
        ReviewListState(
          items: revoked ? const [] : state.items,
          summary: revoked ? null : state.summary,
          page: revoked ? -1 : state.page,
          loading: false,
          error: error is Failure
              ? error.message
              : 'Không tải được đánh giá. Vui lòng thử lại.',
        ),
      );
    }
  }

  @override
  Future<void> close() async {
    _revision++;
    await _subscription.cancel();
    await super.close();
  }
}
