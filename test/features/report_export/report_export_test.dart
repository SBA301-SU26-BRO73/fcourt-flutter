import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fcourt/core/error/failure.dart';
import 'package:fcourt/features/report_export/data/report_file_store.dart';
import 'package:fcourt/features/report_export/data/revenue_report_remote_data_source.dart';
import 'package:fcourt/features/report_export/data/revenue_report_repository_impl.dart';
import 'package:fcourt/features/report_export/domain/report_export.dart';
import 'package:fcourt/features/report_export/presentation/revenue_export_button.dart';
import 'package:fcourt/features/report_export/presentation/revenue_export_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_adapter.dart';
import '../admin_facility/fixtures.dart';

class _MemoryStore implements ReportFileStore {
  final saved = <String, Uint8List>{};
  bool fail = false;

  @override
  Future<String> save(String fileName, Uint8List bytes) async {
    if (fail) throw const FileSystemException('disk full');
    saved[fileName] = bytes;
    return '/storage/Download/$fileName';
  }
}

class _Opener implements ReportFileOpener {
  _Opener([this.result = true]);

  final bool result;
  final opened = <String>[];

  @override
  Future<bool> open(String path) async {
    opened.add(path);
    return result;
  }
}

class _FakeRepository implements RevenueReportRepository {
  _FakeRepository({this.error, this.gate});

  final Failure? error;
  final Completer<void>? gate;
  final requests = <RevenueReportRequest>[];

  @override
  Future<DownloadedReport> download(
    RevenueReportRequest request, {
    void Function(double? fraction)? onProgress,
  }) async {
    requests.add(request);
    onProgress?.call(0.5);
    if (gate != null) await gate!.future;
    if (error != null) throw error!;
    return const DownloadedReport(
      name: 'bao-cao.xlsx',
      path: '/storage/Download/bao-cao.xlsx',
      sizeBytes: 3,
    );
  }
}

final _xlsxBytes = Uint8List.fromList([0x50, 0x4B, 3, 4, 9]);
final _request = RevenueReportRequest(
  from: DateTime(2026, 10, 1),
  to: DateTime(2026, 10, 31),
  branchId: 3,
);

ResponseBody _file(
  RequestOptions options, {
  String disposition = 'attachment; filename="bao-cao-doanh-thu_20261001_20261031.xlsx"',
}) => ResponseBody.fromBytes(
  _xlsxBytes,
  200,
  headers: {
    'content-disposition': [disposition],
    Headers.contentLengthHeader: ['${_xlsxBytes.length}'],
  },
);

RevenueReportRepositoryImpl _repo(
  FakeAdapter adapter,
  _MemoryStore store, {
  DateTime? now,
}) => RevenueReportRepositoryImpl(
  RevenueReportRemoteDataSource(Dio()..httpClientAdapter = adapter),
  store,
  now: () => now ?? DateTime(2026, 11, 5),
);

