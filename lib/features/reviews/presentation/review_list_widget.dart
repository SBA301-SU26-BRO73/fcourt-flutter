import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../domain/review.dart';
import 'review_list_cubit.dart';

class ReviewListWidget extends StatelessWidget {
  const ReviewListWidget({
    super.key,
    required this.repository,
    required this.branchId,
  });
  final ReviewRepository repository;
  final int branchId;
  @override
  Widget build(BuildContext context) => BlocProvider(
    key: ValueKey((repository, branchId)),
    create: (_) => ReviewListCubit(repository, branchId)..refresh(),
    child: const _ReviewList(),
  );
}

class _ReviewList extends StatelessWidget {
  const _ReviewList();
  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<ReviewListCubit, ReviewListState>(
    builder: (context, state) {
      final cubit = context.read<ReviewListCubit>();
      final summary = state.summary;
      return RefreshIndicator(
        onRefresh: cubit.refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Đánh giá',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Làm mới đánh giá',
                          onPressed: state.loading ? null : cubit.refresh,
                          icon: const Icon(Icons.refresh),
                        ),
                      ],
                    ),
                    if (summary != null) ...[
                      Text(
                        '${summary.average.toStringAsFixed(2)}/5 · ${summary.total} đánh giá',
                      ),
                      for (var star = 5; star >= 1; star--)
                        Row(
                          children: [
                            Text('$star ★ '),
                            Expanded(
                              child: LinearProgressIndicator(
                                value: summary.total == 0
                                    ? 0
                                    : (summary.starCounts[star] ?? 0) /
                                          summary.total,
                              ),
                            ),
                            Text(' ${summary.starCounts[star] ?? 0}'),
                          ],
                        ),
                    ],
                    if (state.loading) const LinearProgressIndicator(),
                    if (state.error != null) ...[
                      Text(
                        state.error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      TextButton(
                        onPressed: cubit.retry,
                        child: const Text('Thử lại'),
                      ),
                    ],
                    if (!state.loading &&
                        state.error == null &&
                        state.items.isEmpty)
                      const Text('Chưa có đánh giá cho chi nhánh này'),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              sliver: SliverList.builder(
                itemCount: state.items.length,
                itemBuilder: (context, index) {
                  final row = state.items[index];
                  return Card(
                    key: ValueKey(row.id),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const CircleAvatar(
                                child: Icon(Icons.person_outline),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text('Khách hàng #${row.userId}'),
                              ),
                            ],
                          ),
                          Text('${row.rating}/5 ★'),
                          Text(
                            '${DateFormat('dd/MM/yyyy HH:mm').format(row.createdAt.toUtc().add(const Duration(hours: 7)))} (giờ Việt Nam)',
                          ),
                          if (row.comment?.isNotEmpty == true)
                            Text(row.comment!),
                          if (row.imageUrls.isNotEmpty)
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: row.imageUrls
                                  .map(
                                    (url) => Image.network(
                                      url,
                                      width: 96,
                                      height: 96,
                                      fit: BoxFit.cover,
                                      semanticLabel: 'Ảnh phản hồi tại sân',
                                      errorBuilder: (_, _, _) => const SizedBox(
                                        width: 96,
                                        height: 96,
                                        child: Icon(
                                          Icons.broken_image_outlined,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          if (row.adminReply?.isNotEmpty == true) ...[
                            const Divider(),
                            const Text(
                              'Phản hồi của chủ sân',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(row.adminReply!),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            if (state.hasMore && state.error == null)
              SliverToBoxAdapter(
                child: state.moreLoading
                    ? const Center(child: CircularProgressIndicator())
                    : TextButton(
                        onPressed: cubit.more,
                        child: const Text('Xem thêm đánh giá'),
                      ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      );
    },
  );
}
