import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../domain/discovery_repository.dart';

class DiscoveryState {
  const DiscoveryState({
    this.query = '',
    this.sport,
    this.branches = const [],
    this.loading = true,
    this.loadingMore = false,
    this.page = -1,
    this.hasNext = false,
    this.total = 0,
    this.error,
  });
  final String query;
  final DiscoverySport? sport;
  final List<Branch> branches;
  final bool loading, loadingMore, hasNext;
  final int page, total;
  final String? error;
}

class DiscoveryCubit extends Cubit<DiscoveryState> {
  DiscoveryCubit(this.repository, {String query = '', DiscoverySport? sport})
    : super(DiscoveryState(query: query, sport: sport));
  final DiscoveryRepository repository;
  Timer? _debounce;
  int _revision = 0;

  void search(String query) {
    _debounce?.cancel();
    _revision++;
    emit(DiscoveryState(query: query, sport: state.sport));
    _debounce = Timer(const Duration(milliseconds: 300), refresh);
  }

  void filter(DiscoverySport? sport) {
    _debounce?.cancel();
    emit(DiscoveryState(query: state.query, sport: sport));
    refresh();
  }

  Future<void> refresh() {
    _debounce?.cancel();
    final revision = ++_revision;
    emit(DiscoveryState(query: state.query, sport: state.sport));
    return _load(revision, 0);
  }

  Future<void> loadMore() async {
    if (state.loading || state.loadingMore || !state.hasNext) return;
    emit(
      DiscoveryState(
        query: state.query,
        sport: state.sport,
        branches: state.branches,
        page: state.page,
        total: state.total,
        hasNext: true,
        loading: false,
        loadingMore: true,
      ),
    );
    await _load(_revision, state.page + 1);
  }

  Future<void> _load(int revision, int page) async {
    final previous = state;
    try {
      final result = await repository.search(
        query: previous.query,
        sport: previous.sport,
        page: page,
      );
      if (isClosed || revision != _revision) return;
      final items = <int, Branch>{
        if (page > 0)
          for (final branch in previous.branches) branch.id: branch,
        for (final branch in result.branches) branch.id: branch,
      };
      emit(
        DiscoveryState(
          query: previous.query,
          sport: previous.sport,
          branches: List.unmodifiable(items.values),
          loading: false,
          page: result.page,
          hasNext: result.hasNext,
          total: result.totalElements,
        ),
      );
    } catch (error) {
      if (isClosed || revision != _revision) return;
      emit(
        DiscoveryState(
          query: previous.query,
          sport: previous.sport,
          branches: previous.branches,
          loading: false,
          page: previous.page,
          hasNext: previous.hasNext,
          total: previous.total,
          error: error is Failure
              ? error.message
              : 'Không thể tải danh sách sân.',
        ),
      );
    }
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    _revision++;
    return super.close();
  }
}
