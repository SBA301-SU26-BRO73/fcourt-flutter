import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/widgets/fc_widgets.dart';
import '../../../app/widgets/filter_pill.dart';
import '../../../app/widgets/photo_empty_state.dart';
import '../../../app/widgets/pill_search_field.dart';
import '../../../app/widgets/wp3b_widgets.dart';
import '../../operations/domain/counter.dart';
import '../domain/pending_sale.dart';
import '../domain/pos.dart';
import 'order_dialog.dart';
import 'pos_cubit.dart';

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

  void _openCart(PosCubit cubit) => showModalBottomSheet<void>(
    useRootNavigator: true,
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: const FractionallySizedBox(heightFactor: 0.9, child: PosCart()),
    ),
  );

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
      final colors = Theme.of(context).colorScheme;
      final count = state.cart.values.fold(0, (sum, n) => sum + n);
      return LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 800;
          return Scaffold(
            appBar: AppBar(
              title: const Text('Quầy dịch vụ'),
              actions: [
                CircleIconButton(
                  tooltip: 'Hóa đơn',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          OrderHistory(repository: cubit.repository),
                    ),
                  ),
                  icon: Icons.receipt_long_outlined,
                ),
                CircleIconButton(
                  tooltip: 'Làm mới tồn kho',
                  onPressed: state.loading || state.selling
                      ? null
                      : () => cubit.load(),
                  icon: Icons.refresh,
                ),
                const SizedBox(width: 8),
              ],
            ),
            bottomNavigationBar: wide
                ? null
                : FloatingBottomBar(
                    caption: 'Tạm tính',
                    priceText: moneyLabel(state.total),
                    actionLabel: 'Giỏ hàng ($count)',
                    actionIcon: Icons.shopping_cart_outlined,
                    filled: count > 0,
                    onAction: () => _openCart(cubit),
                  ),
            body: SafeArea(
              bottom: false,
              child: wide
                  ? Row(
                      children: [
                        Expanded(
                          child: _catalog(context, state, cubit, colors),
                        ),
                        const VerticalDivider(width: 1),
                        const SizedBox(width: 340, child: PosCart()),
                      ],
                    )
                  : _catalog(context, state, cubit, colors),
            ),
          );
        },
      );
    },
  );

  Widget _catalog(
    BuildContext context,
    PosState state,
    PosCubit cubit,
    ColorScheme colors,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
          child: PillSearchField(
            hint: 'Tìm sản phẩm',
            onChanged: (value) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 300), () {
                cubit.query = value.trim();
                cubit.load();
              });
            },
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              FilterPill(
                'Tất cả',
                selected: cubit.category.isEmpty,
                onTap: () {
                  cubit.category = '';
                  cubit.load();
                },
              ),
              for (final c in cubit.categories) ...[
                const SizedBox(width: 7),
                FilterPill(
                  c,
                  selected: cubit.category == c,
                  onTap: () {
                    cubit.category = c;
                    cubit.load();
                  },
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (state.loading) const LinearProgressIndicator(),
        if (state.error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(state.error!, style: TextStyle(color: colors.error)),
          ),
        if (!state.loading && state.products.isEmpty)
          const PhotoEmptyState(
            message: 'Chưa tìm thấy sản phẩm. Thử từ khóa hoặc danh mục khác.',
          ),
        Expanded(
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 240,
                    mainAxisExtent:
                        232 *
                        MediaQuery.textScalerOf(context).scale(1).clamp(1, 2.5),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final p = state.products[index];
                    final count = cubit.count(p.id);
                    return _ProductTile(
                      product: p,
                      count: count,
                      canAdd:
                          p.stock > count && !state.selling && !state.uncertain,
                      onAdd: () => cubit.quantity(p, count + 1),
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
              const SliverToBoxAdapter(child: SizedBox(height: Gap.xl)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Flat 22dp product card: 96dp picture, name, accent price, stock tag and a
/// round "add" button.
class _ProductTile extends StatelessWidget {
  const _ProductTile({
    required this.product,
    required this.count,
    required this.canAdd,
    required this.onAdd,
  });
  final PosProduct product;
  final int count;
  final bool canAdd;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final p = product;
    final hasImage =
        p.imageUrl != null && Uri.tryParse(p.imageUrl!)?.scheme == 'https';
    return FcCard(
      radius: 22,
      padding: EdgeInsets.zero,
      clip: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 96,
            width: double.infinity,
            child: ColoredBox(
              color: colors.primaryContainer,
              child: hasImage
                  ? CachedNetworkImage(
                      imageUrl: p.imageUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => Icon(
                        Icons.inventory_2_outlined,
                        color: colors.onPrimaryContainer,
                      ),
                    )
                  : Icon(
                      Icons.inventory_2_outlined,
                      size: 36,
                      color: colors.onPrimaryContainer,
                    ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    moneyLabel(p.price),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: colors.primary,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          [
                            p.stock == 0 ? 'Hết hàng' : 'Còn ${p.stock}',
                            if (count > 0) 'Trong giỏ: $count',
                          ].join(' · '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                      IconButton.filledTonal(
                        tooltip: 'Thêm ${p.name}',
                        onPressed: canAdd ? onAdd : null,
                        icon: const Icon(Icons.add_shopping_cart, size: 18),
                      ),
                    ],
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
      final theme = Theme.of(context);
      final colors = theme.colorScheme;
      final locked = state.selling || state.uncertain || state.restoring;
      final method = state.uncertain ? cubit.pendingMethod ?? _method : _method;
      final note = TextStyle(fontSize: 11, color: colors.onSurfaceVariant);
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        children: [
          Text(
            'Giỏ hàng',
            style: theme.textTheme.titleLarge?.copyWith(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -.7,
            ),
          ),
          const SizedBox(height: 14),
          if (state.restoring)
            Text(
              'Đang kiểm tra lệnh bán đã lưu. Chưa được tạo giao dịch mới.',
              style: note,
            ),
          if (state.uncertain)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: context.fc.warning.container,
                  borderRadius: BorderRadius.circular(Radii.md),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Có lệnh bán chưa rõ kết quả. Đối soát lệnh cũ trước khi bán tiếp; không thu tiền lần nữa.',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.fc.warning.color,
                    ),
                  ),
                ),
              ),
            ),
          if (state.cart.isEmpty)
            const PhotoEmptyState(
              message: 'Chọn sản phẩm để bắt đầu bán hàng.',
              size: 96,
            ),
          if (state.cart.isNotEmpty)
            FcCard(
              radius: 22,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Column(
                children: [
                  for (final (i, e) in state.cart.entries.indexed) ...[
                    if (i > 0) const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  e.key.name,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  moneyLabel(e.key.price * e.value),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: colors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Bớt ${e.key.name}',
                            onPressed: locked
                                ? null
                                : () => cubit.quantity(e.key, e.value - 1),
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                          Text(
                            '${e.value}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Thêm ${e.key.name}',
                            onPressed: locked || e.value >= e.key.stock
                                ? null
                                : () => cubit.quantity(e.key, e.value + 1),
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 16),
          SegmentedButton<String>(
            showSelectedIcon: false,
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
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text('ID đơn đặt sân: ${cubit.pendingBooking}'),
            ),
          if (!state.uncertain && method == 'BOOKING')
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: TextField(
                controller: _booking,
                enabled: !locked,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'ID đơn đặt sân',
                  helperText: 'Máy chủ kiểm tra booking thuộc chi nhánh.',
                ),
              ),
            ),
          const SizedBox(height: 20),
          Text(
            'Dự tính: ${moneyLabel(state.total)}',
            style: theme.textTheme.titleLarge?.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: colors.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Giá và tồn kho chốt theo hóa đơn máy chủ. Chưa giao hàng khi đơn còn chờ gộp booking.',
            style: note,
          ),
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(state.error!, style: TextStyle(color: colors.error)),
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
