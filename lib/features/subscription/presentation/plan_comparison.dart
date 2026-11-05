import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../catalog/domain/entities/subscription_plan.dart';

String subscriptionMoney(int? amount) => amount == null
    ? 'Không bán chu kỳ này'
    : '${NumberFormat('#,##0', 'vi').format(amount)} đ';

class PlanComparison extends StatelessWidget {
  const PlanComparison({super.key, required this.plans});
  final List<SubscriptionPlan> plans;
  @override
  Widget build(BuildContext context) => ExpansionTile(
    title: const Text('So sánh gói dịch vụ'),
    children: [
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: [
            const DataColumn(label: Text('Thông tin')),
            for (final plan in plans)
              DataColumn(
                label: SizedBox(
                  width: 180,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(plan.name),
                        if (plan.popular) const Text('Phổ biến'),
                      ],
                    ),
                  ),
                ),
              ),
          ],
          dataRowMinHeight: 64,
          dataRowMaxHeight: 160,
          rows: [
            for (final row in <(String, String Function(SubscriptionPlan))>[
              ('Giá / tháng', (p) => subscriptionMoney(p.monthlyPrice)),
              ('Giá / năm', (p) => subscriptionMoney(p.yearlyPrice)),
              ('Chi nhánh tối đa', (p) => '${p.maxBranches}'),
              ('Sân tối đa', (p) => '${p.maxCourts}'),
              (
                'Quyền lợi',
                (p) => p.features.isEmpty
                    ? 'Chưa có mô tả'
                    : p.features.join('\n'),
              ),
            ])
              DataRow(
                cells: [
                  DataCell(Text(row.$1)),
                  for (final plan in plans)
                    DataCell(
                      SizedBox(
                        width: 180,
                        child: SingleChildScrollView(child: Text(row.$2(plan))),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    ],
  );
}
