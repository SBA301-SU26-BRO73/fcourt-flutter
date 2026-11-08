import 'package:dio/dio.dart';
import 'package:fcourt/core/error/failure.dart';
import 'package:fcourt/src/features/customer_slots/data/slot_remote_data_source.dart';
import 'package:fcourt/src/features/customer_slots/data/slot_repository_impl.dart';
import 'package:fcourt/src/features/customer_slots/domain/court_slot.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_adapter.dart';

Map<String, Object> row(
  int id,
  String start,
  String end, {
  String status = 'AVAILABLE',
  num price = 75000,
}) => {
  'slotId': id,
  'startTime': start,
  'endTime': end,
  'price': price,
  'status': status,
};

void main() {
  test('uses anonymous SCRUM-22 array contract, orders slots and preserves decimal prices', () async {
    final adapter = FakeAdapter(
      (_) => jsonResponse(200, [
        row(2, '07:30:00', '08:00:00', price: .20),
        row(1, '07:00:00', '07:30:00', price: .10),
        row(48, '23:30:00', '00:00:00', price: 90000.25),
      ]),
    );
    final dio = Dio(BaseOptions(baseUrl: 'http://test'))
      ..httpClientAdapter = adapter;
    final result = await SlotRepositoryImpl(SlotRemoteDataSource(dio))
        .getSlots(9, DateTime(2030, 1, 2));
    final request = adapter.requests.single;
    expect(request.path, '/api/public/courts/9/slots');
    expect(request.queryParameters, {'date': '2030-01-02'});
    expect(request.extra['skipAuth'], isTrue);
    expect(request.headers.containsKey('Authorization'), isFalse);
    expect(result.map((s) => s.id), [1, 2, 48]);
    expect(result.take(2).fold<int>(0, (sum, s) => sum + s.priceMinor), 30);
    expect(result.last.endMinute, 1440);
    expect(result.last.priceMinor, 9000025);
    expect(result.length, 3); // No synthesized slots in closed hours.
  });

  test('maps all backend states and unknown states fail closed', () async {
    final states = [
      'AVAILABLE',
      'BOOKED',
      'HOLD',
      'OUT_OF_SERVICE',
      'EXPIRED',
      'NEW_STATE',
    ];
    final dio = Dio(BaseOptions(baseUrl: 'http://test'))
      ..httpClientAdapter = FakeAdapter(
        (_) => jsonResponse(200, [
          for (var i = 0; i < states.length; i++)
            row(i + 1, '0${i + 1}:00:00', '0${i + 1}:30:00', status: states[i]),
        ]),
      );
    final result = await SlotRepositoryImpl(SlotRemoteDataSource(dio))
        .getSlots(1, DateTime(2030));
    expect(result.map((s) => s.status), SlotStatus.values);
  });

  test(
    'rejects duplicate, overlapping, wrong duration and malformed schedules',
    () async {
      final invalid = [
        [row(1, '07:00:00', '07:30:00'), row(1, '08:00:00', '08:30:00')],
        [row(1, '07:00:00', '07:30:00'), row(2, '07:00:00', '07:30:00')],
        [row(1, '07:00:00', '08:00:00')],
        [row(1, '25:00:00', '25:30:00')],
        [row(1, '07:00:00', '07:30:00', price: -1)],
        [row(1, '07:00:00', '07:30:00', price: .123)],
      ];
      for (final data in invalid) {
        final dio = Dio(BaseOptions(baseUrl: 'http://test'))
          ..httpClientAdapter = FakeAdapter((_) => jsonResponse(200, data));
        await expectLater(
          SlotRepositoryImpl(SlotRemoteDataSource(dio))
              .getSlots(1, DateTime(2030)),
          throwsA(isA<UnknownFailure>()),
        );
      }
    },
  );

  test('handles empty schedule, missing court and upstream failure without inventing availability', () async {
    for (final status in [200, 404, 503]) {
      final dio = Dio(BaseOptions(baseUrl: 'http://test'))
        ..httpClientAdapter = FakeAdapter(
          (_) => jsonResponse(status, status == 200 ? [] : {}),
        );
      final future = SlotRepositoryImpl(SlotRemoteDataSource(dio))
          .getSlots(1, DateTime(2030));
      if (status == 200) {
        expect(await future, isEmpty);
      } else {
        await expectLater(
          future,
          throwsA(
            isA<ServerFailure>().having((f) => f.statusCode, 'status', status),
          ),
        );
      }
    }
  });
}
