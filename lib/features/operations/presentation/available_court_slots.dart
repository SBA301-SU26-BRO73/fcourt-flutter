import 'package:flutter/material.dart';

import '../../../core/error/failure.dart';
import '../domain/counter.dart';

class AvailableCourtSlots extends StatefulWidget {
  const AvailableCourtSlots({
    super.key,
    required this.repository,
    required this.courtId,
    required this.date,
    required this.onSelected,
  });
  final CounterRepository repository;
  final int courtId;
  final String date;
  final void Function(AvailableSlot) onSelected;
  @override
  State<AvailableCourtSlots> createState() => _AvailableCourtSlotsState();
}

class _AvailableCourtSlotsState extends State<AvailableCourtSlots> {
  late Future<List<AvailableSlot>> _slots = widget.repository.slots(
    widget.courtId,
    widget.date,
  );
  @override
  Widget build(BuildContext context) => FutureBuilder<List<AvailableSlot>>(
    future: _slots,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const LinearProgressIndicator();
      }
      if (snapshot.hasError) {
        return TextButton(
          onPressed: () => setState(
            () => _slots = widget.repository.slots(widget.courtId, widget.date),
          ),
          child: Text(
            snapshot.error is Failure
                ? (snapshot.error as Failure).message
                : 'Không tải được khung giờ. Thử lại.',
          ),
        );
      }
      final slots = snapshot.data ?? [];
      if (slots.isEmpty) return const Text('Chưa có lịch mở sân cho ngày này.');
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: slots
              .map(
                (slot) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Semantics(
                    label:
                        '${slot.start} ${slot.available ? 'Trống' : 'Đã có khách'}',
                    child: OutlinedButton(
                      onPressed: slot.available
                          ? () => widget.onSelected(slot)
                          : null,
                      child: Text(
                        '${slot.start}\n${slot.available ? 'Trống' : 'Đã đặt'}',
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      );
    },
  );
}
