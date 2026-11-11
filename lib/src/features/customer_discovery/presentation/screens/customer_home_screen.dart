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
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fc = context.fc;
    final pill = OutlineInputBorder(
      borderRadius: BorderRadius.circular(Radii.pill),
      borderSide: BorderSide(color: fc.hairline),
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
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(Radii.pill),
                        boxShadow: fc.shadowSmall,
                      ),
                      child: TextField(
                        key: const ValueKey('discovery-search'),
                        controller: _query,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => _search(),
                        decoration: InputDecoration(
                          hintText: 'Tìm sân, địa điểm',
                          fillColor: dark ? colors.surface : Colors.white,
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: IconButton(
                            tooltip: 'Tìm sân',
                            onPressed: _search,
                            icon: const Icon(Icons.arrow_forward_rounded),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 12,
                          ),
                          border: pill,
                          enabledBorder: pill,
                          focusedBorder: pill.copyWith(
                            borderSide: BorderSide(
                              color: colors.primary,
                              width: 1.8,
                            ),
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
                                    style: Theme.of(context).textTheme.bodyLarge
                                        ?.copyWith(
                                          color: colors.onSurfaceVariant,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Hôm nay ra sân nào?',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium,
                                  ),
                                  const SizedBox(height: 18),
                                  LayoutBuilder(
                                    builder: (context, constraints) => Wrap(
                                      spacing: 8,
                                      runSpacing: 12,
                                      children: [
                                        for (final (sport, icon, tint) in [
                                          (
                                            DiscoverySport.tennis,
                                            Icons.sports_tennis,
                                            const Color(0xFF16A47B),
                                          ),
                                          (
                                            DiscoverySport.badminton,
                                            Icons.sports,
                                            const Color(0xFFEF9B26),
                                          ),
                                          (
                                            DiscoverySport.football,
                                            Icons.sports_soccer,
                                            const Color(0xFF4582DD),
                                          ),
                                          (
                                            DiscoverySport.pickleball,
                                            Icons.sports_tennis,
                                            const Color(0xFF9062D8),
                                          ),
                                        ])
                                          SizedBox(
                                            width:
                                                (constraints.maxWidth - 24) / 4,
                                            child: Semantics(
                                              selected: state.sport == sport,
                                              button: true,
                                              child: InkWell(
                                                borderRadius:
                                                    BorderRadius.circular(18),
                                                onTap: () => cubit.filter(
                                                  state.sport == sport
                                                      ? null
                                                      : sport,
                                                ),
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 8,
                                                      ),
                                                  child: Column(
                                                    children: [
                                                      AnimatedContainer(
                                                        duration:
                                                            const Duration(
                                                              milliseconds: 200,
                                                            ),
                                                        curve:
                                                            Curves.easeOutCubic,
                                                        width: 60,
                                                        height: 60,
                                                        decoration: BoxDecoration(
                                                          gradient: LinearGradient(
                                                            begin: Alignment
                                                                .topLeft,
                                                            end: Alignment
                                                                .bottomRight,
                                                            colors:
                                                                state.sport ==
                                                                    sport
                                                                ? [
                                                                    tint.withValues(
                                                                      alpha:
                                                                          .85,
                                                                    ),
                                                                    tint,
                                                                  ]
                                                                : [
                                                                    tint.withValues(
                                                                      alpha: .1,
                                                                    ),
                                                                    tint.withValues(
                                                                      alpha:
                                                                          .26,
                                                                    ),
                                                                  ],
                                                          ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                20,
                                                              ),
                                                          border: Border.all(
                                                            color: fc.hairline,
                                                            width: 1.5,
                                                          ),
                                                          boxShadow:
                                                              state.sport ==
                                                                  sport
                                                              ? [
                                                                  BoxShadow(
                                                                    color: tint
                                                                        .withValues(
                                                                          alpha:
                                                                              .4,
                                                                        ),
                                                                    blurRadius:
                                                                        16,
                                                                    offset:
                                                                        const Offset(
                                                                          0,
                                                                          8,
                                                                        ),
                                                                  ),
                                                                ]
                                                              : null,
                                                        ),
                                                        child: Icon(
                                                          icon,
                                                          size: 30,
                                                          color:
                                                              state.sport ==
                                                                  sport
                                                              ? Colors.white
                                                              : tint,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 8),
                                                      Text(
                                                        'Đặt sân\n${sport.label}',
                                                        textAlign:
                                                            TextAlign.center,
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          state.sport == null
                                              ? 'Sân nổi bật'
                                              : 'Sân ${state.sport!.label.toLowerCase()}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleLarge
                                              ?.copyWith(
                                                fontWeight: FontWeight.w800,
                                              ),
                                        ),
                                      ),
                                      if (state.sport != null)
                                        TextButton(
                                          onPressed: () => cubit.filter(null),
                                          child: const Text('Tất cả'),
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
    return FrostedCard(
      padding: EdgeInsets.zero,
      clip: true,
      strong: true,
      onTap: () => context.push('/branches/${branch.id}', extra: branch),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 116,
            width: double.infinity,
            child: branch.imageUrl == null
                ? const CourtArtwork(height: 116, label: 'SportCourt')
                : Image.network(
                    branch.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        const CourtArtwork(height: 116, label: 'SportCourt'),
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
                            ? const Color(0xFFFFB300)
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
