import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/voucher.dart';
import 'voucher_cubit.dart';
import 'voucher_state.dart';
import 'voucher_editor.dart';
import 'voucher_card.dart';

class VoucherManagementScreen extends StatefulWidget {
  const VoucherManagementScreen({super.key});
  @override
  State<VoucherManagementScreen> createState() =>
      _VoucherManagementScreenState();
}

class _VoucherManagementScreenState extends State<VoucherManagementScreen>
    with WidgetsBindingObserver {
  late final Timer _clock;
  bool _editing = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted && !_editing) {
      context.read<VoucherCubit>().refresh();
    }
  }

  Future<void> _edit(VoucherCubit cubit, {int? id}) async {
    final branchId = cubit.state.branchId;
    if (branchId == null || _editing) return;
    setState(() => _editing = true);
    final saved = await showModalBottomSheet<Voucher>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => VoucherEditor(
        repository: cubit.repository,
        branchId: branchId,
        id: id,
      ),
    );
    if (!mounted || cubit.isClosed) return;
    setState(() => _editing = false);
    if (saved != null && cubit.state.branchId == branchId) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Đã lưu voucher')));
      await cubit.refresh();
    }
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<VoucherCubit, VoucherState>(
    builder: (context, state) {
      final cubit = context.read<VoucherCubit>();
      return Scaffold(
        appBar: AppBar(title: const Text('Quản lý voucher')),
        floatingActionButton: state.branchId == null
            ? null
            : FloatingActionButton.extended(
                onPressed: _editing || state.busyIds.isNotEmpty
                    ? null
                    : () => _edit(cubit),
                icon: const Icon(Icons.add),
                label: const Text('Tạo voucher'),
              ),
        body: RefreshIndicator(
          onRefresh: state.branchId == null ? cubit.initialize : cubit.refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (state.branches.isNotEmpty)
                        DropdownButtonFormField<int>(
                          key: ValueKey(state.branchId),
                          initialValue: state.branchId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Chi nhánh',
                          ),
                          items: state.branches
                              .map(
                                (branch) => DropdownMenuItem(
                                  value: branch.id,
                                  child: Text(branch.name),
                                ),
                              )
                              .toList(),
                          onChanged: _editing
                              ? null
                              : (id) {
                                  if (id != null) cubit.selectBranch(id);
                                },
                        ),
                      const SizedBox(height: 12),
                      if (state.branchId != null)
                        Text('${state.total} voucher'),
                      if (state.loading) const LinearProgressIndicator(),
                      if (state.error != null) ...[
                        Text(state.error!),
                        TextButton(
                          onPressed: state.branchId == null
                              ? cubit.initialize
                        : cubit.refresh,
                          child: const Text('Thử lại'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (!state.loading && state.error == null && state.items.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text(
                      state.branchId == null
                          ? 'Chưa có chi nhánh để quản lý'
                          : 'Chưa có voucher cho chi nhánh này',
                    ),
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                sliver: SliverList.builder(
                  itemCount: state.items.length,
                  itemBuilder: (context, index) {
                    final row = state.items[index];
                    return VoucherCard(
                      key: ValueKey(row.id),
                      voucher: row,
                      now: DateTime.now().toUtc(),
                      busy:
                          state.busyIds.contains(row.id) ||
                          state.loading ||
                          state.loadingMore ||
                          _editing,
                      onEdit: () => _edit(cubit, id: row.id),
                      onEnabled: (enabled) => cubit.setEnabled(row, enabled),
                    );
                  },
                ),
              ),
              if (state.loadingMore || state.hasMore)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: state.loadingMore
                        ? const Center(child: CircularProgressIndicator())
                        : TextButton(
                            onPressed: cubit.loadMore,
                            child: const Text('Xem thêm'),
                          ),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      );
    },
  );
}
