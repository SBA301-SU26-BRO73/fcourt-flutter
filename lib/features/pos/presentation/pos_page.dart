import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../operations/domain/counter.dart';
import '../domain/pos.dart';
import '../domain/pending_sale.dart';
import 'pos_cubit.dart';
import 'order_dialog.dart';

class PosPage extends StatelessWidget {
  const PosPage({super.key, required this.repository, this.journal});
  final PosRepository repository;
  final PosSaleStore? journal;
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => PosCubit(repository, journal: journal)..load(),
    child: const _PosView(),
  );
}

class _PosView extends StatefulWidget {
  const _PosView();
  @override
  State<_PosView> createState() => _PosViewState();
}

class _PosViewState extends State<_PosView> {
  Timer? _debounce;
  int? _receiptId;
  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _receipt(PosCubit cubit, PosOrder order) async {
    await showDialog<void>(
      context: context,
      builder: (_) => OrderDialog(repository: cubit.repository, order: order),
    );
    if (mounted) await cubit.load();
  }

  @override
  Widget build(BuildContext context) => BlocConsumer<PosCubit, PosState>(
    listener: (context, state) {
      if (state.receipt case final order?) {
        if (order.id != _receiptId) {
          _receiptId = order.id;
          _receipt(context.read<PosCubit>(), order);
        }
      }
    },
    builder: (context, state) {
      final cubit = context.read<PosCubit>();
      return Scaffold(
        appBar: AppBar(
          title: const Text('Quầy dịch vụ'),
          actions: [
            IconButton(
              tooltip: 'Hóa đơn',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => OrderHistory(repository: cubit.repository),
                ),
              ),
              icon: const Icon(Icons.receipt_long),
            ),
            IconButton(
              tooltip: 'Làm mới tồn kho',
              onPressed: state.loading || state.selling
                  ? null
                  : () => cubit.load(),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 800;
              final catalog = Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      decoration: const InputDecoration(
                        labelText: 'Tìm sản phẩm',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (value) {
                        _debounce?.cancel();
                        _debounce = Timer(
                          const Duration(milliseconds: 300),
                          () {
                            cubit.query = value.trim();
                            cubit.load();
                          },
                        );
                      },
                    ),
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: ChoiceChip(
                            label: const Text('Tất cả'),
                            selected: cubit.category.isEmpty,
                            onSelected: (_) {
                              cubit.category = '';
                              cubit.load();
                            },
                          ),
                        ),
                        ...cubit.categories.map(
                          (c) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(c),
                              selected: cubit.category == c,
                              onSelected: (_) {
                                cubit.category = c;
                                cubit.load();
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (state.loading) const LinearProgressIndicator(),
                  if (state.error != null)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        state.error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  if (!state.loading && state.products.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Chưa tìm thấy sản phẩm. Thử từ khóa hoặc danh mục khác.',
                      ),
                    ),
                  Expanded(
                    child: CustomScrollView(
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.all(16),
                          sliver: SliverGrid(
                            gridDelegate:
                                SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: 260,
                                  mainAxisExtent:
                                      280 *
                                      MediaQuery.textScalerOf(context)
                                          .scale(1)
                                          .clamp(1, 2.5),
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                ),
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              final p = state.products[index];
                              final count = cubit.count(p.id);
                              return Card(
                                elevation: 0,
                                clipBehavior: Clip.antiAlias,
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      SizedBox(
                                        height: 80,
                                        width: double.infinity,
                                        child:
                                            p.imageUrl != null &&
                                                Uri.tryParse(p.imageUrl!)
                                                        ?.scheme ==
                                                    'https'
                                            ? CachedNetworkImage(
                                                imageUrl: p.imageUrl!,
                                                fit: BoxFit.cover,
                                                errorWidget: (_, _, _) =>
                                                    const Icon(
                                                      Icons
                                                          .inventory_2_outlined,
                                                    ),
                                              )
                                            : const Icon(
                                                Icons.inventory_2_outlined,
                                                size: 40,
                                              ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        p.name,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                      ),
                                      Text(moneyLabel(p.price)),
                                      Text(
                                        p.stock == 0
                                            ? 'Hết hàng'
                                            : 'Còn ${p.stock}',
                                      ),
                                      const Spacer(),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              count == 0
                                                  ? ''
                                                  : 'Trong giỏ: $count',
                                            ),
                                          ),
                                          IconButton(
                                            tooltip: 'Thêm ${p.name}',
                                            onPressed:
                                                p.stock <= count ||
                                                    state.selling ||
                                                    state.uncertain
                                                ? null
                                                : () => cubit.quantity(
                                                    p,
                                                    count + 1,
                                                  ),
                                            icon: const Icon(
                                              Icons.add_shopping_cart,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }, childCount: state.products.length),
                          ),
                        ),
                        if (state.hasMore)
                          SliverToBoxAdapter(
                            child: TextButton(
                              onPressed: state.loading
                                  ? null
                                  : () => cubit.load(more: true),
                              child: const Text('Xem thêm sản phẩm'),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (!wide)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: FilledButton.icon(
                        onPressed: () => showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          useSafeArea: true,
                          builder: (_) => BlocProvider.value(
                            value: cubit,
                            child: const FractionallySizedBox(
                              heightFactor: 0.9,
                              child: PosCart(),
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.shopping_cart_outlined),
                        label: Text(
                          'Giỏ hàng (${state.cart.values.fold(0, (sum, n) => sum + n)}) · ${moneyLabel(state.total)}',
                        ),
                      ),
                    ),
                ],
              );
              return wide
                  ? Row(
                      children: [
                        Expanded(child: catalog),
                        const VerticalDivider(width: 1),
                        const SizedBox(width: 340, child: PosCart()),
                      ],
                    )
                  : catalog;
            },
          ),
        ),
      );
    },
  );
}

