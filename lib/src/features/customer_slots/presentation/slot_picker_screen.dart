import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/court_slot.dart';
import '../domain/slot_repository.dart';
import 'slot_picker_cubit.dart';
import 'widgets/slot_date_selector.dart';
import 'widgets/slot_grid_picker.dart';

class SlotPickerScreen extends StatelessWidget {
  const SlotPickerScreen({
    super.key,
    required this.repository,
    required this.courtId,
    this.courtName,
    this.branchName,
    this.date,
    this.onContinue,
  });
  final SlotRepository repository;
  final int courtId;
  final String? courtName, branchName;
  final DateTime? date;
  final ValueChanged<SlotSelection>? onContinue;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) =>
        SlotPickerCubit(repository, courtId: courtId, date: date)..refresh(),
    child: _SlotView(
      courtName: courtName ?? 'Sân #$courtId',
      branchName: branchName,
      onContinue: onContinue,
    ),
  );
}

class _SlotView extends StatefulWidget {
  const _SlotView({required this.courtName, this.branchName, this.onContinue});
  final String courtName;
  final String? branchName;
  final ValueChanged<SlotSelection>? onContinue;
  @override
  State<_SlotView> createState() => _SlotViewState();
}

class _SlotViewState extends State<_SlotView> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<SlotPickerCubit>().refresh();
    }
  }

  void _review(SlotPickerCubit cubit) {
    cubit.expirePastSlots();
    final selection = cubit.selection;
    if (selection.slots.isEmpty) return;
    if (widget.onContinue != null) {
      widget.onContinue!(selection);
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: .7,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: ListView(
            children: [
              Text(
                'Lựa chọn tạm tính',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text('${widget.courtName} · ${slotDateKey(selection.date)}'),
              const SizedBox(height: 16),
              for (final slot in selection.slots)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.schedule),
                  title: Text(
                    '${slotTime(slot.startMinute)}–${slotTime(slot.endMinute)}',
                  ),
                  trailing: Text(slotMoney(slot.priceMinor)),
                ),
              const Divider(),
              Text(
                'Tổng: ${slotMoney(selection.totalMinor)}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              const Text(
                'Các khung giờ này chưa được giữ chỗ. '
                'Chức năng xác nhận đặt sân sẽ được cập nhật sau.',
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<SlotPickerCubit, SlotPickerState>(
    builder: (context, state) {
      final cubit = context.read<SlotPickerCubit>();
      return Scaffold(
        appBar: AppBar(
          title: const Text('Lịch sân trống'),
          actions: [
            IconButton(
              tooltip: 'Tải lại lịch sân',
              onPressed: state.loading ? null : cubit.refresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: RefreshIndicator(
                onRefresh: cubit.refresh,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.all(16),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Chọn ngày, chọn giờ chơi',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on_outlined,
                                  size: 20,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    [widget.courtName, widget.branchName]
                                        .whereType<String>()
                                        .where((name) => name.isNotEmpty)
                                        .join(' · '),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SlotDateSelector(
                              date: state.date,
                              onSelected: (date) => cubit.refresh(date),
                            ),
                            const SizedBox(height: 20),
                            const SlotLegend(),
                            const SizedBox(height: 12),
                            const Text(
                              'Mỗi ô tương ứng 30 phút. Có thể chọn nhiều ô.\n'
                              'Lịch có thể thay đổi; chọn giờ chưa phải giữ chỗ.',
                            ),
                            if (state.notice != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Semantics(
                                  liveRegion: true,
                                  child: Text(
                                    state.notice!,
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .error,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (state.loading)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (state.error != null || state.slots.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.event_busy, size: 40),
                                const SizedBox(height: 12),
                                Text(
                                  state.error ??
                                      'Chưa có lịch sân trong ngày này.',
                                  textAlign: TextAlign.center,
                                ),
                                if (state.error != null)
                                  TextButton.icon(
                                    onPressed: cubit.refresh,
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('Thử lại'),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        sliver: SliverToBoxAdapter(
                          child: SlotGridPicker(
                            slots: state.slots,
                            selectedIds: state.selectedIds,
                            onToggle: cubit.toggle,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Card(
                margin: const EdgeInsets.all(12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              '${state.selectedIds.length} slot · ${state.selectedIds.length * 30} phút',
                            ),
                          ),
                          if (state.selectedIds.isNotEmpty)
                            TextButton(
                              onPressed: cubit.clear,
                              child: const Text('Bỏ chọn tất cả'),
                            ),
                        ],
                      ),
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        spacing: 16,
                        runSpacing: 4,
                        children: [
                          const Text('Tổng tạm tính'),
                          Text(
                            slotMoney(state.totalMinor),
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: state.loading || state.selectedIds.isEmpty
                            ? null
                            : () => _review(cubit),
                        icon: const Icon(Icons.shopping_bag_outlined),
                        label: Text(
                          widget.onContinue == null
                              ? 'Xem lựa chọn'
                              : 'Tiếp tục',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
