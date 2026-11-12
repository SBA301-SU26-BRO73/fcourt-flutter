import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/tokens.dart';
import '../../../app/widgets/wp3b_widgets.dart';
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
  Widget build(BuildContext context) =>
      BlocBuilder<ReviewListCubit, ReviewListState>(
        builder: (context, state) {
          final cubit = context.read<ReviewListCubit>();
          final summary = state.summary;
          final colors = Theme.of(context).colorScheme;
          return RefreshIndicator(
            onRefresh: cubit.refresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Đánh giá',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                            ),
                            CircleIconButton(
                              icon: Icons.refresh,
                              tooltip: 'Làm mới đánh giá',
                              onPressed: state.loading ? null : cubit.refresh,
                            ),
                          ],
                        ),
                        const SizedBox(height: Gap.md),
                        if (summary != null) _SummaryCard(summary: summary),
                        if (state.loading)
                          const Padding(
                            padding: EdgeInsets.only(top: Gap.md),
                            child: LinearProgressIndicator(),
                          ),
                        if (state.error != null) ...[
                          const SizedBox(height: Gap.md),
                          Text(
                            state.error!,
                            style: TextStyle(color: colors.error),
                          ),
                          TextButton(
                            onPressed: cubit.retry,
                            child: const Text('Thử lại'),
                          ),
                        ],
                        if (!state.loading &&
                            state.error == null &&
                            state.items.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: Gap.lg),
                            child: Text(
                              'Chưa có đánh giá cho chi nhánh này',
                              style: TextStyle(color: colors.onSurfaceVariant),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  sliver: SliverList.separated(
                    itemCount: state.items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: Gap.md),
                    itemBuilder: (context, index) => _ReviewCard(
                      key: ValueKey(state.items[index].id),
                      row: state.items[index],
                    ),
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

/// Average on the left, five soft bars on the right.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});
  final ReviewPage summary;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 112,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  summary.average.toStringAsFixed(1),
                  style: TextStyle(
                    fontSize: 40,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                    color: colors.primary,
                  ),
                ),
                _Stars(rating: summary.average.round(), size: 14),
                const SizedBox(height: 6),
                Text(
                  '${summary.average.toStringAsFixed(2)}/5 · ${summary.total} đánh giá',
                  style: TextStyle(
                    fontSize: 11,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: Gap.lg),
          Expanded(
            child: Column(
              children: [
                for (var star = 5; star >= 1; star--)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 14,
                          child: Text(
                            '$star',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(Radii.pill),
                            child: LinearProgressIndicator(
                              minHeight: 6,
                              value: summary.total == 0
                                  ? 0
                                  : (summary.starCounts[star] ?? 0) /
                                        summary.total,
                              backgroundColor: colors.surfaceContainerHighest,
                              color: colors.primary,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 26,
                          child: Text(
                            '${summary.starCounts[star] ?? 0}',
                            textAlign: TextAlign.end,
                            style: TextStyle(
                              fontSize: 11,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stars extends StatelessWidget {
  const _Stars({required this.rating, this.size = 14});
  final int rating;
  final double size;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: '$rating/5 sao',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 1; i <= 5; i++)
              Icon(
                i <= rating ? Icons.star_rounded : Icons.star_outline_rounded,
                size: size,
                color: i <= rating ? colors.primary : colors.outline,
              ),
          ],
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({super.key, required this.row});
  final CourtReview row;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final muted = TextStyle(fontSize: 11, color: colors.onSurfaceVariant);
    final when = DateFormat('dd/MM/yyyy HH:mm')
        .format(row.createdAt.toUtc().add(const Duration(hours: 7)));
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _ReviewerAvatar(url: row.reviewerAvatarUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.reviewerName ?? 'Khách hàng',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text('$when (giờ Việt Nam)', style: muted),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _Stars(rating: row.rating, size: 16),
          if (row.comment?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Text(
              row.comment!,
              style: const TextStyle(fontSize: 13, height: 1.45),
            ),
          ],
          if (row.imageUrls.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: row.imageUrls
                  .map(
                    (url) => ClipRRect(
                      borderRadius: BorderRadius.circular(Radii.md),
                      child: Image.network(
                        url,
                        width: 88,
                        height: 88,
                        fit: BoxFit.cover,
                        semanticLabel: 'Ảnh phản hồi tại sân',
                        errorBuilder: (_, _, _) => SizedBox(
                          width: 88,
                          height: 88,
                          child: ColoredBox(
                            color: colors.surfaceContainerHighest,
                            child: const Icon(Icons.broken_image_outlined),
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          if (row.adminReply?.isNotEmpty == true) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: BorderRadius.circular(Radii.md),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Phản hồi của chủ sân',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    row.adminReply!,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Reviewer photo with a generic icon when there is no avatar or it fails to load.
class _ReviewerAvatar extends StatelessWidget {
  const _ReviewerAvatar({required this.url});
  final String? url;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final fallback = Icon(
      Icons.person_outline,
      color: colors.onPrimaryContainer,
    );
    final avatar = url;
    return CircleAvatar(
      radius: 20,
      backgroundColor: colors.primaryContainer,
      child: avatar == null
          ? fallback
          : ClipOval(
              child: Image.network(
                avatar,
                width: 40,
                height: 40,
                fit: BoxFit.cover,
                semanticLabel: 'Ảnh đại diện người đánh giá',
                errorBuilder: (_, _, _) => fallback,
              ),
            ),
    );
  }
}
