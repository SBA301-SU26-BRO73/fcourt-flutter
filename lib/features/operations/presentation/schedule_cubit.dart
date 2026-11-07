import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/failure.dart';
import '../domain/schedule.dart';

class ScheduleState {
  const ScheduleState({
    this.data,
    this.loading = false,
    this.error,
    this.weekly = false,
    this.anchor,
    this.refreshVersion = 0,
  });
  final BranchSchedule? data;
  final bool loading;
  final String? error;
  final bool weekly;
  final DateTime? anchor;
  final int refreshVersion;
}

class ScheduleCubit extends Cubit<ScheduleState> {
  ScheduleCubit(this.repository) : super(const ScheduleState());
  final OperationsRepository repository;
  int _version = 0;
  Future<void> refresh() => state.weekly ? loadWeek(state.anchor!) : load();
  Future<void> loadWeek(DateTime date) async {
    final start = weekMonday(date);
    final version = ++_version;
    final sameWeek = state.weekly && state.anchor == start;
    final kept = sameWeek ? state.data : null;
    emit(ScheduleState(data: kept, loading: true, weekly: true, anchor: start));
    try {
      final data = await repository.week(
        calendarDate(start),
        calendarDate(start.add(const Duration(days: 6))),
      );
      if (!isClosed && version == _version) {
        emit(ScheduleState(data: data, weekly: true, anchor: start));
      }
    } on Failure catch (e) {
      if (!isClosed && version == _version) {
        emit(
          ScheduleState(
            data: kept,
            error: e.message,
            weekly: true,
            anchor: start,
          ),
        );
      }
    }
  }

  Future<void> load() async {
    final version = ++_version;
    emit(
      ScheduleState(
        data: state.weekly ? null : state.data,
        loading: true,
        refreshVersion: version,
      ),
    );
    try {
      final data = await repository.today();
      if (!isClosed && version == _version) {
        emit(ScheduleState(data: data, refreshVersion: version));
      }
    } on Failure catch (e) {
      if (!isClosed && version == _version) {
        emit(
          ScheduleState(
            data: state.data,
            error: e.message,
            refreshVersion: version,
          ),
        );
      }
    }
  }
}
