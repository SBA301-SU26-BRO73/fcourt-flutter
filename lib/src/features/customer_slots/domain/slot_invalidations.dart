/// A date key requests resync of that day; null resyncs after (re)connection.
abstract class SlotInvalidations {
  Stream<String?> get changes;
  Future<void> close();
}
