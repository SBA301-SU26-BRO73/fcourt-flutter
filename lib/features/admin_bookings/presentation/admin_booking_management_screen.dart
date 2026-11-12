import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../app/widgets/fc_widgets.dart';
import '../domain/admin_booking.dart';
import '../domain/admin_booking_status.dart';
import 'admin_booking_cubit.dart';
import 'admin_booking_state.dart';
import 'admin_booking_detail.dart';
import 'booking_status_badge.dart';

class AdminBookingManagementScreen extends StatefulWidget {
  const AdminBookingManagementScreen({super.key, this.onReviewPayment});

  /// Mở màn duyệt biên lai của chi nhánh; null thì không hiện nút trong chi tiết đơn.
  final void Function(AdminBooking booking)? onReviewPayment;
  @override
  State<AdminBookingManagementScreen> createState() =>
      _AdminBookingManagementScreenState();
}

class _AdminBookingManagementScreenState
    extends State<AdminBookingManagementScreen> {
  final _search = TextEditingController();
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _pickDate(AdminBookingCubit cubit) async {
    final branch = cubit.state.query?.branchId;
    final picked = await showDatePicker(
      context: context,
      initialDate: cubit.state.query?.date ?? DateTime.now(),
      firstDate: DateTime(1),
      lastDate: DateTime(9999, 12, 31),
    );
    if (mounted &&
        !cubit.isClosed &&
        cubit.state.query?.branchId == branch &&
        picked != null) {
      cubit.setDate(picked);
    }
  }

  void _openDetail(BuildContext context, AdminBooking row) => showDialog<void>(
    context: context,
    builder: (_) => Dialog.fullscreen(
      child: AdminBookingDetail(
        booking: row,
        onReviewPayment: widget.onReviewPayment == null
            ? null
            : () {
                Navigator.of(context).pop();
                widget.onReviewPayment!(row);
              },
      ),
    ),
  );

  Future<void> _openFilters(
    AdminBookingCubit cubit,
  ) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: BlocBuilder<AdminBookingCubit, AdminBookingState>(
        builder: (context, state) {
          final query = state.query;
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              16 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Bộ lọc', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                if (state.branches.isNotEmpty) ...[
                  DropdownButtonFormField<int>(
                    key: ValueKey('branch-${query?.branchId}'),
                    initialValue: query?.branchId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Chi nhánh'),
                    items: state.branches
                        .map(
                          (branch) => DropdownMenuItem(
                            value: branch.id,
                            child: Text(branch.name),
                          ),
                        )
                        .toList(),
                    onChanged: (id) {
                      if (id != null) cubit.selectBranch(id);
                    },
                  ),
                  const SizedBox(height: 12),
                ],

                if (query != null) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    key: ValueKey('court-${query.branchId}-${query.courtId}'),
                    initialValue: query.courtId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Sân'),
                    items: [
                      const DropdownMenuItem<int>(
                        value: null,
                        child: Text('Tất cả sân'),
                      ),
                      ...state.courts.map(
                        (court) => DropdownMenuItem(
                          value: court.id,
                          child: Text(court.name),
                        ),
                      ),
                    ],
                    onChanged: state.courtsLoading || state.courtsError != null
                        ? null
                        : cubit.setCourt,
                  ),
                  if (state.courtsLoading) const LinearProgressIndicator(),
                  if (state.courtsError != null) ...[
                    Text(state.courtsError!),
                    TextButton(
                      onPressed: cubit.reloadCourts,
                      child: const Text('Tải lại danh sách sân'),
                    ),
                  ],
                  const SizedBox(height: 12),
                  DropdownButtonFormField<AdminBookingStatus>(
                    key: ValueKey('status-${query.status}'),
                    initialValue: query.status,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Trạng thái'),
                    items: [
                      const DropdownMenuItem<AdminBookingStatus>(
                        value: null,
                        child: Text('Tất cả trạng thái'),
                      ),
                      ...AdminBookingStatus.values.map(
                        (status) => DropdownMenuItem(
                          value: status,
                          child: Text(status.label),
                        ),
                      ),
                    ],
                    onChanged: cubit.setStatus,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _pickDate(cubit),
                        icon: const Icon(Icons.calendar_today),
                        label: Text(
                          query.date == null
                              ? 'Chọn ngày chơi'
                              : DateFormat('dd/MM/yyyy').format(query.date!),
                        ),
                      ),
                      if (query.date != null)
                        IconButton(
                          tooltip: 'Bỏ lọc ngày',
                          onPressed: () => cubit.setDate(null),
                          icon: const Icon(Icons.close),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Xong'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );

  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<AdminBookingCubit, AdminBookingState>(
    listenWhen: (old, current) =>
        old.query?.branchId != current.query?.branchId,
    listener: (_, _) => _search.clear(),
    builder: (context, state) {
      final cubit = context.read<AdminBookingCubit>();
      final query = state.query;
      return Scaffold(
        appBar: AppBar(title: const Text('Quản lý đơn đặt sân')),
        body: RefreshIndicator(
          onRefresh: query == null ? cubit.initialize : cubit.refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (state.branchesLoading)
                        const LinearProgressIndicator(),
                      if (query != null) ...[
                        TextField(
                          controller: _search,
                          maxLength: 200,
                          onChanged: cubit.search,
                          onSubmitted: (_) => cubit.refresh(),
                          textInputAction: TextInputAction.search,
                          decoration: const InputDecoration(
                            labelText: 'Tên hoặc SĐT khách hàng',
                            counterText: '',
                            prefixIcon: Icon(Icons.search),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            ChoiceChip(
                              key: const ValueKey('chip-pending'),
                              label: const Text('Cần xử lý'),
                              selected:
                                  query.status ==
                                  AdminBookingStatus.awaitingConfirmation,
                              onSelected: (_) => cubit.setStatus(
                                AdminBookingStatus.awaitingConfirmation,
                              ),
                            ),
                            ChoiceChip(
                              key: const ValueKey('chip-all'),
                              label: const Text('Tất cả'),
                              selected: query.status == null,
                              onSelected: (_) => cubit.setStatus(null),
                            ),
                            ActionChip(
                              key: const ValueKey('open-filters'),
                              avatar: const Icon(Icons.tune, size: 18),
                              label: const Text('Bộ lọc'),
                              onPressed: () => _openFilters(cubit),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          state.loading
                              ? 'Đang tải đơn…'
                              : '${state.total} đơn đặt sân',
                        ),
                      ],
                      if (state.loading) const LinearProgressIndicator(),
                      if (state.error != null) ...[
                        Text(state.error!),
                        TextButton(
                          onPressed: query == null
                              ? cubit.initialize
                              : state.items.isEmpty
                              ? cubit.refresh
                              : cubit.loadMore,
                          child: const Text('Thử lại'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (!state.branchesLoading &&
                  !state.loading &&
                  state.error == null &&
                  state.items.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text(
                      state.branches.isEmpty
                          ? 'Chưa có chi nhánh để quản lý'
                          : 'Không có đơn đặt sân phù hợp',
                    ),
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList.builder(
                  itemCount: state.items.length,
                  itemBuilder: (context, index) {
                    final row = state.items[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: Gap.sm),
                      child: FcCard(
                        onTap: () => _openDetail(context, row),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${row.code} · ${row.customerName ?? 'Khách đặt sân'}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall,
                                  ),
                                  const SizedBox(height: Gap.xs),
                                  Text(
                                    '${row.courtName} · ${DateFormat('dd/MM/yyyy').format(row.date)}',
                                  ),
                                  if (row.customerPhone != null)
                                    Text(row.customerPhone!),
                                  Text(adminBookingMoney(row.amount)),
                                  const SizedBox(height: Gap.sm),
                                  BookingStatusBadge(row.status),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
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
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      );
    },
  );
}