void main() {
  group('RevenueReportRequest', () {
    test('kiểm tra khoảng ngày', () {
      expect(_request.validationError, isNull);
      expect(
        RevenueReportRequest(from: DateTime(2026, 11, 2), to: DateTime(2026, 11, 1))
            .validationError,
        contains('trước hoặc bằng'),
      );
      // 366 ngày là tối đa (2027 không nhuận: 01/01 -> 01/01 năm sau = 366 ngày).
      expect(
        RevenueReportRequest(from: DateTime(2026, 1, 1), to: DateTime(2026, 12, 31))
            .validationError,
        isNull,
      );
      expect(
        RevenueReportRequest(from: DateTime(2026, 1, 1), to: DateTime(2027, 1, 2))
            .validationError,
        contains('366'),
      );
      expect(
        RevenueReportRequest(from: DateTime(2026, 1, 1), to: DateTime(2026, 1, 2), branchId: 0)
            .validationError,
        isNotNull,
      );
    });
  });

  group('RevenueReportRepositoryImpl', () {
    test('gửi đúng tham số, xin file nhị phân và lưu tên chuẩn hóa kèm ngày xuất', () async {
      final adapter = FakeAdapter(_file);
      final store = _MemoryStore();
      final fractions = <double?>[];

      final report = await _repo(adapter, store).download(
        _request,
        onProgress: fractions.add,
      );

      final sent = adapter.requests.single;
      expect(sent.path, '/api/admin/dashboard/export/revenue');
      expect(sent.queryParameters, {
        'fromDate': '2026-10-01',
        'toDate': '2026-10-31',
        'format': 'xlsx',
        'branchId': 3,
      });
      expect(sent.responseType, ResponseType.bytes);
      expect(sent.headers['Accept'], '*/*');
      expect(
        report.name,
        'bao-cao-doanh-thu_20261001_20261031_xuat-20261105.xlsx',
      );
      expect(report.path, '/storage/Download/${report.name}');
      expect(report.sizeBytes, _xlsxBytes.length);
      expect(store.saved[report.name], _xlsxBytes);
      expect(fractions, isNotEmpty);
    });

    test('CSV và không chọn chi nhánh: không gửi branchId', () async {
      final adapter = FakeAdapter(
        (o) => _file(o, disposition: 'attachment; filename="bao-cao-doanh-thu_20261001_20261031.csv"'),
      );
      final report = await _repo(adapter, _MemoryStore()).download(
        RevenueReportRequest(
          from: DateTime(2026, 10, 1),
          to: DateTime(2026, 10, 31),
          format: ReportFormat.csv,
        ),
      );

      expect(adapter.requests.single.queryParameters, {
        'fromDate': '2026-10-01',
        'toDate': '2026-10-31',
        'format': 'csv',
      });
      expect(report.name.endsWith('_xuat-20261105.csv'), isTrue);
    });

    test('tên gợi ý lạ hoặc sai đuôi bị bỏ, tự dựng từ khoảng ngày', () {
      String name(String? header) =>
          RevenueReportRepositoryImpl.fileName(_request, header, DateTime(2026, 11, 5));
      const standard = 'bao-cao-doanh-thu_20261001_20261031_xuat-20261105.xlsx';
      expect(name(null), standard);
      expect(name('attachment; filename="../../etc/passwd.xlsx"'), standard);
      expect(name('attachment; filename="report.csv"'), standard);
      expect(name('attachment; filename=".xlsx"'), standard);
      expect(name('attachment; filename="custom.xlsx"'), 'custom_xuat-20261105.xlsx');
    });

    test('khoảng ngày sai bị chặn trước khi gọi mạng', () async {
      final adapter = FakeAdapter(_file);
      await expectLater(
        _repo(adapter, _MemoryStore()).download(
          RevenueReportRequest(from: DateTime(2026, 11, 2), to: DateTime(2026, 11, 1)),
        ),
        throwsA(isA<ServerFailure>()),
      );
      expect(adapter.requests, isEmpty);
    });

    test('lỗi ProblemDetail dạng bytes được giải mã thành thông báo', () async {
      Future<ServerFailure> failure(int status, String detail) async {
        final adapter = FakeAdapter(
          (_) => ResponseBody.fromString(
            jsonEncode({'detail': detail, 'status': status}),
            status,
            headers: {
              Headers.contentTypeHeader: ['application/problem+json'],
            },
          ),
        );
        try {
          await _repo(adapter, _MemoryStore()).download(_request);
        } on ServerFailure catch (f) {
          return f;
        }
        throw TestFailure('Phải ném ServerFailure');
      }

      expect(
        (await failure(400, 'Date range must not exceed 366 days')).message,
        contains('Date range must not exceed 366 days'),
      );
      expect((await failure(403, 'Branch access denied')).message, contains('không có quyền'));
      expect((await failure(503, 'Facility service unavailable')).message, contains('thử lại sau'));
    });

    test('file rỗng hoặc không lưu được đều là lỗi, không báo thành công', () async {
      final empty = FakeAdapter((_) => ResponseBody.fromBytes(const [], 200));
      await expectLater(
        _repo(empty, _MemoryStore()).download(_request),
        throwsA(isA<UnknownFailure>()),
      );
      final store = _MemoryStore()..fail = true;
      await expectLater(
        _repo(FakeAdapter(_file), store).download(_request),
        throwsA(
          isA<UnknownFailure>().having((f) => f.message, 'message', contains('Không lưu được')),
        ),
      );
    });
  });

  group('RevenueExportCubit', () {
    test('thành công: tải xong rồi mở file', () async {
      final opener = _Opener();
      final cubit = RevenueExportCubit(_FakeRepository(), opener);
      final states = <RevenueExportState>[];
      cubit.stream.listen(states.add);

      await cubit.export(_request);

      expect(states.first.status, RevenueExportStatus.downloading);
      expect(states.any((s) => s.progress == 0.5), isTrue);
      expect(cubit.state.status, RevenueExportStatus.success);
      expect(cubit.state.opened, isTrue);
      expect(opener.opened, ['/storage/Download/bao-cao.xlsx']);
      await cubit.close();
    });

    test('không có app mở file vẫn là thành công nhưng opened=false', () async {
      final cubit = RevenueExportCubit(_FakeRepository(), _Opener(false));
      await cubit.export(_request);
      expect(cubit.state.status, RevenueExportStatus.success);
      expect(cubit.state.opened, isFalse);
      await cubit.close();
    });

    test('lỗi từ repository hiện thông báo và không mở file', () async {
      final opener = _Opener();
      final cubit = RevenueExportCubit(
        _FakeRepository(error: const ServerFailure('Bạn không có quyền')),
        opener,
      );
      await cubit.export(_request);
      expect(cubit.state.status, RevenueExportStatus.failure);
      expect(cubit.state.message, 'Bạn không có quyền');
      expect(opener.opened, isEmpty);
      await cubit.close();
    });

    test('yêu cầu không hợp lệ không gọi repository; đang tải thì bỏ qua lần bấm thứ hai', () async {
      final repo = _FakeRepository();
      final cubit = RevenueExportCubit(repo, _Opener());
      await cubit.export(
        RevenueReportRequest(from: DateTime(2026, 11, 2), to: DateTime(2026, 11, 1)),
      );
      expect(cubit.state.status, RevenueExportStatus.failure);
      expect(repo.requests, isEmpty);

      final gate = Completer<void>();
      final slow = _FakeRepository(gate: gate);
      final busy = RevenueExportCubit(slow, _Opener());
      final first = busy.export(_request);
      await busy.export(_request);
      gate.complete();
      await first;
      expect(slow.requests, hasLength(1));
      await cubit.close();
      await busy.close();
    });
  });

  group('RevenueExportButton', () {
    Future<void> pumpButton(
      WidgetTester tester,
      RevenueReportRepository repo,
      ReportFileOpener opener, {
      bool lockBranch = false,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              actions: [
                RevenueExportButton(
                  repository: repo,
                  opener: opener,
                  branches: [sampleBranch(id: 3, name: 'Chi nhánh Cầu Giấy')],
                  initialBranchId: 3,
                  lockBranch: lockBranch,
                ),
              ],
            ),
          ),
        ),
      );
    }

    testWidgets('chọn CSV rồi tải: gửi đúng yêu cầu và SnackBar báo vị trí lưu', (tester) async {
      final repo = _FakeRepository();
      await pumpButton(tester, repo, _Opener());

      await tester.tap(find.byKey(const ValueKey('export-open')));
      await tester.pumpAndSettle();
      expect(find.text('Xuất báo cáo doanh thu'), findsOneWidget);
      expect(find.text('Chi nhánh Cầu Giấy'), findsOneWidget);

      await tester.tap(find.text('CSV (.csv)'));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('export-submit')));
      await tester.pumpAndSettle();

      final sent = repo.requests.single;
      expect(sent.format, ReportFormat.csv);
      expect(sent.branchId, 3);
      expect(sent.from.day, 1);
      expect(find.text('Xuất báo cáo doanh thu'), findsNothing);
      expect(
        find.textContaining('Đã lưu báo cáo tại: /storage/Download/bao-cao.xlsx'),
        findsOneWidget,
      );
    });

    testWidgets('lỗi hiện ngay trong hộp thoại và cho phép thử lại', (tester) async {
      final repo = _FakeRepository(error: const ServerFailure('Máy chủ bận'));
      await pumpButton(tester, repo, _Opener());

      await tester.tap(find.byKey(const ValueKey('export-open')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('export-submit')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('export-error')), findsOneWidget);
      expect(find.text('Máy chủ bận'), findsOneWidget);
      expect(find.text('Xuất báo cáo doanh thu'), findsOneWidget);
    });

    testWidgets('đang tải: thanh tiến trình hiện và nút bị khóa', (tester) async {
      final gate = Completer<void>();
      final repo = _FakeRepository(gate: gate);
      await pumpButton(tester, repo, _Opener());

      await tester.tap(find.byKey(const ValueKey('export-open')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('export-submit')));
      await tester.pump();

      final progress = tester.widget<LinearProgressIndicator>(
        find.byKey(const ValueKey('export-progress')),
      );
      expect(progress.value, 0.5);
      expect(find.text('Đang tải 50%'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byKey(const ValueKey('export-submit'))).onPressed,
        isNull,
      );
      gate.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('màn hình của một chi nhánh: ẩn ô chọn chi nhánh', (tester) async {
      await pumpButton(tester, _FakeRepository(), _Opener(), lockBranch: true);
      await tester.tap(find.byKey(const ValueKey('export-open')));
      await tester.pumpAndSettle();
      expect(find.text('Tất cả chi nhánh'), findsNothing);
      expect(find.byType(BlocConsumer<RevenueExportCubit, RevenueExportState>), findsOneWidget);
    });
  });
}
