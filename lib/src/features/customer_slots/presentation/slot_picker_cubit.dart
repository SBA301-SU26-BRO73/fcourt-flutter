import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../domain/court_slot.dart';
import '../domain/slot_repository.dart';
import '../domain/slot_invalidations.dart';

/// Transient notice (SnackBar) about a schedule change seen by a background
/// resync. Compared by identity so the same text can be shown twice.
class SlotAlert {
  const SlotAlert(this.message);
  final String message;
}

class SlotPickerState {
  const SlotPickerState({
    required this.date,
    this.slots = const [],
    this.selectedIds = const {},
    this.loading = true,
    this.error,
    this.notice,
    this.alert,
  });
  final DateTime date;
  final List<CourtSlot> slots;
  final Set<int> selectedIds;
  final bool loading;
  final String? error, notice;
  final SlotAlert? alert;
  List<CourtSlot> get selected =>
      slots.where((s) => selectedIds.contains(s.id)).toList();
  int get totalMinor =>
      selected.fold(0, (total, slot) => total + slot.priceMinor);
}

class SlotPickerCubit extends Cubit<SlotPickerState> {
  SlotPickerCubit(
    this.repository, {
    required this.courtId,
    DateTime? date,
    DateTime Function()? now,
    SlotInvalidations? invalidations,
    this.pollInterval = const Duration(seconds: 15),
    this.healthyPollFactor = 4,
  }) : _invalidations = invalidations,
       _now = now ?? DateTime.now,
       super(SlotPickerState(date: date ?? venueToday(now?.call()))) {
    _subscription = invalidations?.changes.listen((change) {
      if (change == null || change.date == slotDateKey(state.date)) {
        _resync();
      }
    });
    // Safety resync: Redis Pub/Sub is not durable, so even a healthy socket is
    // reconciled, just less often (pollInterval * healthyPollFactor).
    _poll = Timer.periodic(pollInterval, (_) {
      if (_invalidations?.connected == true &&
          ++_quietTicks < healthyPollFactor) {
        return;
      }
      _quietTicks = 0;
      _resync();
    });
    _expiry = Timer.periodic(
      const Duration(seconds: 15),
      (_) => expirePastSlots(),
    );
  }
  final SlotRepository repository;
  final int courtId;
  final Duration pollInterval;
  final int healthyPollFactor;
  int _quietTicks = 0;
  final DateTime Function() _now;
  late final Timer _expiry;
  int _revision = 0;
  final SlotInvalidations? _invalidations;
  StreamSubscription<SlotChange?>? _subscription;
  late final Timer _poll;
  bool _resyncBusy = false, _resyncAgain = false;

  Future<void> _resync() async {
    if (isClosed) return;
    if (_resyncBusy || state.loading) {
      _resyncAgain = true;
      return;
    }
    _resyncBusy = true;
    try {
      do {
        _resyncAgain = false;
        await _load(null, silent: true);
      } while (_resyncAgain && !isClosed && !state.loading);
    } finally {
      _resyncBusy = false;
    }
  }

  Future<void> refresh([DateTime? date]) async {
    await _load(date);
    if (_resyncAgain && !isClosed) await _resync();
  }

  Future<void> _load(DateTime? date, {bool silent = false}) async {
    final revision = ++_revision;
    final nextDate = date ?? state.date;
    final previous = slotDateKey(nextDate) == slotDateKey(state.date)
        ? state.selectedIds
        : <int>{};
    if (!silent) emit(SlotPickerState(date: nextDate));
    try {
      final response = await repository.getSlots(courtId, nextDate);
      if (isClosed || revision != _revision) return;
      final slots = response
          .map((s) => s.isPast(nextDate, _now()) ? s.expired : s)
          .toList();
      final selectedBefore = silent ? state.selectedIds : previous;
      final alert = silent && !state.loading && state.error == null
          ? slotChangeAlert(state.slots, slots)
          : null;
      final ids = slots
          .where(
            (s) =>
                s.status == SlotStatus.available &&
                selectedBefore.contains(s.id),
          )
          .map((s) => s.id)
          .toSet();
      emit(
        SlotPickerState(
          date: nextDate,
          slots: List.unmodifiable(slots),
          selectedIds: Set.unmodifiable(ids),
          loading: false,
          notice: ids.length < selectedBefore.length
              ? 'Một số khung giờ đã thay đổi. Vui lòng chọn lại.'
              : null,
          alert: alert == null ? null : SlotAlert(alert),
        ),
      );
    } catch (error) {
      if (isClosed || revision != _revision || silent) return;
      emit(
        SlotPickerState(
          date: nextDate,
          loading: false,
          error: error is Failure
              ? error.message
              : 'Không thể tải lịch sân. Vui lòng thử lại.',
        ),
      );
    }
  }

