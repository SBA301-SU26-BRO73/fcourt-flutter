import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../domain/discovery_repository.dart';
import '../discovery_cubit.dart';
import 'discovery_widgets.dart';

class VenueFeed extends StatelessWidget {
  const VenueFeed({super.key, required this.repository});
  final DiscoveryRepository repository;
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => DiscoveryCubit(repository)..refresh(),
    child: BlocBuilder<DiscoveryCubit, DiscoveryState>(
      builder: (context, state) {
        final cubit = context.read<DiscoveryCubit>();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SportFilters(selected: state.sport, onSelected: cubit.filter),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Sân dành cho bạn',
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                TextButton(
                  onPressed: () => context.go('/discover'),
                  child: const Text('Xem tất cả'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (state.loading)
              const Padding(
                padding: EdgeInsets.all(28),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (state.error != null)
              DiscoveryMessage(message: state.error!, onRetry: cubit.refresh),
            if (!state.loading && state.error == null && state.branches.isEmpty)
              DiscoveryMessage(
                message: 'Chưa có sân cho môn này. Thử xem tất cả nhé.',
                onRetry: () => cubit.filter(null),
              ),
            for (final branch in state.branches)
              BranchCard(
                branch: branch,
                onTap: () =>
                    context.push('/branches/${branch.id}', extra: branch),
              ),
            if (state.hasNext)
              Center(
                child: TextButton(
                  onPressed: state.loadingMore ? null : cubit.loadMore,
                  child: Text(state.loadingMore ? 'Đang tải…' : 'Xem thêm sân'),
                ),
              ),
          ],
        );
      },
    ),
  );
}
