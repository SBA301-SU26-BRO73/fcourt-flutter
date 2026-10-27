import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../discovery_cubit.dart';
import '../widgets/discovery_widgets.dart';

class BranchListScreen extends StatefulWidget {
  const BranchListScreen({super.key});
  @override
  State<BranchListScreen> createState() => _BranchListScreenState();
}

class _BranchListScreenState extends State<BranchListScreen> {
  late final _query = TextEditingController(
    text: context.read<DiscoveryCubit>().state.query,
  );
  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Khám phá sân')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: BlocBuilder<DiscoveryCubit, DiscoveryState>(
            builder: (context, state) {
              final cubit = context.read<DiscoveryCubit>();
              return RefreshIndicator(
                onRefresh: cubit.refresh,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: _query,
                              maxLength: 200,
                              textInputAction: TextInputAction.search,
                              onChanged: cubit.search,
                              onSubmitted: (_) => cubit.refresh(),
                              decoration: InputDecoration(
                                labelText: 'Tên sân hoặc địa chỉ',
                                counterText: '',
                                prefixIcon: const Icon(Icons.search),
                                suffixIcon: IconButton(
                                  tooltip: 'Xóa tìm kiếm',
                                  icon: const Icon(Icons.close),
                                  onPressed: () {
                                    _query.clear();
                                    cubit.search('');
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SportFilters(
                              selected: state.sport,
                              onSelected: cubit.filter,
                            ),
                            const SizedBox(height: 20),
                            Text(
                              state.loading
                                  ? 'Đang tìm sân…'
                                  : '${state.total} chi nhánh',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                            if (state.loading) const LinearProgressIndicator(),
                            if (state.error != null)
                              DiscoveryMessage(
                                message: state.error!,
                                onRetry: state.branches.isEmpty
                                    ? cubit.refresh
                                    : cubit.loadMore,
                              ),
                            if (!state.loading &&
                                state.error == null &&
                                state.branches.isEmpty)
                              const DiscoveryMessage(
                                message: 'Chưa tìm thấy sân phù hợp.\nThử từ khóa hoặc môn thể thao khác.',
                              ),
                          ],
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      sliver: SliverList.builder(
                        itemCount: state.branches.length,
                        itemBuilder: (context, index) {
                          final branch = state.branches[index];
                          return BranchCard(
                            branch: branch,
                            onTap: () => context.push(
                              '/branches/${branch.id}',
                              extra: branch,
                            ),
                          );
                        },
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: state.loadingMore
                            ? const Center(child: CircularProgressIndicator())
                            : state.hasNext
                            ? OutlinedButton(
                                onPressed: cubit.loadMore,
                                child: const Text('Xem thêm chi nhánh'),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
}
