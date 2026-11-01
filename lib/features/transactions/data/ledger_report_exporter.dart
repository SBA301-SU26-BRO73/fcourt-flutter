import 'dart:convert';
import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

import '../../../core/error/failure.dart';
import '../domain/branch_ledger.dart';
import '../domain/transaction.dart';

class CsvLedgerExporter implements LedgerReportExporter {
  CsvLedgerExporter(
    this.repository, {
    Future<void> Function(Uint8List, String)? share,
  }) : _share = share ?? _shareFile;
  final AdminTransactions repository;
  final Future<void> Function(Uint8List, String) _share;
  static Future<void> _shareFile(Uint8List bytes, String name) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(bytes, mimeType: 'text/csv', name: name)],
        fileNameOverrides: [name],
        title: 'Báo cáo dòng tiền FCOURT',
      ),
    );
  }

  static String cell(String value) {
    final trimmed = value.trimLeft();
    if (trimmed.isNotEmpty && '=+-@'.contains(trimmed[0])) value = "'$value";
    return '"${value.replaceAll('"', '""')}"';
  }

  @override
  Future<void> export(LedgerQuery query) async {
    LedgerPage? first;
    final rows = <PaymentTransaction>[];
    final keys = <String>{};
    for (int page = 0; page < 10000; page++) {
      final result = await repository.load(query, page: page);
      first ??= result;
      if (result.transactions.total != first.transactions.total ||
          result.received != first.received ||
          result.refunded != first.refunded ||
          result.netRevenue != first.netRevenue ||
          result.pending != first.pending ||
          result.rejectedCount != first.rejectedCount) {
        throw const ServerFailure(
          'Dữ liệu đang thay đổi. Vui lòng xuất lại báo cáo.',
        );
      }
      for (final row in result.transactions.items) {
        if (!keys.add(row.key)) {
          throw const ServerFailure(
            'Dữ liệu phân trang thay đổi. Vui lòng thử lại.',
          );
        }
        rows.add(row);
      }
      if (!result.transactions.hasMore) {
        if (rows.length != result.transactions.total) {
          throw const ServerFailure(
            'Báo cáo chưa đủ dữ liệu. Vui lòng thử lại.',
          );
        }
        final lines = <String>[
          '${cell('Chi nhánh')},${query.branchId}',
          '${cell('Tổng thu')},${result.received}',
          '${cell('Tổng hoàn tiền')},${result.refunded}',
          '${cell('Doanh thu thực tế')},${result.netRevenue}',
          [
            'Khóa giao dịch',
            'Loại giao dịch',
            'Mã giao dịch',
            'Mã đơn',
            'Chi nhánh',
            'Sân',
            'Thời gian UTC',
            'Trạng thái',
            'Số tiền (VND)',
          ].map(cell).join(','),
          ...rows.map(
            (r) => [
              cell(r.key),
              cell(r.transactionType),
              cell(r.code),
              cell(r.bookingCode),
              cell(r.branch),
              cell(r.court),
              cell(r.occurredAt.toUtc().toIso8601String()),
              cell(r.status),
              r.amount.toString(),
            ].join(','),
          ),
        ];
        try {
          await _share(
            Uint8List.fromList(utf8.encode('\uFEFF${lines.join('\r\n')}')),
            'fcourt-ledger-${query.branchId}.csv',
          );
        } on Exception {
          throw const ServerFailure(
            'Chưa mở được nơi lưu/chia sẻ báo cáo. Vui lòng thử lại.',
          );
        }
        return;
      }
    }
    throw const ServerFailure('Báo cáo quá lớn. Vui lòng thu hẹp khoảng ngày.');
  }
}
