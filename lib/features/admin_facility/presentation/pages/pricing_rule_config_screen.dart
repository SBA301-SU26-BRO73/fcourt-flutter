import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../admin_dashboard/presentation/widgets/owner_ui.dart';
import '../../domain/entities/pricing_rule.dart';
import '../../domain/entities/pricing_rules.dart';
import '../bloc/pricing_rule_bloc.dart';
import '../widgets/facility_formatters.dart';
import '../widgets/pricing_rule_sheet.dart';
import '../widgets/pricing_timeline_bar.dart';

/// SCRUM-81/83: cấu hình giá giờ cao điểm/thấp điểm của một sân, tách tab
/// "Giá ngày thường (T2-T6)" và "Giá cuối tuần (T7-CN)".
class PricingRuleConfigScreen extends StatelessWidget {
  const PricingRuleConfigScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<PricingRuleBloc, PricingRuleState>(
      listenWhen: (p, c) => c.notice != null && p.notice != c.notice,
      listener: (context, state) {
        final notice = state.notice!;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(notice.message),
              backgroundColor: notice.isError
                  ? Theme.of(context).colorScheme.error
                  : null,
            ),
          );
      },
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Cấu hình giá'),
            bottom: const TabBar(
              labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              unselectedLabelStyle: TextStyle(fontSize: 12),
              tabs: [
                Tab(key: Key('tab-weekday'), text: 'Giá ngày thường (T2-T6)'),
                Tab(key: Key('tab-weekend'), text: 'Giá cuối tuần (T7-CN)'),
              ],
            ),
          ),
          body: BlocBuilder<PricingRuleBloc, PricingRuleState>(
            builder: (context, state) {
              switch (state.status) {
                case PricingRuleStatus.loading:
                  return const Center(child: CircularProgressIndicator());
                case PricingRuleStatus.loadFailure:
                  return OwnerMessage(
                    icon: Icons.cloud_off_outlined,
                    text: state.message ?? 'Không tải được cấu hình giá',
                    action: 'Thử lại',
                    onAction: () => context.read<PricingRuleBloc>().add(
                      const PricingRuleStarted(),
                    ),
                  );
                case PricingRuleStatus.ready:
                  return TabBarView(
                    children: [
                      _RulesTab(state: state, weekend: false),
                      _RulesTab(state: state, weekend: true),
                    ],
                  );
              }
            },
          ),
        ),
      ),
    );
  }
}

/// "06:00–17:00 · 100.000 đ/giờ" cho từng khung của một tab.
List<String> pricingSummaryLines(List<PricingRule> rules) => [
  for (final rule in rules)
    '${rule.peak ? 'Cao điểm' : 'Thấp điểm'} '
        '${rule.startTime.format()}–${rule.endTime.format()}: '
        '${formatVnd(rule.pricePerHour)}/giờ',
];

class _RulesTab extends StatelessWidget {
  const _RulesTab({required this.state, required this.weekend});

  final PricingRuleState state;
  final bool weekend;

  Future<void> _edit(BuildContext context, {PricingRule? rule}) async {
    final bloc = context.read<PricingRuleBloc>();
    final draft = await showPricingRuleSheet(
      context,
      existing: state.rules,
      defaultDays: weekend ? weekendDays : weekdayDays,
      editing: rule,
    );
    if (draft == null) return;
    bloc.add(PricingRuleSaved(draft, ruleId: rule?.id));
  }

