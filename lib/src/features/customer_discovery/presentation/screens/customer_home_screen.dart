import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../../app/widgets/account_actions.dart';
import '../../../../../app/widgets/fc_widgets.dart';
import '../../../../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../domain/discovery_repository.dart';
import '../discovery_cubit.dart';
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
    final colors = Theme.of(context).colorScheme;
    final pill = OutlineInputBorder(
      borderRadius: BorderRadius.circular(Radii.pill),
      borderSide: BorderSide(color: colors.outline),
    );
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
                    child: TextField(
                      key: const ValueKey('discovery-search'),
                      controller: _query,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _search(),
                      decoration: InputDecoration(
                        hintText: 'Tìm sân, địa điểm',
                        prefixIcon: const Icon(Icons.search_outlined),
                        suffixIcon: IconButton(
                          tooltip: 'Tìm sân',
                          onPressed: _search,
                          icon: const Icon(Icons.arrow_forward_outlined),
                        ),
                        border: pill,
                        enabledBorder: pill,
                        focusedBorder: pill.copyWith(
                          borderSide: BorderSide(
                            color: colors.primary,
                            width: 2,
                          ),
                        ),
                      ),
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
                                final scale = MediaQuery.textScalerOf(context)
                                    .scale(1);
                                return SliverGrid(
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) => _VenueTile(
                                      branch: state.branches[index],
                                    ),
                                    childCount: state.branches.length,
                                  ),
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: columns,
                                        crossAxisSpacing: 12,
                                        mainAxisSpacing: 14,
                                        mainAxisExtent:
                                            285 + math.max(0, scale - 1) * 90,
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
  const _VenueTile({required this.branch});
  final Branch branch;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return FcCard(
      padding: EdgeInsets.zero,
      clip: true,
      onTap: () => context.push('/branches/${branch.id}', extra: branch),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 116,
            width: double.infinity,
            child: branch.imageUrl == null
                ? const CourtArtwork(height: 116)
                : Image.network(
                    branch.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        const CourtArtwork(height: 116),
                  ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    branch.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    [
                      branch.address,
                      branch.city,
                    ].where((s) => s.isNotEmpty).join(', '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Icon(
                        Icons.star_rounded,
                        color: branch.reviewCount > 0
                            ? ChartColors.gold
                            : colors.outline,
                        size: 18,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        branch.reviewCount > 0
                            ? branch.averageRating.toStringAsFixed(1)
                            : 'Mới',
                        style: const TextStyle(fontSize: 12),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.grid_view_rounded,
                        size: 14,
                        color: colors.onSurfaceVariant,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${branch.courtCount} sân',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    branchPrice(branch),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: colors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
