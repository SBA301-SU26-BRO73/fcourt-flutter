import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/branch.dart';
import '../../domain/entities/court.dart';
import '../../domain/entities/court_type.dart';
import '../../domain/usecases/branch_usecases.dart';
import '../../domain/usecases/court_usecases.dart';

part 'court_list_event.dart';
part 'court_list_state.dart';

/// SCRUM-17: danh sách sân theo chi nhánh, đổi bộ lọc chi nhánh, bật/tắt bảo trì.
class CourtListBloc extends Bloc<CourtListEvent, CourtListState> {
  CourtListBloc({
    required this._getBranches,
    required this._getCourts,
    required this._getCourtTypes,
    required this._toggleMaintenance,
  }) : super(const CourtListState()) {
    on<CourtListStarted>(_onStarted);
    on<CourtBranchSelected>(_onBranchSelected);
    on<CourtMaintenanceToggled>(_onMaintenanceToggled);
    on<CourtSaved>(_onSaved);
  }

  final GetBranches _getBranches;
  final GetCourts _getCourts;
  final GetCourtTypes _getCourtTypes;
  final ToggleCourtMaintenance _toggleMaintenance;

  /// Tăng mỗi lần đổi chi nhánh: phản hồi của chi nhánh cũ về muộn bị bỏ qua.
  int _generation = 0;

  Future<void> _onStarted(
    CourtListStarted event,
    Emitter<CourtListState> emit,
  ) async {
    final generation = ++_generation;
    emit(
      state.copyWith(
        status: CourtListStatus.loading,
        selectedBranchId: event.branchId,
        message: null,
      ),
    );
    try {
      final results = await Future.wait([
        _getBranches(),
        _getCourtTypes(),
        _getCourts(event.branchId),
      ]);
      if (generation != _generation) return;
      emit(
        state.copyWith(
          status: CourtListStatus.success,
          branches: results[0] as List<Branch>,
          courtTypes: results[1] as List<CourtType>,
          courts: results[2] as List<Court>,
        ),
      );
    } on Failure catch (failure) {
      if (generation != _generation) return;
      emit(
        state.copyWith(
          status: CourtListStatus.failure,
          message: failure.message,
        ),
      );
    }
  }

  Future<void> _onBranchSelected(
    CourtBranchSelected event,
    Emitter<CourtListState> emit,
  ) async {
    if (event.branchId == state.selectedBranchId &&
        state.status == CourtListStatus.success) {
      return;
    }
    final generation = ++_generation;
    emit(
      state.copyWith(
        status: CourtListStatus.loading,
        selectedBranchId: event.branchId,
        courts: const [],
        message: null,
      ),
    );
    try {
      final courts = await _getCourts(event.branchId);
      if (generation != _generation) return;
      emit(state.copyWith(status: CourtListStatus.success, courts: courts));
    } on Failure catch (failure) {
      if (generation != _generation) return;
      emit(
        state.copyWith(
          status: CourtListStatus.failure,
          message: failure.message,
        ),
      );
    }
  }

  Future<void> _onMaintenanceToggled(
    CourtMaintenanceToggled event,
    Emitter<CourtListState> emit,
  ) async {
    if (state.updatingIds.contains(event.courtId)) return;
    emit(state.copyWith(updatingIds: {...state.updatingIds, event.courtId}));
    try {
      final updated = await _toggleMaintenance(
        event.courtId,
        maintenance: event.maintenance,
      );
      // Người dùng có thể đã đổi sang chi nhánh khác trong lúc chờ.
      final sameBranch = updated.branchId == state.selectedBranchId;
      emit(
        state.copyWith(
          courts: sameBranch ? _upsert(state.courts, updated) : null,
          updatingIds: {...state.updatingIds}..remove(event.courtId),
          notice: CourtListNotice(
            updated.status == CourtStatus.maintenance
                ? 'Đã chuyển "${updated.name}" sang bảo trì'
                : '"${updated.name}" đã hoạt động trở lại',
          ),
        ),
      );
    } on Failure catch (failure) {
      emit(
        state.copyWith(
          updatingIds: {...state.updatingIds}..remove(event.courtId),
          notice: CourtListNotice(failure.message, isError: true),
        ),
      );
    }
  }

  void _onSaved(CourtSaved event, Emitter<CourtListState> emit) {
    // Sân của chi nhánh khác (không xảy ra trong luồng bình thường) thì bỏ qua.
    if (event.court.branchId != state.selectedBranchId) return;
    final isNew = state.courts.every((c) => c.id != event.court.id);
    emit(
      state.copyWith(
        courts: _upsert(state.courts, event.court),
        notice: CourtListNotice(
          isNew
              ? 'Đã thêm sân "${event.court.name}"'
              : 'Đã cập nhật sân "${event.court.name}"',
        ),
      ),
    );
  }

  static List<Court> _upsert(List<Court> courts, Court court) {
    final index = courts.indexWhere((c) => c.id == court.id);
    if (index < 0) return [...courts, court];
    return [...courts]..[index] = court;
  }
}
