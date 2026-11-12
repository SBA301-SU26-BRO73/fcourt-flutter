import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../../app/widgets/account_actions.dart';
import '../../../../../app/widgets/fc_widgets.dart';
import '../../../../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../domain/discovery_repository.dart';
import '../discovery_cubit.dart';
import '../widgets/discovery_filter_sheet.dart';
import '../widgets/discovery_widgets.dart';

class CustomerHomeScreen extends StatelessWidget {
  const CustomerHomeScreen({super.key, required this.repository});
  final DiscoveryRepository repository;
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => DiscoveryCubit(repository)..refresh(),
    child: const _DiscoveryLanding(),
  );
}

class _DiscoveryLanding extends StatefulWidget {
  const _DiscoveryLanding();
  @override
  State<_DiscoveryLanding> createState() => _DiscoveryLandingState();
}

class _DiscoveryLandingState extends State<_DiscoveryLanding> {
  final _query = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _query.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _search() {
    FocusScope.of(context).unfocus();
    _query.text = _query.text.trim();
    context.read<DiscoveryCubit>().search(_query.text.trim());
    context.read<DiscoveryCubit>().refresh();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthBloc bloc) => bloc.state.user);
    return Scaffold(
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Gap.screen, 10, 8, 10),
              child: Row(
                children: [
                  Expanded(
                    child: SearchBar(
                      key: const ValueKey('discovery-search'),
                      controller: _query,
                      hintText: 'Tìm sân, địa điểm',
                      elevation: const WidgetStatePropertyAll(0),
                      textInputAction: TextInputAction.search,
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => _search(),
                      leading: const Icon(Icons.search_outlined),
                      trailing: [
                        IconButton(
                          tooltip: 'Bộ lọc khu vực và giá',
                          icon: const Icon(Icons.tune),
                          onPressed: () => showModalBottomSheet<void>(
                            useRootNavigator: true,
                            context: context,
                            isScrollControlled: true,
                            useSafeArea: true,
                            builder: (_) => BlocProvider.value(
                              value: context.read<DiscoveryCubit>(),
                              child: const DiscoveryFilterSheet(),
                            ),
                          ),
                        ),
                        if (_query.text.isNotEmpty)
                          IconButton(
                            tooltip: 'Xóa tìm kiếm',
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              _query.clear();
                              _search();
                            },
                          ),
                      ],
                    ),
                  ),
                  const AccountActions(),
                ],
              ),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                BlocBuilder<DiscoveryCubit, DiscoveryState>(
                  builder: (context, state) {
                    final cubit = context.read<DiscoveryCubit>();
                    return RefreshIndicator(
                      onRefresh: cubit.refresh,
                      child: CustomScrollView(
                        controller: _scroll,
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(
                              Gap.screen,
                              8,
                              Gap.screen,
                              8,
                            ),
                            sliver: SliverToBoxAdapter(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Xin chào, ${user?.displayName ?? 'bạn'}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall,
                                  ),
                                  const SizedBox(height: Gap.md),
                                  SportFilters(
                                    selected: state.sport,
                                    onSelected: cubit.filter,
                                  ),
                                  const SizedBox(height: Gap.lg),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          state.sport == null
                                              ? 'Sân nổi bật'
                                              : 'Sân ${state.sport!.label.toLowerCase()}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (state.loading)
                                    const Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      child: LinearProgressIndicator(),
                                    ),
                                  if (state.error != null)
                                    DiscoveryMessage(
                                      message: state.error!,
                                      onRetry: cubit.refresh,
                                    ),
                                  if (!state.loading &&
                                      state.error == null &&
                                      state.branches.isEmpty)
                                    const DiscoveryMessage(
                                      message: 'Chưa tìm thấy sân phù hợp. Thử từ khóa hoặc môn khác nhé.',
                                    ),
                                ],
                              ),
                            ),
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            sliver: SliverLayoutBuilder(
                              builder: (context, constraints) {
                                final columns =
                                    constraints.crossAxisExtent >= 900
                                    ? 4
                                    : constraints.crossAxisExtent >= 620
                                    ? 3
                                    : 2;
                                // Cards size to their content: each row is as tall as its
                                // tallest card, with no fixed extent and no empty gap.
                                final rows =
                                    (state.branches.length + columns - 1) ~/
                                    columns;
                                return SliverList(
                                  delegate: SliverChildBuilderDelegate(
                                    (context, row) => Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: Gap.md,
                                      ),
                                      child: IntrinsicHeight(
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            for (
                                              var c = 0;
                                              c < columns;
                                              c++
                                            ) ...[
                                              if (c > 0)
                                                const SizedBox(width: Gap.md),
                                              Expanded(
                                                child:
                                                    row * columns + c <
                                                        state.branches.length
                                                    ? _VenueTile(
                                                        branch:
                                                            state.branches[row *
                                                                    columns +
                                                                c],
                                                        sport: state.sport,
                                                      )
                                                    : const SizedBox.shrink(),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                    childCount: rows,
                                  ),
                                );
                              },
                            ),
                          ),
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(
                                0,
                                24,
                                0,
                                24 + MediaQuery.paddingOf(context).bottom,
                              ),
                              child: Center(
                                child: state.loadingMore
                                    ? const CircularProgressIndicator()
                                    : state.hasNext
                                    ? OutlinedButton(
                                        onPressed: cubit.loadMore,
                                        child: const Text('Xem thêm sân'),
                                      )
                                    : const SizedBox(height: 16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VenueTile extends StatelessWidget {
  const _VenueTile({required this.branch, this.sport});
  final Branch branch;
  final DiscoverySport? sport;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final address = [
      branch.address,
      branch.city,
    ].where((s) => s.isNotEmpty).join(', ');
    return FcCard(
      padding: EdgeInsets.zero,
      clip: true,
      onTap: () => context.push('/branches/${branch.id}', extra: branch),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: branch.imageUrl == null
                ? CourtArtwork(sport: sport)
                : Image.network(
                    branch.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => CourtArtwork(sport: sport),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(Gap.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  branch.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
                if (address.isNotEmpty) ...[
                  const SizedBox(height: Gap.xs),
                  Text(
                    address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: Gap.sm),
                Row(
                  children: [
                    Icon(
                      Icons.star_rounded,
                      color: branch.reviewCount > 0
                          ? ChartColors.gold
                          : colors.outline,
                      size: 18,
                    ),
                    const SizedBox(width: Gap.xs),
                    Text(
                      branch.reviewCount > 0
                          ? branch.averageRating.toStringAsFixed(1)
                          : 'Mới',
                      style: theme.textTheme.bodySmall,
                    ),
                    const Spacer(),
                    Icon(
                      Icons.grid_view_rounded,
                      size: 14,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: Gap.xs),
                    Text(
                      '${branch.courtCount} sân',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Gap.xs),
                Text(
                  branchPrice(branch),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colors.primary,
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
