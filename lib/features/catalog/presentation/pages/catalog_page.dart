import 'package:flutter/material.dart';

import '../../domain/usecases/save_court_type.dart';
import '../../domain/usecases/save_subscription_plan.dart';
import 'court_types_tab.dart';
import 'subscription_plans_tab.dart';

/// Màn hình super admin quản lý danh mục hệ thống: loại sân và gói dịch vụ SaaS.
/// Cần cung cấp sẵn hai `CatalogListBloc` (loại sân và gói) phía trên cây widget.
class CatalogPage extends StatelessWidget {
  const CatalogPage({
    super.key,
    required this.saveCourtType,
    required this.saveSubscriptionPlan,
  });

  final SaveCourtType saveCourtType;
  final SaveSubscriptionPlan saveSubscriptionPlan;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Danh mục hệ thống'),
          bottom: const _PillTabs(),
        ),
        body: TabBarView(
          children: [
            CourtTypesTab(saveCourtType: saveCourtType),
            SubscriptionPlansTab(savePlan: saveSubscriptionPlan),
          ],
        ),
      ),
    );
  }
}

/// Mock-up pills: the selected tab is a filled accent pill.
class _PillTabs extends StatelessWidget implements PreferredSizeWidget {
  const _PillTabs();

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceContainer,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: TabBar(
          dividerColor: Colors.transparent,
          indicatorSize: TabBarIndicatorSize.tab,
          indicator: BoxDecoration(
            color: colors.primary,
            borderRadius: BorderRadius.circular(999),
          ),
          labelColor: colors.onPrimary,
          unselectedLabelColor: colors.onSurface,
          labelStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          tabs: const [
            Tab(height: 40, text: 'Loại sân'),
            Tab(height: 40, text: 'Gói dịch vụ'),
          ],
        ),
      ),
    );
  }
}
