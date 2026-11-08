/// One public schedule invalidation pushed by the backend (SCRUM-108).
///
/// [type] is one of SLOT_CHANGED, HOLD_CREATED, HOLD_RELEASED, HOLD_EXPIRED,
/// LOCK_CREATED, LOCK_REMOVED; [lockType] is OUT_OF_SERVICE or PRIVATE_EVENT
/// and only accompanies LOCK_* events. It only selects the notice wording: the
/// slot colors always come from a fresh HTTP schedule.
class SlotChange {
  const SlotChange(this.date, {this.type = 'SLOT_CHANGED', this.lockType});
  final String date;
  final String type;
  final String? lockType;
  bool get isFullCourtLock =>
      type == 'LOCK_CREATED' && lockType == 'PRIVATE_EVENT';
}

/// A change requests resync of its day; null resyncs after (re)connection.
abstract class SlotInvalidations {
  Stream<SlotChange?> get changes;

  /// True while the realtime socket is connected and subscribed. When false the
  /// screen keeps polling at its normal pace.
  bool get connected;
  Future<void> close();
}
