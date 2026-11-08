import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../domain/subscription.dart';
import 'subscription_cubit.dart';
import 'subscription_state.dart';
import 'plan_comparison.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});
  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen>
    with WidgetsBindingObserver {
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
  void didChangeAppLifecycleState(AppLifecycleState state) => context
      .read<SubscriptionCubit>()
      .foreground(state == AppLifecycleState.resumed);
  String date(DateTime value) => DateFormat('dd/MM/yyyy').format(value);

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<SubscriptionCubit, SubscriptionState>(
    builder: (context, state) {
      final cubit = context.read<SubscriptionCubit>();
      final current = state.current, payment = state.payment;
      final locked = state.busy || state.checking || state.loading;
      final buying = locked || payment?.pending == true;
      return Scaffold(
        appBar: AppBar(
          title: const Text('Gói dịch vụ'),
          actions: [
            IconButton(
              tooltip: 'Làm mới gói dịch vụ',
              onPressed: locked ? null : cubit.refresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: SafeArea(
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
                          'Gói hiện tại',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        if (state.loading) const LinearProgressIndicator(),
                        if (state.error != null) ...[
                          Text(
                            state.error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                          TextButton(
                            onPressed: locked ? null : cubit.refresh,
                            child: const Text('Thử lại'),
                          ),
                        ],
                        if (current != null)
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    current.period.plan.name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge,
                                  ),
                                  Chip(
                                    label: Text(
                                      current.active
                                          ? 'Đang có hiệu lực'
                                          : 'Không còn hiệu lực',
                                    ),
                                  ),
                                  if (current.starter)
                                    const Text('Gói khởi đầu do hệ thống cấp'),
                                  Text(
                                    'Hiệu lực: ${date(current.period.startDate)} – ${date(current.period.endDate)}',
                                  ),
                                  Text(
                                    'Ngày hết hạn: ${date(current.period.endDate)} (giờ Việt Nam)',
                                  ),
                                  Text(
                                    'Hạn mức hiện tại: ${current.period.maxBranches} chi nhánh · ${current.period.maxCourts} sân',
                                  ),
                                  if (current.upcoming.isNotEmpty)
                                    const Text('Các kỳ đã thanh toán sắp tới'),
                                  for (final next in current.upcoming)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(
                                        '${next.plan.name}: ${date(next.startDate)} – ${date(next.endDate)}\n'
                                        '${next.maxBranches} chi nhánh · ${next.maxCourts} sân',
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),
                        SegmentedButton<BillingCycle>(
                          segments: [
                            for (final cycle in BillingCycle.values)
                              ButtonSegment(
                                value: cycle,
                                label: Text(
                                  'Theo ${cycle.label.toLowerCase()}',
                                ),
                              ),
                          ],
                          selected: {state.cycle},
                          onSelectionChanged: locked
                              ? null
                              : (selection) => cubit.cycle(selection.single),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Gói và ngày hiệu lực sau thanh toán do máy chủ xác nhận. Gói khác có thể áp dụng từ kỳ kế tiếp.',
                        ),
                        if (payment != null)
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Giao dịch #${payment.orderCode} · ${payment.planName}',
                                  ),
                                  Text(
                                    '${subscriptionMoney(payment.amount)} / ${payment.cycle.label.toLowerCase()}',
                                  ),
                                  Text(switch (payment.status) {
                                    SubscriptionPaymentStatus.pending =>
                                      'Chờ thanh toán',
                                    SubscriptionPaymentStatus.paid =>
                                      'Máy chủ đã ghi nhận thanh toán',
                                    SubscriptionPaymentStatus.expired =>
                                      'Giao dịch đã hết hạn',
                                    SubscriptionPaymentStatus.cancelled =>
                                      'Giao dịch đã hủy',
                                    SubscriptionPaymentStatus.failed =>
                                      'Giao dịch thất bại',
                                  }),
                                  if (payment.pending) ...[
                                    Text(
                                      'Hạn thanh toán: ${DateFormat('dd/MM/yyyy HH:mm').format(payment.expiredAt.toUtc().add(const Duration(hours: 7)))} (giờ Việt Nam)',
                                    ),
                                    TextButton(
                                      onPressed: locked
                                          ? null
                                          : cubit.openPayment,
                                      child: const Text('Mở lại PayOS'),
                                    ),
                                  ],
                                  TextButton(
                                    onPressed: locked
                                        ? null
                                        : cubit.checkPayment,
                                    child: const Text(
                                      'Kiểm tra kết quả thanh toán',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (state.paymentError != null)
                          Text(
                            state.paymentError!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        if (state.busy || state.checking)
                          const LinearProgressIndicator(),
                        if (!state.loading &&
                            state.plans.isEmpty &&
                            state.error == null)
                          const Text('Chưa có gói dịch vụ đang bán'),
                        if (state.plans.isNotEmpty)
                          PlanComparison(plans: state.plans),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  sliver: SliverList.builder(
                    itemCount: state.plans.length,
                    itemBuilder: (context, index) {
                      final plan = state.plans[index],
                          price = state.cycle.price(state.plans[index]);
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                plan.name,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              if (plan.popular)
                                const Chip(label: Text('Phổ biến')),
                              if (plan.tagline != null) Text(plan.tagline!),
                              Text(
                                '${subscriptionMoney(price)}${price == null ? '' : ' / ${state.cycle.label.toLowerCase()}'}',
                              ),
                              Text(
                                '${plan.maxBranches} chi nhánh · ${plan.maxCourts} sân',
                              ),
                              for (final feature in plan.features)
                                Text('• $feature'),
                              FilledButton(
                                key: ValueKey('checkout-${plan.id}'),
                                onPressed: buying || price == null
                                    ? null
                                    : () => cubit.checkout(plan.id),
                                child: Text(
                                  current?.period.plan.id == plan.id
                                      ? 'Gia hạn gói'
                                      : 'Nâng cấp / đổi gói',
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ),
          ),
        ),
      );
    },
  );
}
