import '../../../core/error/failure.dart';
import '../../operations/domain/schedule.dart';
import 'offline_coordinator.dart';
import 'offline_store.dart';

class OfflineOperations implements OperationsRepository {
  OfflineOperations(this.remote, this.offline);
  OfflineOperations.cached(this.offline) : remote = null;
  final OperationsRepository? remote;
  final OfflineCoordinator offline;
  final Set<String> _offlinePreviews = {};
  @override
  Future<BranchSchedule> today() =>
      remote == null ? Future.error(const NetworkFailure()) : remote!.today();
  @override
  Future<BranchSchedule> week(String start, String end) => remote == null
      ? Future.error(const NetworkFailure())
      : remote!.week(start, end);
  @override
  Future<TicketPreview> preview(String code) async {
    final hash = ticketHash(code);
    _offlinePreviews.remove(hash);
    if (remote == null) return _cachedPreview(code, hash);
    try {
      return await remote!.preview(code);
    } on Failure catch (e) {
      if (e is! NetworkFailure &&
          !(e is ServerFailure && (e.statusCode ?? 0) >= 500)) {
        rethrow;
      }
      return _cachedPreview(code, hash);
    }
  }

  Future<TicketPreview> _cachedPreview(String code, String hash) async {
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
    if (remote == null) {
      throw const NetworkFailure('Kiểm tra lại vé offline trước khi nhận sân');
    }
    return remote!.checkIn(code, key, manual: manual);
  }
}
