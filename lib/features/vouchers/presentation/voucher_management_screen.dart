import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/theme/tokens.dart';
import '../../admin_dashboard/presentation/widgets/owner_ui.dart';
import '../domain/voucher.dart';
import '../domain/voucher_usage_repository.dart';
import 'voucher_usage_history_dialog.dart';
import 'voucher_cubit.dart';
import 'voucher_state.dart';
import 'voucher_editor.dart';
import 'voucher_card.dart';

class VoucherManagementScreen extends StatefulWidget {
  const VoucherManagementScreen({super.key, this.usages});
  final VoucherUsageRepository? usages;
  @override
  State<VoucherManagementScreen> createState() =>
      _VoucherManagementScreenState();
}

class _VoucherManagementScreenState extends State<VoucherManagementScreen>
    with WidgetsBindingObserver {
  late final Timer _clock;
  bool _editing = false;
  Future<void> _history(Voucher row) async {
    final repository = widget.usages;
    if (_editing || repository == null) return;
    setState(() => _editing = true);
    try {
      await showDialog<void>(
        context: context,
        builder: (_) => VoucherUsageHistoryDialog(
          repository: repository,
          voucherId: row.id,
          code: row.code,
        ),
      );
    } finally {
      if (mounted) setState(() => _editing = false);
    }
  }

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
      useRootNavigator: true,
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
            : _CreateButton(
                onPressed: _editing || state.busyIds.isNotEmpty
                    ? null
                    : () => _edit(cubit),
              ),
        body: RefreshIndicator(
          onRefresh: state.branchId == null ? cubit.initialize : cubit.refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: ownerPad),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
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
                      const SizedBox(height: 14),
                      if (state.branchId != null)
                        OwnerNote('${state.total} voucher'),
                      const SizedBox(height: 12),
                      if (state.loading) const LinearProgressIndicator(),
                      if (state.error != null) ...[
                        OwnerNote(state.error!, size: 12),
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
                  child: OwnerMessage(
                    icon: Icons.local_offer_outlined,
                    text: state.branchId == null
                        ? 'Chưa có chi nhánh để quản lý'
                        : 'Chưa có voucher cho chi nhánh này',
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  ownerPad,
                  0,
                  ownerPad,
                  Gap.fabClearance,
                ),
                sliver: SliverList.builder(
                  itemCount: state.items.length,
                  itemBuilder: (context, index) {
                    final row = state.items[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 15),
                      child: VoucherCard(
                        key: ValueKey(row.id),
                        voucher: row,
                        now: DateTime.now().toUtc(),
                        busy: state.busyIds.contains(row.id),
                        blocked: state.loading || state.loadingMore || _editing,
                        onEdit: () => _edit(cubit, id: row.id),
                        onUsage: widget.usages == null
                            ? null
                            : () => _history(row),
                        onEnabled: (enabled) => cubit.setEnabled(row, enabled),
                      ),
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
            ],
          ),
        ),
      );
    },
  );
}

/// Nút "Tạo voucher": pill màu nhấn có bóng nhẹ (như nút "+ Chi nhánh").
class _CreateButton extends StatelessWidget {
  const _CreateButton({required this.onPressed});
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Opacity(
      opacity: onPressed == null ? .5 : 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.primary,
          borderRadius: BorderRadius.circular(Radii.pill),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF372A8F).withValues(alpha: .13),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(Radii.pill),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
              child: Text(
                'Tạo voucher',
                style: TextStyle(
                  color: colors.onPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
