import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/page_result.dart';

sealed class CatalogListEvent extends Equatable {
  const CatalogListEvent();

  @override
  List<Object?> get props => [];
}

/// Tải lại từ trang đầu (mở màn hình, kéo để làm mới, sau khi lưu).
class CatalogRefreshed extends CatalogListEvent {
  const CatalogRefreshed();
}

class CatalogMoreRequested extends CatalogListEvent {
  const CatalogMoreRequested();
}

class CatalogItemDeleted extends CatalogListEvent {
  const CatalogItemDeleted(this.id);

  final int id;

  @override
  List<Object?> get props => [id];
}

enum CatalogListStatus { loading, ready, failure }

/// Thông báo ngắn sau một thao tác (xóa xong, xóa lỗi, tải thêm lỗi). [sequence] tăng mỗi lần
/// để hai thông báo giống hệt nhau liên tiếp vẫn được giao diện hiển thị.
class CatalogNotice extends Equatable {
  const CatalogNotice(this.message, {required this.isError, required this.sequence});

  final String message;
  final bool isError;
  final int sequence;

  @override
  List<Object?> get props => [message, isError, sequence];
}

class CatalogListState<T> extends Equatable {
  const CatalogListState({
    this.status = CatalogListStatus.loading,
    this.items = const [],
    this.page = 0,
    this.hasMore = false,
    this.loadingMore = false,
    this.refreshing = false,
    this.deletingId,
    this.message,
    this.notice,
  });

  final CatalogListStatus status;
  final List<T> items;

  /// Trang cuối đã tải (bắt đầu từ 0).
  final int page;
  final bool hasMore;
  final bool loadingMore;

  /// Đang tải lại trong khi vẫn hiện danh sách cũ (kéo để làm mới).
  final bool refreshing;

  /// Mục đang được xóa, để khóa nút xóa của mục đó.
  final int? deletingId;

  /// Lý do khi [status] là [CatalogListStatus.failure].
  final String? message;
  final CatalogNotice? notice;

  CatalogListState<T> copyWith({
    CatalogListStatus? status,
    List<T>? items,
    int? page,
    bool? hasMore,
    bool? loadingMore,
    bool? refreshing,
    int? Function()? deletingId,
    String? message,
    CatalogNotice? notice,
  }) =>
      CatalogListState<T>(
        status: status ?? this.status,
        items: items ?? this.items,
        page: page ?? this.page,
        hasMore: hasMore ?? this.hasMore,
        loadingMore: loadingMore ?? this.loadingMore,
        refreshing: refreshing ?? this.refreshing,
        deletingId: deletingId == null ? this.deletingId : deletingId(),
        message: message ?? this.message,
        notice: notice ?? this.notice,
      );

  @override
  List<Object?> get props =>
      [status, items, page, hasMore, loadingMore, refreshing, deletingId, message, notice];
}

/// Danh sách phân trang có xóa, dùng chung cho loại sân và gói dịch vụ.
class CatalogListBloc<T> extends Bloc<CatalogListEvent, CatalogListState<T>> {
  CatalogListBloc({
    required this.load,
    required this.delete,
    required this.idOf,
    required this.deletedMessage,
  }) : super(CatalogListState<T>()) {
    on<CatalogRefreshed>(_onRefreshed);
    on<CatalogMoreRequested>(_onMoreRequested);
    on<CatalogItemDeleted>(_onItemDeleted);
  }

  final Future<PageResult<T>> Function(int page) load;
  final Future<void> Function(int id) delete;
  final int Function(T item) idOf;
  final String deletedMessage;
  int _noticeSequence = 0;

  /// Tăng mỗi lần làm mới. Kết quả tải thêm của lượt trước về muộn sẽ bị bỏ, nếu không sẽ
  /// nối trang cũ vào danh sách mới (trùng mục, sai số trang).
  int _generation = 0;

  CatalogNotice _notice(String message, {required bool isError}) =>
      CatalogNotice(message, isError: isError, sequence: ++_noticeSequence);

  Future<void> _onRefreshed(
    CatalogRefreshed event,
    Emitter<CatalogListState<T>> emit,
  ) async {
    final generation = ++_generation;
    // Làm mới khi đã có dữ liệu thì giữ danh sách cũ trên màn hình cho tới khi có kết quả.
    if (state.items.isEmpty) {
      emit(CatalogListState<T>());
    } else {
      emit(state.copyWith(refreshing: true));
    }
    try {
      final result = await load(0);
      if (generation != _generation) return;
      emit(
        CatalogListState<T>(
          status: CatalogListStatus.ready,
          items: result.items,
          page: result.page,
          hasMore: result.hasMore,
        ),
      );
    } on Failure catch (failure) {
      if (generation != _generation) return;
      if (state.items.isEmpty) {
        emit(CatalogListState<T>(status: CatalogListStatus.failure, message: failure.message));
      } else {
        emit(state.copyWith(refreshing: false, notice: _notice(failure.message, isError: true)));
      }
    }
  }

  Future<void> _onMoreRequested(
    CatalogMoreRequested event,
    Emitter<CatalogListState<T>> emit,
  ) async {
    if (!state.hasMore || state.loadingMore || state.status != CatalogListStatus.ready) return;
    final generation = _generation;
    emit(state.copyWith(loadingMore: true));
    try {
      final result = await load(state.page + 1);
      if (generation != _generation) return;
      emit(
        state.copyWith(
          items: [...state.items, ...result.items],
          page: result.page,
          hasMore: result.hasMore,
          loadingMore: false,
        ),
      );
    } on Failure catch (failure) {
      if (generation != _generation) return;
      emit(state.copyWith(loadingMore: false, notice: _notice(failure.message, isError: true)));
    }
  }

  Future<void> _onItemDeleted(
    CatalogItemDeleted event,
    Emitter<CatalogListState<T>> emit,
  ) async {
    if (state.deletingId != null) return;
    emit(state.copyWith(deletingId: () => event.id));
    try {
      await delete(event.id);
      emit(
        state.copyWith(
          items: [
            for (final item in state.items)
              if (idOf(item) != event.id) item,
          ],
          deletingId: () => null,
          notice: _notice(deletedMessage, isError: false),
        ),
      );
    } on Failure catch (failure) {
      emit(
        state.copyWith(
          deletingId: () => null,
          notice: _notice(failure.message, isError: true),
        ),
      );
    }
  }
}
