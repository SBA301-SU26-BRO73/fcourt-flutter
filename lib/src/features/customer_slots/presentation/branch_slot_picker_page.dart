import 'package:flutter/material.dart';

import '../../customer_discovery/domain/discovery_repository.dart';
import '../domain/court_slot.dart';
import '../domain/slot_invalidations.dart';
import '../domain/slot_options.dart';
import '../domain/slot_repository.dart';
import 'slot_picker_screen.dart';
import 'widgets/slot_option_views.dart';
import '../../../../app/theme/slot_picker_palette.dart';

/// Loads the courts of a branch, then shows [SlotPickerScreen] over all of them.
class BranchSlotPickerPage extends StatefulWidget {
  const BranchSlotPickerPage({
    super.key,
    required this.branchId,
    required this.discovery,
    required this.slots,
    this.branchName,
    this.initialCourtId,
    this.date,
    this.onContinue,
    this.invalidationsFor,
  });
  final int branchId;
  final DiscoveryRepository discovery;
  final SlotRepository slots;
  final String? branchName;
  final int? initialCourtId;
  final DateTime? date;
  final void Function(SlotSelection selection, String courtName)? onContinue;
  final SlotInvalidations Function(int courtId)? invalidationsFor;

  @override
  State<BranchSlotPickerPage> createState() => _BranchSlotPickerPageState();
}

class _BranchSlotPickerPageState extends State<BranchSlotPickerPage> {
  late Future<List<Court>> _courts = widget.discovery.courtsOfBranch(
    widget.branchId,
  );

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Court>>(
    future: _courts,
    builder: (context, snapshot) {
      final done = snapshot.connectionState == ConnectionState.done;
      final courts = snapshot.data;
      if (done && courts != null && courts.isNotEmpty) {
        return SlotPickerScreen(
          repository: widget.slots,
          courts: [for (final c in courts) PickerCourt(id: c.id, name: c.name)],
          initialCourtId: widget.initialCourtId,
          branchName: widget.branchName,
          date: widget.date,
          onContinue: widget.onContinue,
          invalidationsFor: widget.invalidationsFor,
        );
      }
      final palette = SlotPickerPalette.of(context);
      final failed = done && courts == null;
      return Scaffold(
        backgroundColor: palette.background,
        appBar: AppBar(
          backgroundColor: palette.background,
          foregroundColor: palette.text,
          title: const Text('Chọn giờ chơi'),
        ),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: !done
              ? const SlotListSkeleton()
              : SlotEmptyState(
                  icon: failed
                      ? Icons.wifi_off_rounded
                      : Icons.sports_score_rounded,
                  title: failed
                      ? 'Không tải được danh sách sân'
                      : 'Chi nhánh chưa có sân hoạt động',
                  actionLabel: 'Thử lại',
                  onAction: () => setState(() {
                    _courts = widget.discovery.courtsOfBranch(widget.branchId);
                  }),
                ),
        ),
      );
    },
  );
}
