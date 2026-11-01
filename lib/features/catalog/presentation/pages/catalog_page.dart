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
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Loại sân'),
              Tab(text: 'Gói dịch vụ'),
            ],
          ),
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
