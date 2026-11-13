import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/failure.dart';
import '../domain/app_notification.dart';

enum NotificationsStatus { loading, loaded, failure }

class NotificationsState extends Equatable {
  const NotificationsState({
    this.status = NotificationsStatus.loading,
    this.items = const [],
    this.total = 0,
    this.loadingMore = false,
    this.error,
  });

  final NotificationsStatus status;
  final List<AppNotification> items;
  final int total;
  final bool loadingMore;
  final String? error;

  bool get hasMore => items.length < total;
  int get unread => items.where((n) => !n.isRead).length;

  NotificationsState copyWith({
    List<AppNotification>? items,
    int? total,
    bool? loadingMore,
    String? error,
  }) => NotificationsState(
    status: status,
    items: items ?? this.items,
    total: total ?? this.total,
    loadingMore: loadingMore ?? this.loadingMore,
    error: error,
  );

  @override
  List<Object?> get props => [status, items, total, loadingMore, error];
}

class NotificationsCubit extends Cubit<NotificationsState> {
  NotificationsCubit(this.repository, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now,
      super(const NotificationsState());

  final NotificationsRepository repository;
  final DateTime Function() _clock;
  static const _pageSize = 20;

  Future<void> load() async {
    emit(const NotificationsState());
    try {
      final page = await repository.page(0, size: _pageSize);
      if (isClosed) return;
      emit(
        NotificationsState(
          status: NotificationsStatus.loaded,
          items: page.items,
          total: page.total,
        ),
      );
    } on Failure catch (e) {
      if (!isClosed) {
        emit(
          NotificationsState(
            status: NotificationsStatus.failure,
            error: e.message,
          ),
        );
      }
    }
  }

  Future<void> loadMore() async {
    if (state.loadingMore || !state.hasMore) return;
    emit(state.copyWith(loadingMore: true));
    try {
      final next = state.items.length ~/ _pageSize;
      final page = await repository.page(next, size: _pageSize);
      if (isClosed) return;
      final known = {for (final n in state.items) n.id};
      emit(
        state.copyWith(
          items: [
            ...state.items,
            for (final n in page.items)
              if (!known.contains(n.id)) n,
          ],
          total: page.total,
          loadingMore: false,
        ),
      );
    } on Failure catch (e) {
      if (!isClosed) emit(state.copyWith(loadingMore: false, error: e.message));
    }
  }

  Future<void> markRead(int id) async {
    if (!state.items.any((n) => n.id == id && !n.isRead)) return;
    try {
      await repository.markRead(id);
      if (isClosed) return;
      final now = _clock();
      emit(
        state.copyWith(
          items: [
            for (final n in state.items) n.id == id ? n.markedRead(now) : n,
          ],
        ),
      );
    } on Failure catch (e) {
      if (!isClosed) emit(state.copyWith(error: e.message));
    }
  }

  Future<void> markAllRead() async {
    if (state.unread == 0) return;
    try {
      await repository.markAllRead();
      if (isClosed) return;
      final now = _clock();
      emit(
        state.copyWith(items: [for (final n in state.items) n.markedRead(now)]),
      );
    } on Failure catch (e) {
      if (!isClosed) emit(state.copyWith(error: e.message));
    }
  }
}
