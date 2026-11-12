import 'package:flutter/material.dart';

import '../../../../app/widgets/fc_widgets.dart';
import '../bloc/catalog_list_bloc.dart';

/// Khung danh sách phân trang dùng chung: vòng chờ, lỗi kèm thử lại, danh sách rỗng,
/// kéo để làm mới và nút tải thêm.
class CatalogListView<T> extends StatelessWidget {
  const CatalogListView({
    super.key,
    required this.state,
    required this.itemBuilder,
    required this.emptyMessage,
    required this.onRefresh,
    required this.onLoadMore,
  });

  final CatalogListState<T> state;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final String emptyMessage;

  /// Hoàn thành khi tải lại xong, để vòng kéo-làm-mới biết lúc nào dừng.
  final Future<void> Function() onRefresh;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    switch (state.status) {
      case CatalogListStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case CatalogListStatus.failure:
        return _Message(
          icon: Icons.cloud_off,
          text: state.message ?? 'Không tải được dữ liệu',
          action: FilledButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Thử lại'),
          ),
        );
      case CatalogListStatus.ready:
        if (state.items.isEmpty) {
          return RefreshIndicator(
            onRefresh: onRefresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: 380,
                  child: Center(
                    child: EmptyState(
                      icon: Icons.inbox_outlined,
                      message: emptyMessage,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: onRefresh,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              Gap.md,
              Gap.md,
              Gap.md,
              Gap.fabClearance,
            ),
            itemCount: state.items.length + (state.hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index < state.items.length) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: Gap.sm),
                  child: itemBuilder(context, state.items[index]),
                );
              }
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Center(
                  child: state.loadingMore
                      ? const CircularProgressIndicator()
                      : OutlinedButton(
                          onPressed: onLoadMore,
                          child: const Text('Tải thêm'),
                        ),
                ),
              );
            },
          ),
        );
    }
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}