  /// Describes the first slot whose status changed between two schedule reads,
  /// e.g. "Khung giờ 18:00 vừa có người giữ chỗ". Null when nothing changed.
  static String? slotChangeAlert(
    List<CourtSlot> before,
    List<CourtSlot> after,
  ) {
    final previous = {for (final s in before) s.id: s.status};
    final changed = <CourtSlot>[];
    for (final slot in after) {
      final was = previous[slot.id];
      if (was == null || was == slot.status) continue;
      if ({
        was,
        slot.status,
      }.any((v) => v == SlotStatus.expired || v == SlotStatus.unknown)) {
        continue;
      }
      changed.add(slot);
    }
    if (changed.isEmpty) return null;
    final first = changed.first;
    final time =
        '${((first.startMinute ~/ 60) % 24).toString().padLeft(2, '0')}:'
        '${(first.startMinute % 60).toString().padLeft(2, '0')}';
    final what = switch (first.status) {
      SlotStatus.hold => 'vừa có người giữ chỗ',
      SlotStatus.booked => 'vừa được đặt',
      SlotStatus.privateEvent => 'vừa được chủ sân Bao sân',
      SlotStatus.outOfService => 'vừa tạm ngừng phục vụ (bảo trì)',
      _ => 'vừa trống lại',
    };
    final more = changed.length > 1
        ? ' (và ${changed.length - 1} khung giờ khác)'
        : '';
    return 'Khung giờ $time $what$more';
  }

  /// Returns true only when an available slot was actually toggled.
  bool toggle(int slotId) {
    expirePastSlots();
    if (state.loading || state.error != null) return false;
    final slot = state.slots.where((s) => s.id == slotId).firstOrNull;
    if (slot == null || slot.status != SlotStatus.available) return false;
    final selected = {...state.selectedIds};
    if (!selected.remove(slotId)) selected.add(slotId);
    emit(
      SlotPickerState(
        date: state.date,
        slots: state.slots,
        selectedIds: Set.unmodifiable(selected),
        loading: false,
      ),
    );
    return true;
  }

  void clear() {
    if (state.loading || state.error != null) return;
    emit(SlotPickerState(date: state.date, slots: state.slots, loading: false));
  }

  void expirePastSlots() {
    if (state.loading || state.error != null || isClosed) return;
    final expired = state.slots
        .where(
          (s) => s.status != SlotStatus.expired && s.isPast(state.date, _now()),
        )
        .map((s) => s.id)
        .toSet();
    if (expired.isEmpty) return;
    emit(
      SlotPickerState(
        date: state.date,
        loading: false,
        slots: List.unmodifiable(
          state.slots.map((s) => expired.contains(s.id) ? s.expired : s),
        ),
        selectedIds: Set.unmodifiable(state.selectedIds.difference(expired)),
        notice: state.selectedIds.intersection(expired).isNotEmpty
            ? 'Khung giờ đã bắt đầu được bỏ khỏi lựa chọn.'
            : state.notice,
      ),
    );
  }

  SlotSelection get selection =>
      SlotSelection(courtId: courtId, date: state.date, slots: state.selected);

  @override
  Future<void> close() async {
    _revision++;
    _poll.cancel();
    await _subscription?.cancel();
    await _invalidations?.close();
    _expiry.cancel();
    return super.close();
  }
}
