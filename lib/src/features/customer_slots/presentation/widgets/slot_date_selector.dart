import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/court_slot.dart';

class SlotDateSelector extends StatelessWidget {
  const SlotDateSelector({
    super.key,
    required this.date,
    required this.onSelected,
  });
  final DateTime date;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    final today = venueToday();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                DateFormat('dd/MM/yyyy').format(date),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            TextButton.icon(
              icon: const Icon(Icons.calendar_month_outlined),
              label: const Text('Chọn ngày'),
              onPressed: () async {
                final last = DateTime(today.year + 2, today.month, today.day);
                final initial = date.isBefore(today)
                    ? today
                    : date.isAfter(last)
                    ? last
                    : date;
                final chosen = await showDatePicker(
                  context: context,
                  initialDate: initial,
                  firstDate: today,
                  lastDate: last,
                  helpText: 'Chọn ngày chơi',
                  cancelText: 'Hủy',
                  confirmText: 'Chọn',
                );
                if (chosen != null) onSelected(chosen);
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var i = 0; i < 8; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _DateCard(
                    date: DateTime(today.year, today.month, today.day + i),
                    selected: date,
                    onSelected: onSelected,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DateCard extends StatelessWidget {
  const _DateCard({
    required this.date,
    required this.selected,
    required this.onSelected,
  });
  final DateTime date, selected;
  final ValueChanged<DateTime> onSelected;
  @override
  Widget build(BuildContext context) {
    final active = slotDateKey(date) == slotDateKey(selected);
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: active,
      label: DateFormat('dd/MM/yyyy').format(date),
      excludeSemantics: true,
      child: Material(
        color: active ? colors.primary : colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          key: ValueKey('slot-date-${slotDateKey(date)}'),
          borderRadius: BorderRadius.circular(16),
          onTap: () => onSelected(date),
          child: Container(
            constraints: const BoxConstraints(minWidth: 72),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: DefaultTextStyle.merge(
              style: TextStyle(
                color: active ? colors.onPrimary : colors.onSurface,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(date.weekday == 7 ? 'CN' : 'T${date.weekday + 1}'),
                  Text(
                    '${date.day}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
