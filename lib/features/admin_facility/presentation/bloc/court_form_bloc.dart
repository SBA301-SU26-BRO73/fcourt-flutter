import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/court.dart';
import '../../domain/entities/court_type.dart';
import '../../domain/usecases/court_usecases.dart';

part 'court_form_event.dart';
part 'court_form_state.dart';

/// SCRUM-17: tạo sân trong [branchId] hoặc sửa sân [courtId].
class CourtFormBloc extends Bloc<CourtFormEvent, CourtFormState> {
  CourtFormBloc({
    required this._getCourt,
    required this._saveCourt,
    required this._getCourtTypes,
    this.branchId,
    this.courtId,
  }) : assert(branchId != null || courtId != null),
       super(const CourtFormState(status: CourtFormStatus.loading)) {
    on<CourtFormStarted>(_onStarted);
    on<CourtFormSubmitted>(_onSubmitted);
  }

  final GetCourt _getCourt;
  final SaveCourt _saveCourt;
  final GetCourtTypes _getCourtTypes;
  final int? branchId;
  final int? courtId;

  bool get isEditing => courtId != null;

  Future<void> _onStarted(
    CourtFormStarted event,
    Emitter<CourtFormState> emit,
  ) async {
    emit(const CourtFormState(status: CourtFormStatus.loading));
    try {
      final types = await _getCourtTypes();
      final id = courtId;
      final court = id == null ? null : await _getCourt(id);
      emit(
        CourtFormState(
          status: CourtFormStatus.ready,
          courtTypes: types,
          initial: court,
        ),
      );
    } on Failure catch (failure) {
      emit(
        CourtFormState(
          status: CourtFormStatus.loadFailure,
          message: failure.message,
        ),
      );
    }
  }

  Future<void> _onSubmitted(
    CourtFormSubmitted event,
    Emitter<CourtFormState> emit,
  ) async {
    if (state.status == CourtFormStatus.submitting) return;
    if (event.draft.defaultPricePerHour <= 0) {
      emit(
        state.copyWith(
          status: CourtFormStatus.failure,
          message: 'Giá mỗi giờ phải lớn hơn 0',
        ),
      );
      return;
    }
    final targetBranch = state.initial?.branchId ?? branchId;
    if (targetBranch == null) return;
    emit(state.copyWith(status: CourtFormStatus.submitting));
    try {
      final saved = await _saveCourt(
        event.draft,
        branchId: targetBranch,
        courtId: courtId,
      );
      emit(state.copyWith(status: CourtFormStatus.success, saved: saved));
    } on Failure catch (failure) {
      emit(
        state.copyWith(
          status: CourtFormStatus.failure,
          message: failure.message,
        ),
      );
    }
  }
}
