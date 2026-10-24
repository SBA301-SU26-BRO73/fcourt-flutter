import 'dart:async';

import 'package:dio/dio.dart';
import 'package:fcourt/features/booking/data/datasources/booking_remote_data_source.dart';
import 'package:fcourt/features/booking/data/repositories/booking_repository_impl.dart';
import 'package:fcourt/features/booking/domain/entities/booking_hold.dart';
import 'package:fcourt/features/booking/domain/entities/booking_selection.dart';
import 'package:fcourt/features/booking/domain/repositories/booking_repository.dart';
import 'package:fcourt/features/booking/domain/usecases/hold_booking.dart';
import 'package:fcourt/features/booking/presentation/bloc/booking_cubit.dart';
import 'package:fcourt/features/booking/presentation/pages/booking_summary_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_adapter.dart';

BookingSelection selection() => BookingSelection(
  courtId: 1,
  branchName: 'FCOURT Thủ Đức',
  courtName: 'Sân cầu lông 2',
  date: DateTime(2030, 1, 1),
  slots: const [
    BookingSlot(id: 1, startMinute: 1080, priceVnd: 75000),
    BookingSlot(id: 2, startMinute: 1110, priceVnd: 85000),
  ],
);

class FakeBookingRepository implements BookingRepository {
  int calls = 0;
  Completer<BookingHold>? pending;
  BookingFailure? failure;
  @override
  Future<BookingHold> hold(BookingSelection selection, String phone) async {
    calls++;
    if (failure case final error?) throw error;
    return pending?.future ??
        BookingHold(
          token: 'token',
          expiresAt: DateTime.now().add(const Duration(minutes: 5)),
        );
  }
}

