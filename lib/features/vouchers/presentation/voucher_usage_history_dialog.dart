import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../domain/voucher_usage.dart';
import '../domain/voucher_usage_repository.dart';
import 'voucher_usage_cubit.dart';
import 'voucher_usage_state.dart';

class VoucherUsageHistoryDialog extends StatelessWidget {
  const VoucherUsageHistoryDialog({
    super.key,
    required this.repository,
    required this.voucherId,
    required this.code,
  });
  final VoucherUsageRepository repository;
  final int voucherId;
  final String code;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => VoucherUsageCubit(repository, voucherId)..refresh(),
    child: Dialog.fullscreen(child: _HistoryView(code: code)),
  );
}

class _HistoryView extends StatelessWidget {
  const _HistoryView({required this.code});
  final String code;
  String money(int minor) =>
      '${NumberFormat('#,##0.##', 'vi').format(minor / 100)} đ';

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text('Lượt dùng $code'),
      leading: IconButton(
        tooltip: 'Đóng',
        icon: const Icon(Icons.close),
        onPressed: () => Navigator.of(context).pop(),
      ),
    ),
    body: BlocBuilder<VoucherUsageCubit, VoucherUsageState>(
      builder: (context, state) {
        final cubit = context.read<VoucherUsageCubit>();
        return RefreshIndicator(
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
                        state.query.trim().isEmpty
                            ? 'Tổng chi phí khuyến mãi của mã'
                            : 'Chi phí khuyến mãi của kết quả đang lọc',
                      ),
                      Text(
                        state.totalDiscountMinor == null
                            ? '—'
                            : money(state.totalDiscountMinor!),
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        key: const ValueKey('usage-phone'),
                        keyboardType: TextInputType.phone,
                        maxLength: 20,
                        onChanged: cubit.search,
                        decoration: const InputDecoration(
                          labelText: 'Tìm SĐT khách hàng',
                          helperText:
                              'Nhập ít nhất 3 chữ số, hỗ trợ cả dạng +84.',
                          prefixIcon: Icon(Icons.search),
                        ),
                      ),
                      Text('${state.total} lượt dùng'),
                      if (state.loading) const LinearProgressIndicator(),
                      if (state.error != null) ...[
                        Text(
                          state.error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        TextButton(
                          onPressed: cubit.retry,
                          child: const Text('Thử lại'),
                        ),
                      ],
                      if (!state.loading &&
                          state.error == null &&
                          state.items.isEmpty)
                        const Text('Chưa có lượt sử dụng phù hợp'),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                sliver: SliverList.builder(
                  itemCount: state.items.length,
                  itemBuilder: (context, index) {
                    final row = state.items[index];
                    final time = DateFormat(
                      'dd/MM/yyyy HH:mm',
                    ).format(row.usedAt.toUtc().add(const Duration(hours: 7)));
                    return Card(
                      key: ValueKey(row.id),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              row.customerName ?? 'Khách hàng #${row.userId}',
                            ),
                            Text(row.customerPhone ?? 'SĐT chưa được cung cấp'),
                            Text(
                              row.bookingCode ??
                                  'Đơn #${row.bookingId} (chưa có mã)',
                            ),
                            Text('Được giảm: ${money(row.discountMinor)}'),
                            Text(
                              '${row.timeSource == VoucherUsageTimeSource.paymentConfirmed ? 'Thanh toán lúc' : 'Ghi nhận lúc'}: $time (giờ Việt Nam)',
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (state.hasMore && state.error == null)
                SliverToBoxAdapter(
                  child: state.loadingMore
                      ? const Center(child: CircularProgressIndicator())
                      : TextButton(
                          onPressed: state.loading ? null : cubit.loadMore,
                          child: const Text('Xem thêm'),
                        ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ),
        );
      },
    ),
  );
}
