import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/entities/clock_time.dart';
import '../../domain/entities/pricing_rule.dart';
import '../../domain/entities/pricing_rules.dart';
import 'facility_formatters.dart';

/// Thứ tự hiển thị: T2 ... T7, CN (chỉ số backend: 0 = CN).
const _chipOrder = [1, 2, 3, 4, 5, 6, 0];

/// SCRUM-81/83: BottomSheet thêm/sửa khung giá. Trả về [PricingRuleDraft] khi
/// lưu, `null` khi đóng. [existing] dùng để báo chồng lấn ngay khi chọn giờ.
Future<PricingRuleDraft?> showPricingRuleSheet(
  BuildContext context, {
  required List<PricingRule> existing,
  required List<int> defaultDays,
  PricingRule? editing,
}) => showModalBottomSheet<PricingRuleDraft>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _PricingRuleSheet(
    existing: existing,
    defaultDays: defaultDays,
    editing: editing,
  ),
);

class _PricingRuleSheet extends StatefulWidget {
  const _PricingRuleSheet({
    required this.existing,
    required this.defaultDays,
    required this.editing,
  });

  final List<PricingRule> existing;
  final List<int> defaultDays;
  final PricingRule? editing;

  @override
  State<_PricingRuleSheet> createState() => _PricingRuleSheetState();
}

class _PricingRuleSheetState extends State<_PricingRuleSheet> {
  late final TextEditingController _name;
  late final TextEditingController _price;
  late ClockTime _start;
  late ClockTime _end;
  late bool _peak;
  late Set<int> _days;

  @override
  void initState() {
    super.initState();
    final rule = widget.editing;
    _peak = rule?.peak ?? true;
    _name = TextEditingController(
      text: rule?.name ?? (_peak ? 'Giờ cao điểm' : 'Giờ thấp điểm'),
    );
    _price = TextEditingController(text: rule?.pricePerHour.toString() ?? '');
    _start = rule?.startTime ?? const ClockTime(17, 0);
    _end = rule?.endTime ?? const ClockTime(21, 0);
    _days = {...(rule?.daysOfWeek ?? widget.defaultDays)};
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    super.dispose();
  }

  PricingRuleDraft get _draft => PricingRuleDraft(
    name: _name.text,
    startTime: _start,
    endTime: _end,
    pricePerHour: int.tryParse(_price.text) ?? 0,
    peak: _peak,
    daysOfWeek: _days.toList()..sort(),
  );

  String? get _problem {
    final draft = _draft;
    final issue = validatePricingDraft(draft);
    if (issue != null) return issue.message;
    final clash = findPricingConflict(
      widget.existing,
      draft,
      exceptId: widget.editing?.id,
    );
    if (clash == null) return null;
    return 'Khung giờ trùng với "${clash.name}" '
        '(${clash.startTime.format()}–${clash.endTime.format()})';
  }

  Future<void> _pick({required bool start}) async {
    final picked = await pickClockTime(
      context,
      initial: start ? _start : _end,
      helpText: start ? 'Giờ bắt đầu' : 'Giờ kết thúc',
    );
    if (picked == null) return;
    setState(() => start ? _start = picked : _end = picked);
  }

  @override
  Widget build(BuildContext context) {
    final problem = _problem;
    // Chưa nhập giá thì chưa báo lỗi giá, tránh cảnh báo ngay khi mở form.
    final showProblem =
        problem != null &&
        !(_price.text.isEmpty &&
            validatePricingDraft(_draft) == PricingRuleIssue.invalidPrice);
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.editing == null ? 'Thêm khung giá' : 'Sửa khung giá',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('pricing-name'),
              controller: _name,
              maxLength: 100,
              decoration: const InputDecoration(labelText: 'Tên khung giá'),
              onChanged: (_) => setState(() {}),
            ),
            Row(
              children: [
                Expanded(
                  child: _TimeField(
                    key: const Key('pricing-start'),
                    label: 'Giờ bắt đầu',
                    time: _start,
                    onTap: () => _pick(start: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TimeField(
                    key: const Key('pricing-end'),
                    label: 'Giờ kết thúc',
                    time: _end,
                    onTap: () => _pick(start: false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('pricing-price'),
              controller: _price,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(8),
              ],
              decoration: const InputDecoration(
                labelText: 'Giá mỗi giờ',
                suffixText: 'đ/giờ',
              ),
              onChanged: (_) => setState(() {}),
            ),
            SwitchListTile(
              key: const Key('pricing-peak'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Giờ cao điểm'),
              subtitle: const Text('Tắt = giờ thấp điểm'),
              value: _peak,
              onChanged: (value) => setState(() => _peak = value),
            ),
            const Text('Ngày áp dụng'),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              children: [
                for (final day in _chipOrder)
                  FilterChip(
                    key: Key('pricing-day-$day'),
                    label: Text(dayLabels[day]),
                    selected: _days.contains(day),
                    onSelected: (on) =>
                        setState(() => on ? _days.add(day) : _days.remove(day)),
                  ),
              ],
            ),
            if (showProblem) ...[
              const SizedBox(height: 12),
              Container(
                key: const Key('pricing-sheet-warning'),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: scheme.error),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        problem,
                        style: TextStyle(color: scheme.onErrorContainer),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('pricing-save'),
                onPressed: problem == null
                    ? () => Navigator.of(context).pop(_draft)
                    : null,
                child: const Text('Lưu khung giá'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({
    super.key,
    required this.label,
    required this.time,
    required this.onTap,
  });

  final String label;
  final ClockTime time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: const Icon(Icons.access_time),
      ),
      child: Text(time.format()),
    ),
  );
}
