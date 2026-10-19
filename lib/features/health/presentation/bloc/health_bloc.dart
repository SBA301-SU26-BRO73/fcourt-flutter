import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/health_status.dart';
import '../../domain/usecases/get_health_status.dart';

part 'health_event.dart';
part 'health_state.dart';

class HealthBloc extends Bloc<HealthEvent, HealthState> {
  HealthBloc(this._getHealthStatus) : super(const HealthInitial()) {
    on<HealthCheckRequested>(_onCheckRequested);
  }

  final GetHealthStatus _getHealthStatus;

  Future<void> _onCheckRequested(
    HealthCheckRequested event,
    Emitter<HealthState> emit,
  ) async {
    emit(const HealthLoading());
    try {
      emit(HealthSuccess(await _getHealthStatus()));
    } on Failure catch (failure) {
      emit(HealthFailure(failure.message));
    }
  }
}
