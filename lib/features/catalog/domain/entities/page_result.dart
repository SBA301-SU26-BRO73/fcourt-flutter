import 'package:equatable/equatable.dart';

/// Một trang kết quả của API danh sách. [page] bắt đầu từ 0.
class PageResult<T> extends Equatable {
  const PageResult({
    required this.items,
    required this.page,
    required this.totalPages,
    required this.totalElements,
  });

  final List<T> items;
  final int page;
  final int totalPages;
  final int totalElements;

  bool get hasMore => page + 1 < totalPages;

  @override
  List<Object?> get props => [items, page, totalPages, totalElements];
}
