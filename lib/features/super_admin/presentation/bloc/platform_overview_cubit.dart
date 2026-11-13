import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/platform_overview.dart';
import '../../domain/repositories/platform_overview_repository.dart';

enum PlatformOverviewStatus { loading, success, failure }

class PlatformOverviewState extends Equatable {
  const PlatformOverviewState({
    this.status = PlatformOverviewStatus.loading,
    this.overview,
    this.months = 12,
    this.message,
  });

  final PlatformOverviewStatus status;
  final PlatformOverview? overview;
  final int months;
  final String? message;

  @override
  List<Object?> get props => [status, overview, months, message];
}

/// SCRUM-79: tải thống kê vĩ mô. Khi đổi số tháng hoặc tải lại, dữ liệu cũ vẫn
/// hiển thị cho tới khi có kết quả mới; phản hồi cũ không ghi đè phản hồi mới.
class PlatformOverviewCubit extends Cubit<PlatformOverviewState> {
  PlatformOverviewCubit(this._get) : super(const PlatformOverviewState());

  final GetPlatformOverview _get;
  int _generation = 0;

  Future<void> load({int? months}) async {
    final window = months ?? state.months;
    final generation = ++_generation;
    emit(
      PlatformOverviewState(
        status: PlatformOverviewStatus.loading,
        overview: state.overview,
        months: window,
      ),
    );
    try {
      final overview = await _get(months: window);
      if (isClosed || generation != _generation) return;
      emit(
        PlatformOverviewState(
          status: PlatformOverviewStatus.success,
          overview: overview,
          months: window,
        ),
      );
    } on Failure catch (failure) {
      if (isClosed || generation != _generation) return;
      emit(
        PlatformOverviewState(
          status: PlatformOverviewStatus.failure,
          overview: state.overview,
          months: window,
          message: failure.message,
        ),
      );
    }
  }
}
