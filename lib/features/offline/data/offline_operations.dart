import '../../../core/error/failure.dart';
import '../../operations/domain/schedule.dart';
import 'offline_coordinator.dart';
import 'offline_store.dart';

class OfflineOperations implements OperationsRepository {
  OfflineOperations(this.remote, this.offline);
  final OperationsRepository remote;
  final OfflineCoordinator offline;
  final Set<String> _offlinePreviews = {};
  @override
  Future<BranchSchedule> today() => remote.today();
  @override
  Future<BranchSchedule> week(String start, String end) =>
      remote.week(start, end);
  @override
  Future<TicketPreview> preview(String code) async {
    final hash = ticketHash(code);
    _offlinePreviews.remove(hash);
    try {
      return await remote.preview(code);
    } on Failure catch (e) {
      if (e is! NetworkFailure &&
          !(e is ServerFailure && (e.statusCode ?? 0) >= 500)) {
        rethrow;
      }
      final ticket = await offline.preview(code);
      final scope = await offline.scope();
      _offlinePreviews.add(hash);
      return TicketPreview(
        bookingId: ticket.bookingId,
        branchId: scope.branchId,
        courtName: ticket.court,
        date: scope.date,
        start: ticket.from
            .add(const Duration(minutes: 15, hours: 7))
            .toIso8601String()
            .substring(11, 16),
        end: ticket.until
            .add(const Duration(hours: 7))
            .toIso8601String()
            .substring(11, 16),
        name: ticket.name,
        offline: true,
      );
    }
  }

  @override
  Future<int> checkIn(String code, String key, {bool manual = false}) async {
    final hash = ticketHash(code);
    if (_offlinePreviews.contains(hash)) {
      int id;
      try {
        id = await offline.admit(code, key);
      } on Failure {
        rethrow;
      } catch (_) {
        throw const UnknownFailure(
          'Không ghi được vé trên thiết bị. Chưa xác nhận nhận sân.',
        );
      }
      _offlinePreviews.remove(hash);
      return id;
    }
    // An uncertain online command must retry its original key, never become a local success.
    return remote.checkIn(code, key, manual: manual);
  }
}
