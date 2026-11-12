import 'package:flutter/material.dart';

import '../domain/schedule.dart';
import '../domain/schedule_cells.dart';
import 'schedule_page.dart';
import '../../../app/theme/tokens.dart';

class WeekBoard extends StatefulWidget {
  const WeekBoard({super.key, required this.data, required this.start});
  final BranchSchedule data;
  final DateTime start;
  @override
  State<WeekBoard> createState() => _WeekBoardState();
}

class _WeekBoardState extends State<WeekBoard> {
  int? _court;
  @override
  Widget build(BuildContext context) {
    if (widget.data.courts.isEmpty) {
      return const Text('Chưa có sân trong tuần này.');
    }
    final court =
        widget.data.courts.where((c) => c.id == _court).firstOrNull ??
        widget.data.courts.first;
    final byTime = scheduleCells(court.sessions);
    final colors = Theme.of(context).colorScheme;
    final days = List.generate(7, (i) => widget.start.add(Duration(days: i)));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<int>(
          initialValue: court.id,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Sân'),
          items: widget.data.courts
              .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
              .toList(),
          onChanged: (id) => setState(() => _court = id),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'Cuộn ngang để xem đủ 7 ngày, cuộn dọc để xem giờ. Chạm ô có khách để đọc đầy đủ.',
          ),
        ),
        SizedBox(
          height: 560,
          child: SingleChildScrollView(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Table(
                defaultColumnWidth: const FixedColumnWidth(160),
                columnWidths: const {0: FixedColumnWidth(64)},
                border: TableBorder.all(color: colors.outlineVariant),
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                children: [
                  TableRow(
                    decoration: BoxDecoration(color: colors.surfaceContainer),
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(8),
                        child: Text('Giờ'),
                      ),
                      ...days.map(
                        (d) => Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            'Thứ ${d.weekday + 1 == 8 ? 'CN' : d.weekday + 1}\n${calendarDate(d)}',
                          ),
                        ),
                      ),
                    ],
                  ),
                  for (var i = 0; i < 48; i++)
                    _row(
                      context,
                      days,
                      byTime,
                      '${(i ~/ 2).toString().padLeft(2, '0')}:${i.isEven ? '00' : '30'}',
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  TableRow _row(
    BuildContext context,
    List<DateTime> days,
    Map<String, List<CourtSession>> byTime,
    String time,
  ) => TableRow(
    children: [
      Padding(padding: const EdgeInsets.all(8), child: Text(time)),
      ...days.map((day) {
        final sessions = byTime['${calendarDate(day)}:$time'] ?? [];
        if (sessions.isEmpty) {
          return const SizedBox(
            height: 64,
            child: Center(
              child: Text('—', semanticsLabel: 'Không có ca đặt sân'),
            ),
          );
        }
        final ending = sessions.any((s) => s.endingSoon);
        final playing = sessions.any((s) => s.playing);
        final fc = context.fc;
        final color = ending
            ? fc.warning.container
            : playing
            ? fc.danger.container
            : Theme.of(context).colorScheme.secondaryContainer;
        final ink = ending
            ? fc.warning.color
            : playing
            ? fc.danger.color
            : Theme.of(context).colorScheme.onSecondaryContainer;
        final text = sessions
            .map(
              (s) =>
                  '${s.name.isEmpty ? 'Khách vãng lai' : s.name}\n${s.start}–${s.end}\n${sessionLabel(s.status)}${s.lateCheckIn ? ' · Trễ nhận sân' : ''}',
            )
            .join('\n');
        return Material(
          color: color,
          child: InkWell(
            onTap: () => showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(calendarDate(day)),
                content: SingleChildScrollView(child: Text(text)),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Đóng'),
                  ),
                ],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (ending) const EndingSoonIndicator(),
                  Text(text, style: TextStyle(color: ink)),
                ],
              ),
            ),
          ),
        );
      }),
    ],
  );
}

class EndingSoonIndicator extends StatefulWidget {
  const EndingSoonIndicator({super.key});
  @override
  State<EndingSoonIndicator> createState() => _EndingSoonIndicatorState();
}

class _EndingSoonIndicatorState extends State<EndingSoonIndicator>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      _controller.value = 1;
    } else {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      FadeTransition(
        opacity: Tween(begin: 0.4, end: 1.0).animate(_controller),
        child: Icon(Icons.warning_amber, color: context.fc.warning.color),
      ),
      Flexible(
        child: Text(
          'Sắp hết giờ',
          style: TextStyle(
            color: context.fc.warning.color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    ],
  );
}
