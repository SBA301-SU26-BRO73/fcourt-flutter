import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/widgets/fc_widgets.dart';
import '../../domain/entities/subscription_plan.dart';
import '../../domain/entities/subscription_plan_input.dart';
import '../../domain/usecases/save_subscription_plan.dart';
import '../bloc/catalog_form_bloc.dart';
import '../bloc/catalog_list_bloc.dart';
import '../formatters.dart';
import '../widgets/catalog_notice.dart';
import '../widgets/catalog_list_view.dart';
import '../widgets/confirm_delete_dialog.dart';
import '../widgets/status_chip.dart';
import 'subscription_plan_form_page.dart';

typedef PlanListBloc = CatalogListBloc<SubscriptionPlan>;

class SubscriptionPlansTab extends StatefulWidget {
  const SubscriptionPlansTab({super.key, required this.savePlan});

  final SaveSubscriptionPlan savePlan;

  @override
  State<SubscriptionPlansTab> createState() => _SubscriptionPlansTabState();
}

class _SubscriptionPlansTabState extends State<SubscriptionPlansTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Future<void> _refresh(PlanListBloc bloc) {
    bloc.add(const CatalogRefreshed());
    return bloc.stream.firstWhere((state) => !state.refreshing);
  }

  Future<void> _openForm(SubscriptionPlan? editing) async {
    final bloc = context.read<PlanListBloc>();
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => BlocProvider(
          create: (_) => CatalogFormBloc<SubscriptionPlanInput>(
            (input) => widget.savePlan(input, id: editing?.id),
          ),
          child: SubscriptionPlanFormPage(editing: editing),
        ),
      ),
    );
    if (saved == true) {
      bloc.add(const CatalogRefreshed());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              editing == null ? 'Đã thêm gói dịch vụ' : 'Đã lưu gói dịch vụ',
            ),
          ),
        );
      }
    }
  }

  Future<void> _delete(SubscriptionPlan plan) async {
    final bloc = context.read<PlanListBloc>();
    final confirmed = await confirmDelete(
      context,
      title: 'Xóa gói dịch vụ?',
      message:
          'Gói "${plan.name}" sẽ không còn hiện cho chủ sân chọn. '
          'Chủ sân đã mua gói này vẫn tiếp tục dùng bình thường.',
    );
    if (confirmed) bloc.add(CatalogItemDeleted(plan.id));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return BlocConsumer<PlanListBloc, CatalogListState<SubscriptionPlan>>(
      listenWhen: (previous, current) =>
          current.notice != null && previous.notice != current.notice,
      listener: (context, state) => showCatalogNotice(context, state.notice!),
      builder: (context, state) {
        final bloc = context.read<PlanListBloc>();
        return Scaffold(
          floatingActionButton: FloatingActionButton.extended(
            // Hai tab cùng sống trong TabBarView nên mỗi nút nổi cần hero tag riêng.
            heroTag: 'subscription-plans-fab',
            onPressed: () => _openForm(null),
            icon: const Icon(Icons.add),
            label: const Text('Thêm gói'),
          ),
          body: CatalogListView<SubscriptionPlan>(
            state: state,
            emptyMessage: 'Chưa có gói dịch vụ nào',
            onRefresh: () => _refresh(bloc),
            onLoadMore: () => bloc.add(const CatalogMoreRequested()),
            itemBuilder: (context, plan) => _PlanCard(
              plan: plan,
              deleting: state.deletingId == plan.id,
              onTap: () => _openForm(plan),
              onDelete: () => _delete(plan),
            ),
          ),
        );
      },
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.deleting,
    required this.onTap,
    required this.onDelete,
  });

  final SubscriptionPlan plan;
  final bool deleting;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FcCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: deleting ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(plan.name, style: theme.textTheme.titleMedium),
                  ),
                  if (deleting)
                    const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    IconButton(
                      tooltip: 'Xóa ${plan.name}',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: onDelete,
                    ),
                ],
              ),
              if (plan.tagline != null) Text(plan.tagline!),
              const SizedBox(height: 8),
              Text('${formatVnd(plan.monthlyPrice)} / tháng'),
              Text('${formatVnd(plan.yearlyPrice)} / năm'),
              const SizedBox(height: 8),
              Text(
                'Tối đa ${plan.maxBranches} chi nhánh · ${plan.maxCourts} sân',
              ),
              if (plan.features.isNotEmpty)
                Text('${plan.features.length} tính năng'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  StatusChip(
                    plan.active ? 'Đang bán' : 'Tạm ngưng',
                    highlighted: plan.active,
                  ),
                  if (plan.popular)
                    const StatusChip('Phổ biến', highlighted: true),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
