import 'dart:async';

import 'package:dio/dio.dart';
import 'package:fcourt/core/error/failure.dart';
import 'package:fcourt/features/operations/data/http_operations_repository.dart';
import 'package:fcourt/features/operations/domain/schedule.dart';
import 'package:fcourt/features/operations/presentation/schedule_cubit.dart';
import 'package:fcourt/features/operations/presentation/week_board.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_adapter.dart';
import 'operations_test.dart' show FakeOperations;

class DelayedWeek extends FakeOperations {
  final first = Completer<BranchSchedule>();
  @override
  Future<BranchSchedule> week(String start, String end) => start == '2026-10-26'
      ? first.future
      : Future.value(const BranchSchedule(8, []));
}

void main() {
  test('calendar week crosses month and year with monday start', () {
    expect(calendarDate(weekMonday(DateTime(2027, 1, 1))), '2026-12-28');
    expect(calendarDate(weekMonday(DateTime(2026, 11, 1))), '2026-10-26');
    expect(calendarDate(weekMonday(DateTime(2026, 11, 2))), '2026-11-02');
  });
  test(
    'weekly adapter flattens days and preserves authority warning flags',
    () async {
      final adapter = FakeAdapter(
        (r) => jsonResponse(200, {
          'branchId': 7,
          'startDate': '2026-10-26',
          'endDate': '2026-11-01',
          'courts': [
            {
              'courtId': 21,
              'courtName': 'Sân 1',
              'days': [
                {
                  'date': '2026-11-01',
                  'slots': [
                    {
                      'bookingId': 42,
                      'slotStart': '09:00',
                      'slotEnd': '09:30',
                      'status': 'CHECKED_IN',
                      'flags': {
                        'endingSoon': true,
                        'playing': true,
                        'lateCheckIn': false,
                      },
                    },
                  ],
                },
              ],
            },
            {'courtId': 22, 'courtName': 'Empty court', 'days': []},
          ],
        }),
      );
      final dio = Dio(BaseOptions(baseUrl: 'http://test'))
        ..httpClientAdapter = adapter;
      final result =
          await HttpOperationsRepository(dio).week('2026-10-26', '2026-11-01');
      expect(result.courts.first.sessions.single.endingSoon, isTrue);
      expect(result.courts.last.sessions, isEmpty);
      expect(adapter.requests.single.queryParameters, {
        'startDate': '2026-10-26',
        'endDate': '2026-11-01',
      });
    },
  );
  test('stale previous week cannot overwrite next week', () async {
    final fake = DelayedWeek();
    final cubit = ScheduleCubit(fake);
    final first = cubit.loadWeek(DateTime(2026, 11, 1));
    await cubit.loadWeek(DateTime(2026, 11, 2));
    fake.first.complete(const BranchSchedule(7, []));
    await first;
    expect(cubit.state.data!.branchId, 8);
    expect(calendarDate(cubit.state.anchor!), '2026-11-02');
    await cubit.close();
  });
  testWidgets(
    'weekly matrix scrolls both axes with persistent reduced-motion warning',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: WeekBoard(
                start: DateTime(2026, 10, 26),
                data: const BranchSchedule(7, [
                  CourtSchedule(21, 'Sân 1', [
                    CourtSession(
                      bookingId: 42,
                      date: '2026-10-26',
                      start: '09:00',
                      end: '09:30',
                      status: 'CHECKED_IN',
                      name: 'Khoa',
                      endingSoon: true,
                    ),
                  ]),
                ]),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Table), findsOneWidget);
      expect(find.text('Sắp hết giờ'), findsOneWidget);
      await tester.drag(find.byType(Table), const Offset(-450, -300));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  test('refreshing the same week keeps the board while loading and on failure',
      () async {
    final fake = ControlledWeek();
    final cubit = ScheduleCubit(fake);
    await cubit.loadWeek(DateTime(2026, 11, 2));
    expect(cubit.state.data, isNotNull);
    fake.pending = Completer();
    final refresh = cubit.refresh();
    expect(cubit.state.loading, isTrue);
    expect(cubit.state.data, isNotNull);
    fake.pending!.completeError(const NetworkFailure());
    await refresh;
    expect(cubit.state.error, isNotNull);
    expect(cubit.state.data, isNotNull);
    await cubit.close();
  });
}

class ControlledWeek extends FakeOperations {
  Completer<BranchSchedule>? pending;
  @override
  Future<BranchSchedule> week(String start, String end) =>
      pending?.future ?? Future.value(const BranchSchedule(7, []));
}