class PosCart extends StatefulWidget {
  const PosCart({super.key});
  @override
  State<PosCart> createState() => _PosCartState();
}

class _PosCartState extends State<PosCart> {
  final _booking = TextEditingController();
  String _method = 'CASH';
  @override
  void dispose() {
    _booking.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<PosCubit, PosState>(
    builder: (context, state) {
      final cubit = context.read<PosCubit>();
      final locked = state.selling || state.uncertain || state.restoring;
      final method = state.uncertain ? cubit.pendingMethod ?? _method : _method;
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Giỏ hàng', style: Theme.of(context).textTheme.headlineSmall),
          if (state.restoring)
            const Text(
              'Đang kiểm tra lệnh bán đã lưu. Chưa được tạo giao dịch mới.',
            ),
          if (state.uncertain)
            const Text(
              'Có lệnh bán chưa rõ kết quả. Đối soát lệnh cũ trước khi bán tiếp; không thu tiền lần nữa.',
            ),
          if (state.cart.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text('Chọn sản phẩm để bắt đầu bán hàng.'),
            ),
          ...state.cart.entries.map(
            (e) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.key.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    IconButton(
                      tooltip: 'Bớt ${e.key.name}',
                      onPressed: locked
                          ? null
                          : () => cubit.quantity(e.key, e.value - 1),
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Text('${e.value}'),
                    IconButton(
                      tooltip: 'Thêm ${e.key.name}',
                      onPressed: locked || e.value >= e.key.stock
                          ? null
                          : () => cubit.quantity(e.key, e.value + 1),
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                    Text(moneyLabel(e.key.price * e.value)),
                  ],
                ),
                const Divider(),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'CASH', label: Text('Tiền mặt')),
              ButtonSegment(value: 'BOOKING', label: Text('Gộp booking')),
            ],
            selected: {method},
            onSelectionChanged: locked
                ? null
                : (value) => setState(() => _method = value.single),
          ),
          if (state.uncertain && method == 'BOOKING')
            Text('ID đơn đặt sân: ${cubit.pendingBooking}'),
          if (!state.uncertain && method == 'BOOKING')
            TextField(
              controller: _booking,
              enabled: !locked,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'ID đơn đặt sân',
                helperText: 'Máy chủ kiểm tra booking thuộc chi nhánh.',
              ),
            ),
          const SizedBox(height: 16),
          Text(
            'Dự tính: ${moneyLabel(state.total)}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const Text(
            'Giá và tồn kho chốt theo hóa đơn máy chủ. Chưa giao hàng khi đơn còn chờ gộp booking.',
          ),
          if (state.error != null)
            Text(
              state.error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: state.selling || state.restoring || state.cart.isEmpty
                ? null
                : () => cubit.sell(_method, int.tryParse(_booking.text)),
            child: Text(
              state.selling
                  ? 'Đang ghi hóa đơn…'
                  : state.uncertain
                  ? 'Thử lại lệnh bán cũ'
                  : 'Xác nhận xuất hóa đơn',
            ),
          ),
        ],
      );
    },
  );
}
