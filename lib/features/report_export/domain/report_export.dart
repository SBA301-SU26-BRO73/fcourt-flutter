import 'package:equatable/equatable.dart';

enum ReportFormat {
  xlsx('xlsx', 'Excel (.xlsx)'),
  csv('csv', 'CSV (.csv)');

  const ReportFormat(this.extension, this.label);

  final String extension;
  final String label;
}

/// Yêu cầu xuất báo cáo doanh thu (SCRUM-76). [from]/[to] là ngày chơi, gồm cả hai đầu.
class RevenueReportRequest extends Equatable {
  const RevenueReportRequest({
    required this.from,
    required this.to,
    this.format = ReportFormat.xlsx,
    this.branchId,
  });

  /// Backend từ chối khoảng dài hơn số ngày này.
  static const maxDays = 366;

  final DateTime from;
  final DateTime to;
  final ReportFormat format;

  /// `null` = mọi chi nhánh của chủ sân.
  final int? branchId;

  /// Thông báo lỗi tiếng Việt nếu yêu cầu không hợp lệ, ngược lại `null`.
  String? get validationError {
    final start = DateTime.utc(from.year, from.month, from.day);
    final end = DateTime.utc(to.year, to.month, to.day);
    if (start.isAfter(end)) {
      return 'Ngày bắt đầu phải trước hoặc bằng ngày kết thúc';
    }
    if (end.difference(start).inDays + 1 > maxDays) {
      return 'Khoảng ngày tối đa $maxDays ngày';
    }
    if (branchId != null && branchId! <= 0) return 'Chi nhánh không hợp lệ';
    return null;
  }

  @override
  List<Object?> get props => [from, to, format, branchId];
}

class DownloadedReport extends Equatable {
  const DownloadedReport({
    required this.name,
    required this.path,
    required this.sizeBytes,
  });

  final String name;
  final String path;
  final int sizeBytes;

  @override
  List<Object?> get props => [name, path, sizeBytes];
}

abstract interface class RevenueReportRepository {
  /// Tải file về thiết bị. [onProgress] nhận tỉ lệ 0..1, hoặc `null` khi máy chủ
  /// không báo kích thước.
  Future<DownloadedReport> download(
    RevenueReportRequest request, {
    void Function(double? fraction)? onProgress,
  });
}

/// Mở file bằng ứng dụng có sẵn trên máy. `false` nếu không có ứng dụng phù hợp.
abstract interface class ReportFileOpener {
  Future<bool> open(String path);
}
