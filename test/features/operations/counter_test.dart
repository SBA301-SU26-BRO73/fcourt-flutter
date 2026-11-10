import 'package:dio/dio.dart';
import 'package:fcourt/core/error/failure.dart';
import 'package:fcourt/features/operations/domain/counter.dart';
import 'package:fcourt/features/operations/data/http_counter_repository.dart';
import 'package:fcourt/features/operations/presentation/walk_in_sheet.dart';
import 'package:fcourt/features/operations/presentation/checkout_dialog.dart';
import 'package:fcourt/features/operations/presentation/available_court_slots.dart';
import 'package:fcourt/features/operations/domain/schedule.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_adapter.dart';

class FakeCounter implements CounterRepository {
  Failure? error;
  final keys = <String>[];
  final checkoutFees = <int>[];
  List<int>? selected;
  @override
  Future<List<AvailableSlot>> slots(int court, String date) async => const [
    AvailableSlot(1, '09:00', '09:30', 1000000, true),
    AvailableSlot(2, '09:30', '10:00', 2000000, true),
    AvailableSlot(3, '10:00', '10:30', 2000000, false),
    AvailableSlot(4, '11:00', '11:30', 2000000, true),
  ];
  @override
  Future<CashReceipt> create(
    int court,
    String date,
    List<int> slots,
    String phone,
    String name,
    String key,
  ) async {
    keys.add(key);
    selected = slots;
    if (error != null) throw error!;
    return const CashReceipt('INV-1', 3000000, 0, 3000000);
  }

  @override
  Future<CashReceipt> checkoutPreview(int id) async =>
      const CashReceipt('INV-1', 3000000, 100000, 3100000);
  @override
  Future<void> checkout(
    int booking,
    String key, {
    required int expectedSurcharge,
    required int expectedTotal,
  }) async {
    keys.add(key);
    checkoutFees.add(expectedSurcharge);
    if (error != null) throw error!;
  }
}

