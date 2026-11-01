import 'package:dio/dio.dart';
import 'package:fcourt/core/error/failure.dart';
import 'package:fcourt/features/operations/data/http_operations_repository.dart';
import 'package:fcourt/features/operations/domain/schedule.dart';
import 'package:fcourt/features/operations/presentation/check_in_dialog.dart';
import 'package:fcourt/features/operations/presentation/schedule_cubit.dart';
import 'package:fcourt/features/operations/presentation/schedule_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_adapter.dart';

class FakeOperations implements OperationsRepository {
  @override
  Future<BranchSchedule> week(String start, String end) => today();
  int writes = 0;
  Failure? error;
  final keys = <String>[];
  @override
  Future<BranchSchedule> today() async {
    if (error != null) throw error!;
    return const BranchSchedule(7, [
      CourtSchedule(21, 'Sân 1', [
        CourtSession(
          bookingId: 42,
          date: '2026-11-01',
          start: '09:00',
          end: '09:30',
          status: 'CONFIRMED',
          name: 'Khoa',
        ),
      ]),
    ]);
  }

  @override
  Future<TicketPreview> preview(String code) async {
    if (error != null) throw error!;
    return const TicketPreview(
      bookingId: 42,
      branchId: 7,
      courtName: 'Sân 1',
      date: '2026-11-01',
      start: '09:00',
      end: '09:30',
      name: 'Khoa',
    );
  }

  @override
  Future<int> checkIn(String code, String key, {bool manual = false}) async {
    writes++;
    keys.add(key);
    if (error != null) throw error!;
    return 42;
  }
}

void main() {
  test(
    'http schedule and preview match backend projection without writes',
    () async {
      final adapter = FakeAdapter(
        (r) => jsonResponse(
          200,
          r.path.endsWith('today')
              ? {
                  'branchId': 7,
                  'courts': [
                    {
                      'courtId': 21,
                      'courtName': 'Sân 1',
                      'slots': [
                        {
                          'bookingId': 42,
                          'date': '2026-11-01',
                          'slotStart': '09:00:00',
                          'slotEnd': '09:30:00',
                          'status': 'CONFIRMED',
                        },
                      ],
                    },
                  ],
                }
              : {
                  'bookingId': 42,
                  'branchId': 7,
                  'courtName': 'Sân 1',
                  'date': '2026-11-01',
                  'slotStart': '09:00',
                  'slotEnd': '09:30',
                  'status': 'CONFIRMED',
                },
        ),
      );
      final dio = Dio(BaseOptions(baseUrl: 'http://test'))
        ..httpClientAdapter = adapter;
      final repo = HttpOperationsRepository(dio);
      expect((await repo.today()).courts.single.sessions.single.start, '09:00');
      expect((await repo.preview('secret')).bookingId, 42);
      expect(adapter.requests.last.path, '/api/staff/check-in/preview');
      expect(adapter.requests.last.data, {'checkInCode': 'secret'});
      expect(
        adapter.requests.last.headers.containsKey('Idempotency-Key'),
        isFalse,
      );
    },
  );
  test('commands use correct channel and replay key', () async {
    final adapter = FakeAdapter(
      (r) => jsonResponse(200, {'bookingId': 42, 'status': 'CHECKED_IN'}),
    );
    final dio = Dio(BaseOptions(baseUrl: 'http://test'))
      ..httpClientAdapter = adapter;
    final repo = HttpOperationsRepository(dio);
    expect(await repo.checkIn('qr', 'same'), 42);
    expect(adapter.requests.last.path, '/api/staff/check-in/verify');
    await repo.checkIn('FC-123', 'manual-key', manual: true);
    expect(adapter.requests.last.path, '/api/staff/check-in/manual');
    expect(adapter.requests.last.headers['Idempotency-Key'], 'manual-key');
  });
  test('schedule cubit retains old data on failed refresh', () async {
    final fake = FakeOperations();
    final cubit = ScheduleCubit(fake);
    await cubit.load();
    expect(cubit.state.data!.branchId, 7);
    fake.error = const NetworkFailure();
    await cubit.load();
    expect(cubit.state.error, isNotNull);
    expect(cubit.state.data!.branchId, 7);
    await cubit.close();
  });
  testWidgets('ticket preview never admits until explicit confirm', (
    tester,
  ) async {
    final fake = FakeOperations();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<bool>(
              context: context,
              builder: (_) => CheckInDialog(repository: fake, code: 'qr'),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Sân 1'), findsOneWidget);
    expect(fake.writes, 0);
    fake.error = const NetworkFailure();
    await tester.tap(find.widgetWithText(FilledButton, 'Xác nhận nhận sân'));
    await tester.pumpAndSettle();
    expect(fake.writes, 1);
    await tester.tap(find.text('Thử lại lệnh nhận sân'));
    await tester.pumpAndSettle();
    expect(fake.keys[0], fake.keys[1]);
    fake.error = null;
    await tester.tap(find.text('Thử lại lệnh nhận sân'));
    await tester.pumpAndSettle();
    expect(find.byType(CheckInDialog), findsNothing);
  });
  testWidgets('schedule shows court and waiting session', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: SchedulePage(repository: FakeOperations())),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sân 1'), findsOneWidget);
    expect(find.textContaining('Chờ nhận sân'), findsOneWidget);
    expect(find.text('Quét vé'), findsOneWidget);
  });
}