void main() {
  test('validates Vietnam mobile prefixes and rejects malformed numbers', () {
    for (final phone in [
      '0312345678',
      '0512345678',
      '0712345678',
      '0812345678',
      '0912345678',
    ]) {
      expect(validateBookingPhone(phone), isNull);
    }
    for (final phone in [
      '',
      '0212345678',
      '+84912345678',
      '091234567',
      '09123456789',
      '09abcdefgh',
    ]) {
      expect(validateBookingPhone(phone), isNotNull);
    }
  });

  test('selection is immutable and adds VND exactly', () {
    final value = selection();
    expect(value.totalVnd, 160000);
    expect(value.apiDate, '2030-01-01');
    expect(() => value.slots.clear(), throwsUnsupportedError);
    expect(
      () => BookingSelection(
        courtId: 1,
        branchName: '',
        courtName: '',
        date: DateTime(2030),
        slots: [],
      ),
      throwsArgumentError,
    );
  });

  test('repository sends exact guest hold contract and reads expiry', () async {
    final adapter = FakeAdapter(
      (_) => jsonResponse(201, {
        'holdToken': 'server-token',
        'expiresAt': '2030-01-01T12:00:00Z',
      }),
    );
    final dio = Dio(BaseOptions(baseUrl: 'http://test'))
      ..httpClientAdapter = adapter;
    final repository = BookingRepositoryImpl(BookingRemoteDataSource(dio));
    final hold = await repository.hold(selection(), '0912345678');
    expect(hold.token, 'server-token');
    expect(hold.expiresAt.isUtc, isTrue);
    expect(adapter.requests.single.path, '/api/bookings/hold-slots');
    expect(adapter.requests.single.data, {
      'courtId': 1,
      'date': '2030-01-01',
      'slotIds': [1, 2],
      'guestPhone': '0912345678',
    });
  });

  test(
    'repository translates conflict and rejects expired/malformed holds',
    () async {
      for (final body in [
        null,
        {},
        {'holdToken': 'x', 'expiresAt': '2000-01-01T00:00:00Z'},
      ]) {
        final dio = Dio(BaseOptions(baseUrl: 'http://test'))
          ..httpClientAdapter = FakeAdapter(
            (_) => body == null
                ? ResponseBody.fromString(
                    'null',
                    201,
                    headers: {
                      Headers.contentTypeHeader: [Headers.jsonContentType],
                    },
                  )
                : jsonResponse(201, body),
          );
        await expectLater(
          BookingRepositoryImpl(BookingRemoteDataSource(dio))
              .hold(selection(), '0912345678'),
          throwsA(isA<BookingFailure>()),
        );
      }
      final dio = Dio(BaseOptions(baseUrl: 'http://test'))
        ..httpClientAdapter = FakeAdapter((_) => jsonResponse(409, {}));
      await expectLater(
        BookingRepositoryImpl(BookingRemoteDataSource(dio))
            .hold(selection(), '0912345678'),
        throwsA(
          isA<BookingFailure>().having(
            (e) => e.message,
            'message',
            contains('chọn lại'),
          ),
        ),
      );
    },
  );

  test(
    'cubit suppresses repeated taps while pending and after success',
    () async {
      final repository = FakeBookingRepository()
        ..pending = Completer<BookingHold>();
      final cubit = BookingCubit(HoldBooking(repository));
      final first = cubit.submit(selection(), 'Minh', '0912345678');
      await cubit.submit(selection(), 'Minh', '0912345678');
      expect(repository.calls, 1);
      repository.pending!.complete(
        BookingHold(token: 'held', expiresAt: DateTime(2030)),
      );
      await first;
      expect(cubit.state.checkout!.customerName, 'Minh');
      await cubit.submit(selection(), 'Minh', '0912345678');
      expect(repository.calls, 1);
      await cubit.close();
    },
  );

  test('cubit can retry failure and safely finish after disposal', () async {
    final repository = FakeBookingRepository()
      ..failure = const BookingFailure('Conflict');
    final cubit = BookingCubit(HoldBooking(repository));
    await cubit.submit(selection(), 'Minh', '0912345678');
    expect(cubit.state.status, BookingStatus.failed);
    repository.failure = null;
    repository.pending = Completer<BookingHold>();
    final retry = cubit.submit(selection(), 'Minh', '0912345678');
    await cubit.close();
    repository.pending!.complete(
      BookingHold(token: 'held', expiresAt: DateTime(2030)),
    );
    await retry;
    expect(repository.calls, 2);
  });

  testWidgets(
    'summary shows selected slots and prefilled profile; hands off hold once',
    (tester) async {
      final repository = FakeBookingRepository();
      BookingCheckout? checkout;
      await tester.pumpWidget(
        MaterialApp(
          home: BookingSummaryScreen(
            repository: repository,
            arguments: BookingSummaryArguments(
              selection: selection(),
              customerName: 'Minh',
              phone: '0912345678',
              onHeld: (value) => checkout = value,
            ),
          ),
        ),
      );
      expect(find.text('FCOURT Thủ Đức'), findsOneWidget);
      expect(find.text('18:00 – 18:30'), findsOneWidget);
      expect(find.textContaining('160.000'), findsOneWidget);
      expect(find.text('Minh'), findsOneWidget);
      final button = find.text('Tiến hành giữ chỗ & thanh toán');
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(repository.calls, 1);
      expect(checkout!.hold.token, 'token');
      expect(checkout!.selection.totalVnd, 160000);
      expect(find.textContaining('Đã giữ chỗ trong 5 phút'), findsOneWidget);
    },
  );

  testWidgets('guest form prevents invalid contact submission', (tester) async {
    final repository = FakeBookingRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: BookingSummaryScreen(
          repository: repository,
          arguments: BookingSummaryArguments(
            selection: selection(),
            onHeld: (_) => fail('No hold expected'),
          ),
        ),
      ),
    );
    await tester.ensureVisible(find.text('Tiến hành giữ chỗ & thanh toán'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tiến hành giữ chỗ & thanh toán'));
    await tester.pumpAndSettle();
    expect(find.text('Vui lòng nhập họ tên'), findsOneWidget);
    expect(find.textContaining('Nhập SĐT 10 số'), findsOneWidget);
    expect(repository.calls, 0);
  });

  testWidgets('conflict appears without losing contact and permits retry', (
    tester,
  ) async {
    final repository = FakeBookingRepository()
      ..failure = const BookingFailure('Khung giờ vừa có người đặt');
    await tester.pumpWidget(
      MaterialApp(
        home: BookingSummaryScreen(
          repository: repository,
          arguments: BookingSummaryArguments(
            selection: selection(),
            customerName: 'Minh',
            phone: '0912345678',
            onHeld: (_) {},
          ),
        ),
      ),
    );
    await tester.ensureVisible(find.text('Tiến hành giữ chỗ & thanh toán'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tiến hành giữ chỗ & thanh toán'));
    await tester.pumpAndSettle();
    expect(find.text('Khung giờ vừa có người đặt'), findsOneWidget);
    expect(find.text('Minh'), findsOneWidget);
    repository.failure = null;
    await tester.ensureVisible(find.text('Tiến hành giữ chỗ & thanh toán'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tiến hành giữ chỗ & thanh toán'));
    await tester.pumpAndSettle();
    expect(repository.calls, 2);
  });
}
