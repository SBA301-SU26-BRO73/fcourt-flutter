import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/failure.dart';
import '../domain/schedule.dart';

class ScheduleState {
  const ScheduleState({this.data, this.loading = false, this.error});
  final BranchSchedule? data;
  final bool loading;
  final String? error;
}

class ScheduleCubit extends Cubit<ScheduleState> {
  ScheduleCubit(this.repository) : super(const ScheduleState());
  final OperationsRepository repository;
  int _version = 0;
  Future<void> load() async {
    final version = ++_version;
    emit(ScheduleState(data: state.data, loading: true));
    try {
      final data = await repository.today();
      if (!isClosed && version == _version) emit(ScheduleState(data: data));
    } on Failure catch (e) {
      if (!isClosed && version == _version) {
        emit(ScheduleState(data: state.data, error: e.message));
      }
    }
  }
}
