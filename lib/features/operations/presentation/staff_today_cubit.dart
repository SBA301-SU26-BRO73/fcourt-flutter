import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/failure.dart';
import '../../../core/network/command_key.dart';
import '../domain/schedule.dart';

/// Một dòng đơn hôm nay kèm tên sân, đã sắp theo giờ bắt đầu.
class TodayOrder {
  const TodayOrder(this.courtName, this.session);
  final String courtName;
  final CourtSession session;
}

class StaffTodayState {
  const StaffTodayState({
    this.orders = const [],
    this.loading = false,
    this.error,
    this.pending = const {},
    this.notice,
    this.noticeIsError = false,
    this.noticeVersion = 0,
  });
  final List<TodayOrder> orders;
  final bool loading;
  final String? error;

  /// Mã đơn đang gửi lệnh nhận sân.
  final Set<int> pending;

  /// Thông báo ngắn sau khi nhận sân; [noticeVersion] đổi để UI chỉ hiện một lần.
  final String? notice;
  final bool noticeIsError;
  final int noticeVersion;

  StaffTodayState copyWith({
    List<TodayOrder>? orders,
    bool? loading,
    String? error,
    bool clearError = false,
    Set<int>? pending,
    String? notice,
    bool noticeIsError = false,
  }) => StaffTodayState(
    orders: orders ?? this.orders,
    loading: loading ?? this.loading,
    error: clearError ? null : (error ?? this.error),
    pending: pending ?? this.pending,
    notice: notice ?? this.notice,
    noticeIsError: notice == null ? this.noticeIsError : noticeIsError,
    noticeVersion: notice == null ? noticeVersion : noticeVersion + 1,
  );
}

class StaffTodayCubit extends Cubit<StaffTodayState> {
  StaffTodayCubit(this.repository) : super(const StaffTodayState());
  final OperationsRepository repository;

  // Khóa lệnh theo đơn: gửi lại sau lỗi mạng dùng đúng khóa cũ để không nhận sân hai lần.
  final Map<int, String> _keys = {};

  Future<void> load() async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final data = await repository.today();
      if (isClosed) return;
      final orders = [
        for (final court in data.courts)
          for (final s in court.sessions) TodayOrder(court.name, s),
      ]..sort((a, b) => a.session.start.compareTo(b.session.start));
      emit(state.copyWith(orders: orders, loading: false));
    } on Failure catch (e) {
      if (!isClosed) emit(state.copyWith(loading: false, error: e.message));
    }
  }

  Future<void> checkIn(int bookingId) async {
    if (state.pending.contains(bookingId)) return;
    emit(state.copyWith(pending: {...state.pending, bookingId}));
    final key = _keys.putIfAbsent(bookingId, newCommandKey);
    try {
      await repository.checkInByBooking(bookingId, key);
      _keys.remove(bookingId);
      if (isClosed) return;
      final orders = [
        for (final o in state.orders)
          o.session.bookingId == bookingId
              ? TodayOrder(o.courtName, o.session.withStatus('CHECKED_IN'))
              : o,
      ];
      emit(
        state.copyWith(
          orders: orders,
          pending: {...state.pending}..remove(bookingId),
          notice: 'Đã nhận sân',
        ),
      );
    } on Failure catch (e) {
      // Lỗi nghiệp vụ (4xx) là kết quả chắc chắn: lần sau dùng khóa mới.
      if (e is ServerFailure && (e.statusCode ?? 500) < 500) {
        _keys.remove(bookingId);
      }
      if (isClosed) return;
      emit(
        state.copyWith(
          pending: {...state.pending}..remove(bookingId),
          notice: e.message,
          noticeIsError: true,
        ),
      );
      // Đã nhận sân ở nơi khác: làm mới để dòng hiện đúng trạng thái.
      if (e.message.contains('đã được sử dụng')) await load();
    }
  }
}
