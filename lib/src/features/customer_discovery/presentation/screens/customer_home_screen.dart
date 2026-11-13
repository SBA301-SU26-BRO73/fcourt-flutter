import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../../app/widgets/wp3b_widgets.dart';
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

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _search() {
    FocusScope.of(context).unfocus();
    final cubit = context.read<DiscoveryCubit>();
    cubit.search(_query.text.trim());
    cubit.refresh();
  }

  void _openFilters() => showModalBottomSheet<void>(
    useRootNavigator: true,
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => BlocProvider.value(
      value: context.read<DiscoveryCubit>(),
      child: const DiscoveryFilterSheet(),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthBloc bloc) => bloc.state.user);
    final theme = Theme.of(context);
    return Scaffold(
      body: BlocBuilder<DiscoveryCubit, DiscoveryState>(
        builder: (context, state) {
          final cubit = context.read<DiscoveryCubit>();
          final branches = state.branches;
          return RefreshIndicator(
            onRefresh: cubit.refresh,
            edgeOffset: 120,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: HeroHeader(
                    key: const ValueKey('discovery-search'),
                    greeting: _greeting(user?.displayName),
                    title: 'Hôm nay,\nmình chơi gì?',
                    sportKind: state.sport?.kind ?? SportKind.badminton,
                    searchController: _query,
                    onSearchSubmitted: (_) => _search(),
                    onFilterTap: _openFilters,
                    height: 294 - MediaQuery.paddingOf(context).top,
                    trailing: const _AvatarButton(),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 23, 20, 0),
                    child: Row(
                      children: [
                        for (final sport in DiscoverySport.values)
                          Expanded(
                            child: SportCircleIcon(
                              kind: sport.kind,
                              label: sport.label,
                              selected: state.sport == sport,
                              onTap: () => cubit.filter(
                                state.sport == sport ? null : sport,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 23, 20, 15),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            state.sport == null
                                ? 'Sân nổi bật'
                                : 'Sân ${state.sport!.label.toLowerCase()}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontSize: 18,
                              height: 1.25,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () => context.push(
                            state.sport == null
                                ? '/branches'
                                : '/branches?sport=${state.sport!.name}',
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Xem tất cả',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(width: 3),
                                Icon(
                                  Icons.arrow_forward,
                                  size: 12,
                                  color: theme.colorScheme.primary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (state.loading)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(28),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
                if (state.error != null)
                  SliverToBoxAdapter(
                    child: DiscoveryMessage(
                      message: state.error!,
                      onRetry: cubit.refresh,
                    ),
                  ),
                if (!state.loading && state.error == null && branches.isEmpty)
                  const SliverToBoxAdapter(
                    child: DiscoveryMessage(
                      message: 'Chưa tìm thấy sân phù hợp. Thử từ khóa hoặc môn khác nhé.',
                    ),
                  ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList.separated(
                    itemCount: branches.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 16),
                    itemBuilder: (context, i) => BranchPhotoCard(
                      branch: branches[i],
                      sport: state.sport,
                      rank: i < 3 ? i + 1 : null,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      20,
                      16,
                      20,
                      FloatingNavBar.clearance,
                    ),
                    child: Center(
                      child: state.loadingMore
                          ? const CircularProgressIndicator()
                          : state.hasNext
                          ? OutlinedButton(
                              onPressed: cubit.loadMore,
                              child: const Text('Xem thêm sân'),
                            )
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

String _greeting(String? name) {
  final hour = DateTime.now().hour;
  final part = hour < 11
      ? 'buổi sáng'
      : hour < 14
      ? 'buổi trưa'
      : hour < 18
      ? 'buổi chiều'
      : 'buổi tối';
  final first = (name ?? '').trim().split(RegExp(r'\s+')).last;
  return first.isEmpty ? 'Chào $part' : 'Chào $part, $first';
}

/// Translucent white 40dp disc with a person icon (mock-up ".avatar").
class _AvatarButton extends StatelessWidget {
  const _AvatarButton();
  @override
  Widget build(BuildContext context) => Tooltip(
    message: 'Tài khoản',
    child: Semantics(
      button: true,
      label: 'Tài khoản',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => context.push('/profile'),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: .6),
            border: Border.all(color: Colors.white),
          ),
          child: const Icon(
            Icons.person_outline,
            size: 22,
            color: Color(0xFF29324B),
          ),
        ),
      ),
    ),
  );
}
