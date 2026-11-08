import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/failure.dart';
import '../domain/report_export.dart';

enum RevenueExportStatus { idle, downloading, success, failure }

class RevenueExportState extends Equatable {
  const RevenueExportState({
    this.status = RevenueExportStatus.idle,
    this.progress,
    this.report,
    this.opened = false,
    this.message,
  });

  final RevenueExportStatus status;

  /// 0..1; `null` khi chưa biết tổng kích thước (thanh tiến trình không xác định).
  final double? progress;
  final DownloadedReport? report;

  /// File đã được mở bằng ứng dụng ngoài hay chưa.
  final bool opened;
  final String? message;

  @override
  List<Object?> get props => [status, progress, report, opened, message];
}

/// SCRUM-77: tải báo cáo doanh thu về máy rồi tự mở.
class RevenueExportCubit extends Cubit<RevenueExportState> {
  RevenueExportCubit(this._repository, this._opener)
    : super(const RevenueExportState());

  final RevenueReportRepository _repository;
  final ReportFileOpener _opener;

  Future<void> export(RevenueReportRequest request) async {
    if (state.status == RevenueExportStatus.downloading) return;
    final invalid = request.validationError;
    if (invalid != null) {
      emit(
        RevenueExportState(
          status: RevenueExportStatus.failure,
          message: invalid,
        ),
      );
      return;
    }
    emit(const RevenueExportState(status: RevenueExportStatus.downloading));
    try {
      final report = await _repository.download(
        request,
        onProgress: (fraction) {
          if (!isClosed && state.status == RevenueExportStatus.downloading) {
            emit(
              RevenueExportState(
                status: RevenueExportStatus.downloading,
                progress: fraction?.clamp(0, 1).toDouble(),
              ),
            );
          }
        },
      );
      // Không có ứng dụng mở được file không làm hỏng việc tải: file đã nằm trên máy.
      final opened = await _opener.open(report.path);
      if (isClosed) return;
      emit(
        RevenueExportState(
          status: RevenueExportStatus.success,
          report: report,
          opened: opened,
        ),
      );
    } on Failure catch (failure) {
      if (isClosed) return;
      emit(
        RevenueExportState(
          status: RevenueExportStatus.failure,
          message: failure.message,
        ),
      );
    }
  }

  void reset() => emit(const RevenueExportState());
}