void main() {
  testWidgets(
    'authoritative playing session is red and blocks stale available slot',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AvailableCourtSlots(
              repository: FakeCounter(),
              courtId: 21,
              date: '2026-11-01',
              onSelected: (_) => fail('Occupied slot must not be selectable'),
              sessions: const [
                CourtSession(
                  bookingId: 42,
                  date: '2026-11-01',
                  start: '09:00',
                  end: '09:30',
                  status: 'CHECKED_IN',
                  name: 'Khoa',
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final button = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, '09:00\nĐang chơi · Khoa'),
      );
      expect(button.onPressed, isNull);
      expect(
        button.style!.backgroundColor!.resolve({WidgetState.disabled}),
        const Color(0xFFB3261E),
      );
    },
  );
  testWidgets('tapped slot prefills exact start and exposes recent contact', (
    tester,
  ) async {
    final fake = FakeCounter();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WalkInSheet(
            repository: fake,
            courtId: 21,
            courtName: 'Sân 1',
            date: '2026-11-01',
            initialSlotId: 2,
            recentGuests: const {'0912345678': 'Khoa'},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('09:30–10:00'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(1), '091');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Khoa · 0912345678'));
    await tester.tap(find.text('Khoa · 0912345678'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).first)
          .controller!
          .text,
      'Khoa',
    );
    await tester.ensureVisible(find.text('Xác nhận & thu tiền mặt'));
    await tester.tap(find.text('Xác nhận & thu tiền mặt'));
    await tester.pumpAndSettle();
    expect(fake.selected, [2]);
    expect(find.text('Đã tạo đơn tiền mặt'), findsOneWidget);
  });
  testWidgets('stale tapped slot cannot submit a newly occupied time', (
    tester,
  ) async {
    final fake = FakeCounter();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WalkInSheet(
            repository: fake,
            courtId: 21,
            courtName: 'Sân 1',
            date: '2026-11-01',
            initialSlotId: 3,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Xác nhận & thu tiền mặt'),
          )
          .onPressed,
      isNull,
    );
    expect(fake.keys, isEmpty);
  });
  testWidgets('slot strip emits only available selected identity', (
    tester,
  ) async {
    int? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AvailableCourtSlots(
            repository: FakeCounter(),
            courtId: 21,
            date: '2026-11-01',
            onSelected: (slot) => selected = slot.id,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('09:30\nTrống'));
    expect(selected, 2);
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, '10:00\nKhông trống'),
          )
          .onPressed,
      isNull,
    );
  });
  test('availability sorts slots and rejects duplicate identities', () async {
    var duplicate = false;
    final dio = Dio(BaseOptions(baseUrl: 'http://test'))
      ..httpClientAdapter = FakeAdapter(
        (r) => jsonResponse(200, [
          {
            'slotId': 2,
            'startTime': '09:30',
            'endTime': '10:00',
            'price': 10000,
            'status': 'BOOKED',
          },
          {
            'slotId': duplicate ? 2 : 1,
            'startTime': '09:00',
            'endTime': '09:30',
            'price': 10000,
            'status': 'AVAILABLE',
          },
        ]),
      );
    final repo = HttpCounterRepository(dio, dio);
    expect((await repo.slots(21, '2026-11-01')).first.id, 1);
    duplicate = true;
    await expectLater(
      repo.slots(21, '2026-11-01'),
      throwsA(isA<UnknownFailure>()),
    );
  });
  test('mismatched server cash invoice never reports success', () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://test'))
      ..httpClientAdapter = FakeAdapter(
        (r) => jsonResponse(200, {
          'courtId': 21,
          'date': '2026-11-01',
          'status': 'CHECKED_IN',
          'paymentMethod': 'CASH',
          'amount': 20000,
          'invoice': {
            'receiptCode': 'INV',
            'baseAmount': 10000,
            'surchargeAmount': 0,
            'totalAmount': 20000,
          },
        }),
      );
    await expectLater(
      HttpCounterRepository(
        dio,
        dio,
      ).create(21, '2026-11-01', [1], '0912345678', 'Khoa', 'key'),
      throwsA(isA<UnknownFailure>()),
    );
  });
  test('money parses decimal snapshots exactly and rejects invalid totals', () {
    expect(parseMoney('10000.25'), 1000025);
    expect(parseMoney(10000), 1000000);
    expect(moneyLabel(1000025), '10.000,25 ₫');
    for (final value in ['-1', 'NaN', '1e8', '1.234', '100000000']) {
      expect(() => parseMoney(value), throwsFormatException);
    }
  });
  test(
    'contiguous selection rejects busy gaps and out-of-range slots',
    () async {
      final slots = await FakeCounter().slots(1, '2026-11-01');
      expect(contiguousSelection(slots, 0, 2).map((s) => s.id), [1, 2]);
      expect(contiguousSelection(slots, 0, 3), isEmpty);
      expect(contiguousSelection(slots, 2, 2), isEmpty);
      expect(contiguousSelection(slots, -1, 1), isEmpty);
      expect(contiguousSelection(slots, 0, 49), isEmpty);
      expect(businessToday(DateTime.utc(2026, 10, 31, 18)), '2026-11-01');
    },
  );
  test('http sends contact slots and key but never price or cashier', () async {
    final adapter = FakeAdapter(
      (r) => jsonResponse(
        200,
        r.method == 'GET'
            ? {'bookingId': 42, 'surchargeAmount': 0, 'totalAmount': 20000}
            : r.method == 'PUT'
            ? {'bookingId': 42, 'status': 'COMPLETED'}
            : {
                'courtId': 21,
                'date': '2026-11-01',
                'status': 'CHECKED_IN',
                'paymentMethod': 'CASH',
                'amount': 20000,
                'invoice': {
                  'receiptCode': 'INV',
                  'baseAmount': 20000,
                  'surchargeAmount': 0,
                  'totalAmount': 20000,
                },
              },
      ),
    );
    final dio = Dio(BaseOptions(baseUrl: 'http://test'))
      ..httpClientAdapter = adapter;
    final repo = HttpCounterRepository(dio, dio);
    expect(
      (await repo.create(
        21,
        '2026-11-01',
        [1],
        '0912345678',
        'Khoa',
        'same',
      )).total,
      2000000,
    );
    expect(adapter.requests.last.data, {
      'courtId': 21,
      'date': '2026-11-01',
      'slotIds': [1],
      'guestPhone': '0912345678',
      'guestName': 'Khoa',
    });
    expect(adapter.requests.last.headers['Idempotency-Key'], 'same');
    expect((await repo.checkoutPreview(42)).total, 2000000);
    await repo.checkout(
      42,
      'checkout',
      expectedSurcharge: 100000,
      expectedTotal: 2000000,
    );
    expect(adapter.requests.last.data, {
      'expectedSurcharge': '1000.00',
      'expectedTotal': '20000.00',
    });
  });
  testWidgets('walk-in keeps original selection and key after unknown result', (
    tester,
  ) async {
    final fake = FakeCounter()..error = const NetworkFailure();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WalkInSheet(
            repository: fake,
            courtId: 21,
            courtName: 'Sân 1',
            date: '2026-11-01',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<int>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('09:00–09:30').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Khoa');
    await tester.enterText(find.byType(TextFormField).at(1), '0912345678');
    await tester.ensureVisible(find.text('Xác nhận & thu tiền mặt'));
    await tester.tap(find.text('Xác nhận & thu tiền mặt'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Thử lại lệnh cũ'));
    await tester.tap(find.text('Thử lại lệnh cũ'));
    await tester.pumpAndSettle();
    expect(fake.keys, hasLength(2));
    expect(fake.keys[0], fake.keys[1]);
    expect(fake.selected, [1]);
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField).first).enabled,
      isFalse,
    );
  });
  testWidgets('walk-in uses a fresh key after a definite rejection', (
    tester,
  ) async {
    final fake = FakeCounter()
      ..error = const ServerFailure('Invalid phone', statusCode: 400);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WalkInSheet(
            repository: fake,
            courtId: 21,
            courtName: 'Sân 1',
            date: '2026-11-01',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<int>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('09:00–09:30').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Khoa');
    await tester.enterText(find.byType(TextFormField).at(1), '0912345678');
    await tester.ensureVisible(find.text('Xác nhận & thu tiền mặt'));
    await tester.tap(find.text('Xác nhận & thu tiền mặt'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Xác nhận & thu tiền mặt'));
    await tester.tap(find.text('Xác nhận & thu tiền mặt'));
    await tester.pumpAndSettle();
    expect(fake.keys, hasLength(2));
    expect(fake.keys[0], isNot(fake.keys[1]));
  });
  testWidgets(
    'checkout shows fee before explicit submit and preserves retry key',
    (tester) async {
      final fake = FakeCounter()..error = const NetworkFailure();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: CheckoutDialog(repository: fake, bookingId: 42)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Dự tính phụ thu'), findsOneWidget);
      expect(fake.keys, isEmpty);
      await tester.tap(find.widgetWithText(FilledButton, 'Xác nhận trả sân'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Xác nhận trả sân'));
      await tester.pumpAndSettle();
      expect(fake.keys[0], fake.keys[1]);
    },
  );
  testWidgets('checkout conflict requires fresh quote and fresh command', (
    tester,
  ) async {
    final fake = FakeCounter()
      ..error = const ServerFailure('Fee changed', statusCode: 409);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CheckoutDialog(repository: fake, bookingId: 42)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Xác nhận trả sân'));
    await tester.pumpAndSettle();
    expect(fake.checkoutFees, [100000]);
    expect(
      find.textContaining('Phí hoặc trạng thái đã thay đổi'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(FilledButton, 'Kiểm tra lại phí'),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Kiểm tra lại phí'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Xác nhận trả sân'));
    await tester.pumpAndSettle();
    expect(fake.keys[0], isNot(fake.keys[1]));
  });
}
