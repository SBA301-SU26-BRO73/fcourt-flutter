import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/tokens.dart';
import '../../../app/widgets/wp3b_widgets.dart';
import '../../admin_dashboard/presentation/widgets/owner_ui.dart';
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

  Future<void> _openDetail(BuildContext context, AdminBooking row) async {
    final review = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Dialog.fullscreen(
        child: AdminBookingDetail(
          booking: row,
          onReviewPayment: widget.onReviewPayment == null
              ? null
              : () => Navigator.of(dialogContext).pop(true),
        ),
      ),
    );
    if (mounted && review == true) widget.onReviewPayment?.call(row);
  }

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
          final colors = Theme.of(context).colorScheme;
          final textStyle = ownerDropdownText(context);
          return SingleChildScrollView(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                OwnerSheetHeader(
                  title: 'Bộ lọc',
                  onClose: () => Navigator.pop(context),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    ownerPad,
                    12,
                    ownerPad,
                    16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (state.branches.isNotEmpty)
                        OwnerField(
                          label: 'Chi nhánh',
                          child: DropdownButtonFormField<int>(
                            key: ValueKey('branch-${query?.branchId}'),
                            initialValue: query?.branchId,
                            isExpanded: true,
                            style: textStyle,
                            decoration: ownerInput(),
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
                        ),
                      if (query != null) ...[
                        OwnerField(
                          label: 'Sân',
                          child: DropdownButtonFormField<int>(
                            key: ValueKey(
                              'court-${query.branchId}-${query.courtId}',
                            ),
                            initialValue: query.courtId,
                            isExpanded: true,
                            style: textStyle,
                            decoration: ownerInput(),
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
                            onChanged:
                                state.courtsLoading || state.courtsError != null
                                ? null
                                : cubit.setCourt,
                          ),
                        ),
                        if (state.courtsLoading)
                          const LinearProgressIndicator(),
                        if (state.courtsError != null) ...[
                          OwnerNote(
                            state.courtsError!,
                            size: 12,
                            color: colors.error,
                          ),
                          TextButton(
                            onPressed: cubit.reloadCourts,
                            child: const Text('Tải lại danh sách sân'),
                          ),
                        ],
                        OwnerField(
                          label: 'Trạng thái',
                          child: DropdownButtonFormField<AdminBookingStatus>(
                            key: ValueKey('status-${query.status}'),
                            initialValue: query.status,
                            isExpanded: true,
                            style: textStyle,
                            decoration: ownerInput(),
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
                        ),
                        OwnerField(
                          label: 'Ngày chơi',
                          child: Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () => _pickDate(cubit),
                                  borderRadius: BorderRadius.circular(Radii.md),
                                  child: InputDecorator(
                                    decoration: ownerInput(
                                      suffixIcon: const Icon(
                                        Icons.calendar_today,
                                        size: 18,
                                      ),
                                    ),
                                    child: Text(
                                      query.date == null
                                          ? 'Chọn ngày chơi'
                                          : DateFormat('dd/MM/yyyy')
                                                .format(query.date!),
                                      style: textStyle,
                                    ),
                                  ),
                                ),
                              ),
                              if (query.date != null)
                                IconButton(
                                  tooltip: 'Bỏ lọc ngày',
                                  onPressed: () => cubit.setDate(null),
                                  icon: const Icon(Icons.close, size: 20),
                                ),
                            ],
                          ),
                        ),
                      ],
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Xong'),
                        ),
                      ),
                    ],
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
  Widget build(BuildContext context) =>
      BlocConsumer<AdminBookingCubit, AdminBookingState>(
        listenWhen: (old, current) =>
            old.query?.branchId != current.query?.branchId,
        listener: (_, _) => _search.clear(),
        builder: (context, state) {
          final cubit = context.read<AdminBookingCubit>();
          final query = state.query;
          final colors = Theme.of(context).colorScheme;
          const pillPad = EdgeInsets.symmetric(horizontal: 13, vertical: 10);
          return Scaffold(
            appBar: AppBar(title: const Text('Quản lý đơn đặt sân')),
            body: RefreshIndicator(
              onRefresh: query == null ? cubit.initialize : cubit.refresh,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: ownerPad),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (state.branchesLoading)
                            const LinearProgressIndicator(),
                          if (query != null) ...[
                            const SizedBox(height: 7),
                            _SearchField(
                              controller: _search,
                              onChanged: cubit.search,
                              onSubmitted: cubit.refresh,
                            ),
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 7,
                              runSpacing: 7,
                              children: [
                                OwnerPill(
                                  'Cần xử lý',
                                  key: const ValueKey('chip-pending'),
                                  fontSize: 11,
                                  padding: pillPad,
                                  selected:
                                      query.status ==
                                      AdminBookingStatus.awaitingConfirmation,
                                  onTap: () => cubit.setStatus(
                                    AdminBookingStatus.awaitingConfirmation,
                                  ),
                                ),
                                OwnerPill(
                                  'Tất cả',
                                  key: const ValueKey('chip-all'),
                                  fontSize: 11,
                                  padding: pillPad,
                                  selected: query.status == null,
                                  onTap: () => cubit.setStatus(null),
                                ),
                                OwnerPill(
                                  'Bộ lọc',
                                  key: const ValueKey('open-filters'),
                                  fontSize: 11,
                                  padding: pillPad,
                                  trailing: Icon(
                                    Icons.tune,
                                    size: 14,
                                    color: colors.primary,
                                  ),
                                  onTap: () => _openFilters(cubit),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            OwnerNote(
                              state.loading
                                  ? 'Đang tải đơn…'
                                  : '${state.total} đơn đặt sân',
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (state.loading) const LinearProgressIndicator(),
                          if (state.error != null) ...[
                            const SizedBox(height: 12),
                            OwnerNote(
                              state.error!,
                              color: colors.error,
                              size: 12,
                            ),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton(
                                onPressed: query == null
                                    ? cubit.initialize
                                    : state.items.isEmpty
                                    ? cubit.refresh
                                    : cubit.loadMore,
                                child: const Text('Thử lại'),
                              ),
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
                      child: OwnerMessage(
                        icon: Icons.receipt_long_outlined,
                        text: state.branches.isEmpty
                            ? 'Chưa có chi nhánh để quản lý'
                            : 'Không có đơn đặt sân phù hợp',
                      ),
                    ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: ownerPad),
                    sliver: SliverList.builder(
                      itemCount: state.items.length,
                      itemBuilder: (context, index) {
                        final row = state.items[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 15),
                          child: _OrderCard(
                            row: row,
                            onTap: () => _openDetail(context, row),
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

/// Ô tìm kiếm pill 48 cao (mockup `.search`).
class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onSubmitted,
  });
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.search, size: 18, color: colors.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              maxLength: 200,
              onChanged: onChanged,
              onSubmitted: (_) => onSubmitted(),
              textInputAction: TextInputAction.search,
              style: const TextStyle(fontSize: 12),
              decoration: InputDecoration(
                isCollapsed: true,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                counterText: '',
                hintText: 'Tên hoặc SĐT khách hàng',
                hintStyle: TextStyle(
                  fontSize: 12,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Thẻ đơn (mockup `.order`): ngày + thẻ trạng thái, ảnh 74x82 cùng thông tin,
/// đường kẻ rồi tổng tiền.
class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.row, required this.onTap});
  final AdminBooking row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return OwnerCard(
      radius: 23,
      padding: const EdgeInsets.all(16),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: OwnerNote(DateFormat('dd/MM/yyyy').format(row.date)),
              ),
              BookingStatusBadge(row.status),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: SizedBox(
                  width: 74,
                  height: 82,
                  child: SportPhoto(sport: row.courtName),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${row.code} · ${row.customerName ?? 'Khách đặt sân'}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        fontWeight: FontWeight.w700,
                        color: colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    OwnerNote(row.courtName, size: 10),
                    if (row.customerPhone != null) ...[
                      const SizedBox(height: 4),
                      OwnerNote(row.customerPhone!, size: 10),
                    ],
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 15),
            child: Divider(height: 1, color: colors.outlineVariant),
          ),
          Row(
            children: [
              const Expanded(child: OwnerNote('Tổng tiền')),
              Text(
                adminBookingMoney(row.amount),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: colors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