  Future<void> _confirmDelete(BuildContext context, PricingRule rule) async {
    final bloc = context.read<PricingRuleBloc>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa khung giá?'),
        content: Text(
          'Khung "${rule.name}" '
          '(${rule.startTime.format()}–${rule.endTime.format()}) sẽ bị xóa; '
          'các giờ này quay về giá mặc định của sân.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed == true) bloc.add(PricingRuleDeleted(rule.id));
  }

  Future<void> _copyToWeekend(BuildContext context) async {
    final bloc = context.read<PricingRuleBloc>();
    final multiplier = await showDialog<double>(
      context: context,
      builder: (_) => const _CopyDialog(),
    );
    if (multiplier == null) return;
    bloc.add(PricingRuleCopyToWeekendRequested(multiplier: multiplier));
  }

  @override
  Widget build(BuildContext context) {
    final rules = rulesForTab(state.rules, weekend: weekend);
    final weekdayRules = rulesForTab(state.rules, weekend: false);
    final weekendRules = rulesForTab(state.rules, weekend: true);
    final colors = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(ownerPad, 14, ownerPad, 32),
      children: [
        Text(
          state.court?.name ?? '',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -.7,
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        OwnerNote(
          state.court?.defaultPricePerHour == null
              ? 'Giá mặc định: chưa đặt'
              : 'Giá mặc định: '
                    '${formatVnd(state.court!.defaultPricePerHour!)}/giờ',
        ),
        const SizedBox(height: 16),
        _SummaryCard(weekday: weekdayRules, weekend: weekendRules),
        OwnerSectionTitle(
          weekend ? 'Dải giá Thứ 7 / Chủ nhật' : 'Dải giá Thứ 2 – Thứ 6',
        ),
        OwnerCard(
          padding: const EdgeInsets.all(16),
          child: PricingTimelineBar(
            rules: rules,
            onSegmentTap: (rule) => _edit(context, rule: rule),
          ),
        ),
        const SizedBox(height: 16),
        if (rules.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: OwnerNote(
              'Chưa có khung giá. Các giờ này dùng giá mặc định của sân.',
              key: Key('pricing-empty'),
            ),
          ),
        for (final rule in rules)
          _RuleTile(
            rule: rule,
            busy: state.busy,
            onEdit: () => _edit(context, rule: rule),
            onDelete: () => _confirmDelete(context, rule),
          ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            OwnerPillButton(
              key: Key(weekend ? 'add-weekend-rule' : 'add-weekday-rule'),
              label: 'Thêm khung giá',
              icon: Icons.add,
              fontSize: 12,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              onPressed: state.busy ? null : () => _edit(context),
            ),
            if (weekend)
              OwnerPillButton(
                key: const Key('copy-to-weekend'),
                label: 'Sao chép cấu hình ngày thường',
                icon: Icons.copy_all_outlined,
                filled: false,
                fontSize: 12,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                onPressed: state.busy || weekdayRules.isEmpty
                    ? null
                    : () => _copyToWeekend(context),
              ),
          ],
        ),
        if (weekend && weekdayRules.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: OwnerNote(
              'Hãy cấu hình giá ngày thường trước để sao chép sang cuối tuần.',
            ),
          ),
        if (state.busy)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: LinearProgressIndicator(),
          ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.weekday, required this.weekend});

  final List<PricingRule> weekday;
  final List<PricingRule> weekend;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    Widget group(String title, List<PricingRule> rules) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        if (rules.isEmpty)
          const OwnerNote('Dùng giá mặc định')
        else
          for (final line in pricingSummaryLines(rules)) OwnerNote(line),
      ],
    );
    return OwnerCard(
      key: const Key('pricing-summary'),
      color: colors.primaryContainer,
      bordered: false,
      radius: 23,
      padding: const EdgeInsets.all(18),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tóm tắt biểu giá',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            group('Ngày thường (T2-T6)', weekday),
            const SizedBox(height: 10),
            group('Cuối tuần (T7-CN)', weekend),
          ],
        ),
      ),
    );
  }
}

class _RuleTile extends StatelessWidget {
  const _RuleTile({
    required this.rule,
    required this.busy,
    required this.onEdit,
    required this.onDelete,
  });

  final PricingRule rule;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final days = rule.dayType == PricingDayType.all
        ? ' · ${rule.daysOfWeek.map((d) => dayLabels[d]).join(', ')}'
        : '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: OwnerCard(
        key: Key('pricing-rule-${rule.id}'),
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
        onTap: busy ? null : onEdit,
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: rule.peak ? peakColor : offPeakColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rule.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  OwnerNote(
                    '${rule.startTime.format()}–${rule.endTime.format()} · '
                    '${formatVnd(rule.pricePerHour)}/giờ$days',
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Xóa khung giá',
              icon: const Icon(Icons.delete_outline),
              onPressed: busy ? null : onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class _CopyDialog extends StatefulWidget {
  const _CopyDialog();

  @override
  State<_CopyDialog> createState() => _CopyDialogState();
}

class _CopyDialogState extends State<_CopyDialog> {
  final _percent = TextEditingController(text: '0');

  @override
  void dispose() {
    _percent.dispose();
    super.dispose();
  }

  /// Phần trăm chênh lệch so với giá ngày thường; > -100 để giá còn dương.
  int? get _value {
    final value = int.tryParse(_percent.text.trim());
    return value != null && value > -100 && value <= 1000 ? value : null;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Sao chép sang cuối tuần'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Mọi khung giá cuối tuần hiện có sẽ bị thay bằng bản sao khung '
            'giá ngày thường. Nhập mức chênh lệch giá để chỉnh nhanh.',
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('copy-percent'),
            controller: _percent,
            keyboardType: const TextInputType.numberWithOptions(signed: true),
            decoration: InputDecoration(
              labelText: 'Chênh lệch so với ngày thường',
              suffixText: '%',
              errorText: _value == null ? 'Nhập số từ -99 đến 1000' : null,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Hủy'),
        ),
        FilledButton(
          key: const Key('copy-confirm'),
          onPressed: _value == null
              ? null
              : () => Navigator.of(context).pop((100 + _value!) / 100),
          child: const Text('Sao chép'),
        ),
      ],
    );
  }
}
