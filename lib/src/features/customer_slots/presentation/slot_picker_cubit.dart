import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../domain/court_slot.dart';
import '../domain/slot_repository.dart';

class SlotPickerState {
  const SlotPickerState({
    required this.date,
    this.slots = const [],
    this.selectedIds = const {},
    this.loading = true,
    this.error,
    this.notice,
  });
  final DateTime date;
  final List<CourtSlot> slots;
  final Set<int> selectedIds;
  final bool loading;
  final String? error, notice;
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
  }) : _now = now ?? DateTime.now,
       super(SlotPickerState(date: date ?? venueToday(now?.call()))) {
    _expiry = Timer.periodic(
      const Duration(seconds: 15),
      (_) => expirePastSlots(),
    );
  }
  final SlotRepository repository;
  final int courtId;
  final DateTime Function() _now;
  late final Timer _expiry;
  int _revision = 0;

  Future<void> refresh([DateTime? date]) async {
    final revision = ++_revision;
    final nextDate = date ?? state.date;
    final previous = slotDateKey(nextDate) == slotDateKey(state.date)
        ? state.selectedIds
        : <int>{};
    emit(SlotPickerState(date: nextDate));
    try {
      final response = await repository.getSlots(courtId, nextDate);
      if (isClosed || revision != _revision) return;
      final slots = response
          .map((s) => s.isPast(nextDate, _now()) ? s.expired : s)
          .toList();
      final ids = slots
          .where(
            (s) => s.status == SlotStatus.available && previous.contains(s.id),
          )
          .map((s) => s.id)
          .toSet();
      emit(
        SlotPickerState(
          date: nextDate,
          slots: List.unmodifiable(slots),
          selectedIds: Set.unmodifiable(ids),
          loading: false,
          notice: ids.length < previous.length
              ? 'Một số khung giờ đã thay đổi. Vui lòng chọn lại.'
              : null,
        ),
      );
    } catch (error) {
      if (isClosed || revision != _revision) return;
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
  Future<void> close() {
    _revision++;
    _expiry.cancel();
    return super.close();
  }
}
