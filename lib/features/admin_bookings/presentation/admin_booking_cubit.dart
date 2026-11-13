import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/failure.dart';
import '../../admin_facility/domain/repositories/branch_repository.dart';
import '../../admin_facility/domain/repositories/court_repository.dart';
import '../domain/admin_booking.dart';
import '../domain/admin_booking_query.dart';
import '../domain/admin_booking_repository.dart';
import '../domain/admin_booking_status.dart';
import 'admin_booking_state.dart';

class AdminBookingCubit extends Cubit<AdminBookingState> {
  AdminBookingCubit(
    this.repository,
    this.branches,
    this.courts, {
    this.defaultStatus,
  }) : super(const AdminBookingState());

  /// Bộ lọc trạng thái mặc định khi chọn chi nhánh (chủ sân mở vào tab "Cần xử lý").
  final AdminBookingStatus? defaultStatus;
  final AdminBookingRepository repository;
  final BranchRepository branches;
  final CourtRepository courts;
  Timer? _debounce;
  int _revision = 0, _courtRevision = 0, _initialRevision = 0;

  String _message(Object error) => error is Failure
      ? error.message
      : 'Không tải được đơn đặt sân. Vui lòng thử lại.';

  Future<void> initialize({int? branchId}) async {
    final revision = ++_initialRevision;
    _revision++;
    _courtRevision++;
    _debounce?.cancel();
    emit(const AdminBookingState());
    try {
      final owned = await branches.getBranches();
      if (isClosed || revision != _initialRevision) return;
      if (branchId != null && !owned.any((branch) => branch.id == branchId)) {
        throw const ServerFailure(
          'Bạn không có quyền xem chi nhánh này',
          statusCode: 403,
        );
      }
      emit(
        state.copyWith(
          branches: List.unmodifiable(owned),
          branchesLoading: false,
        ),
      );
      if (owned.isNotEmpty) await selectBranch(branchId ?? 0);
    } catch (error) {
      if (!isClosed && revision == _initialRevision) {
        emit(state.copyWith(branchesLoading: false, error: _message(error)));
      }
    }
  }

  Future<void> selectBranch(int id) async {
    if (id != 0 && !state.branches.any((branch) => branch.id == id)) return;
    _courtRevision++;
    emit(
      state.copyWith(
        query: AdminBookingQuery(branchId: id, status: defaultStatus),
        courts: [],
        courtsError: null,
        courtsLoading: true,
      ),
    );
    if (id == 0) {
      await refresh();
    } else {
      await Future.wait([refresh(), reloadCourts()]);
    }
  }

  Future<void> reloadCourts() async {
    final branchId = state.query?.branchId;
    if (branchId == null || branchId == 0) return;
    final revision = ++_courtRevision;
    emit(state.copyWith(courtsLoading: true, courtsError: null));
    try {
      final options = await courts.getCourts(branchId);
      if (isClosed || revision != _courtRevision) return;
      if (options.any((court) => court.branchId != branchId) ||
          options.map((court) => court.id).toSet().length != options.length) {
        throw const ServerFailure('Danh sách sân không hợp lệ');
      }
      emit(
        state.copyWith(
          courts: List.unmodifiable(options),
          courtsLoading: false,
        ),
      );
    } catch (error) {
      if (!isClosed && revision == _courtRevision) {
        emit(
          state.copyWith(courtsLoading: false, courtsError: _message(error)),
        );
      }
    }
  }

  void search(String text) {
    final query = state.query;
    if (query == null) return;
    _debounce?.cancel();
    _revision++;
    emit(
      state.copyWith(
        query: query.copyWith(search: text),
        items: [],
        loading: true,
        loadingMore: false,
        total: 0,
        hasMore: false,
        error: null,
      ),
    );
    _debounce = Timer(const Duration(milliseconds: 300), refresh);
  }

  void setCourt(int? id) {
    final query = state.query;
    if (query == null ||
        (id != null && !state.courts.any((court) => court.id == id))) {
      return;
    }
    emit(
      state.copyWith(
        query: query.copyWith(courtId: id, clearCourt: id == null),
      ),
    );
    refresh();
  }

  void setStatus(AdminBookingStatus? status) {
    final query = state.query;
    if (query == null) return;
    emit(
      state.copyWith(
        query: query.copyWith(status: status, clearStatus: status == null),
      ),
    );
    refresh();
  }

  void setDate(DateTime? date) {
    final query = state.query;
    if (query == null) return;
    emit(
      state.copyWith(
        query: query.copyWith(date: date, clearDate: date == null),
      ),
    );
    refresh();
  }

  Future<void> refresh() async {
    _debounce?.cancel();
    final revision = ++_revision;
    if (state.query == null) return;
    emit(
      state.copyWith(
        items: [],
        page: 0,
        total: 0,
        hasMore: false,
        loading: true,
        loadingMore: false,
        error: null,
      ),
    );
    await _load(revision, 0);
  }

  Future<void> loadMore() async {
    if (state.loading || state.loadingMore || !state.hasMore) return;
    emit(state.copyWith(loadingMore: true, error: null));
    await _load(_revision, state.page + 1);
  }

  Future<void> _load(int revision, int page) async {
    final query = state.query!;
    try {
      final pages = query.branchId == 0
          ? await Future.wait([
              for (final branch in state.branches)
                repository.search(
                  query.copyWith(branchId: branch.id, clearCourt: true),
                  page: page,
                ),
            ])
          : [await repository.search(query, page: page)];
      if (isClosed || revision != _revision) return;
      final items = <int, AdminBooking>{
        if (page > 0)
          for (final row in state.items) row.id: row,
        for (final result in pages)
          for (final row in result.items) row.id: row,
      };
      emit(
        state.copyWith(
          items: List.unmodifiable(
            items.values.toList()..sort((a, b) => b.date.compareTo(a.date)),
          ),
          page: page,
          total: pages.fold<int>(0, (sum, result) => sum + result.total),
          hasMore: pages.any((result) => result.hasMore),
          loading: false,
          loadingMore: false,
        ),
      );
    } catch (error) {
      if (!isClosed && revision == _revision) {
        emit(
          state.copyWith(
            loading: false,
            loadingMore: false,
            error: _message(error),
          ),
        );
      }
    }
  }

  @override
  Future<void> close() {
    _revision++;
    _courtRevision++;
    _initialRevision++;
    _debounce?.cancel();
    return super.close();
  }
}
