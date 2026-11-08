import 'package:flutter/material.dart';

import '../../../core/error/failure.dart';
import '../domain/counter.dart';
import '../domain/schedule.dart';

class AvailableCourtSlots extends StatefulWidget {
  const AvailableCourtSlots({
    super.key,
    required this.repository,
    required this.courtId,
    required this.date,
    required this.onSelected,
    this.sessions = const [],
    this.refreshVersion = 0,
  });
  final CounterRepository repository;
  final int courtId;
  final String date;
  final void Function(AvailableSlot) onSelected;
  final List<CourtSession> sessions;
  final int refreshVersion;
  @override
  State<AvailableCourtSlots> createState() => _AvailableCourtSlotsState();
}

class _AvailableCourtSlotsState extends State<AvailableCourtSlots> {
  late Future<List<AvailableSlot>> _slots = widget.repository.slots(
    widget.courtId,
    widget.date,
  );
  @override
  void didUpdateWidget(covariant AvailableCourtSlots oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.repository != oldWidget.repository ||
        widget.courtId != oldWidget.courtId ||
        widget.date != oldWidget.date ||
        widget.refreshVersion != oldWidget.refreshVersion) {
      _slots = widget.repository.slots(widget.courtId, widget.date);
    }
  }

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
          children: slots.map((slot) {
            final session = widget.sessions
                .where(
                  (s) =>
                      s.date == widget.date &&
                      [
                        'CONFIRMED',
                        'CHECKED_IN',
                        'PENDING_PAYMENT',
                        'AWAITING_CONFIRMATION',
                      ].contains(s.status) &&
                      s.start.compareTo(slot.start) <= 0 &&
                      (s.end == '00:00' || s.end.compareTo(slot.start) > 0),
                )
                .firstOrNull;
            final free = slot.available && session == null;
            final playing = session?.playing == true;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Semantics(
                label:
                    '${slot.start} ${free
                        ? 'Trống'
                        : playing
                        ? 'Đang chơi'
                        : 'Đã có khách'}',
                child: OutlinedButton(
                  style: playing
                      ? OutlinedButton.styleFrom(
                          disabledBackgroundColor: const Color(0xFFB3261E),
                          disabledForegroundColor: Colors.white,
                        )
                      : null,
                  onPressed: free ? () => widget.onSelected(slot) : null,
                  child: Text(
                    '${slot.start}\n${free
                        ? 'Trống'
                        : playing
                        ? 'Đang chơi · ${session!.name.isEmpty ? 'Khách vãng lai' : session.name}'
                        : 'Đã đặt'}',
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      );
    },
  );
}
