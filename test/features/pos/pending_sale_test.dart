import 'dart:convert';

import 'package:fcourt/core/error/failure.dart';
import 'package:fcourt/core/storage/token_storage.dart';
import 'package:fcourt/features/pos/data/secure_pos_sale_store.dart';
import 'package:fcourt/features/pos/domain/pending_sale.dart';
import 'package:fcourt/features/pos/domain/pos.dart';
import 'package:fcourt/features/pos/presentation/pos_cubit.dart';
import 'package:fcourt/features/pos/presentation/pos_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pos_test.dart' show FakePos, product;

AuthTokens tokensFor(int user) => AuthTokens(
  accessToken:
      'header.${base64Url.encode(utf8.encode(jsonEncode({'sub': '$user'})))}.signature',
  refreshToken: 'fixture',
);

PendingSale sale(String key) =>
    PendingSale(key: key, method: 'BOOKING', bookingId: 42, cart: {product: 1});

class BrokenStore implements PosSaleStore {
  bool failRead = false, failSave = false, failClear = false;
  PendingSale? value;
  @override
  Future<PendingSale?> load() async {
    if (failRead) throw const UnknownFailure('read failed');
    return value;
  }

  @override
  Future<void> save(PendingSale sale) async {
    if (failSave) throw const UnknownFailure('save failed');
    value = sale;
  }

  @override
  Future<void> clear(String key) async {
    if (failClear) throw const UnknownFailure('clear failed');
    value = null;
  }
}

class CheckingPos extends FakePos {
  CheckingPos(this.store);
  final PosSaleStore store;
  @override
  Future<PosOrder> create(
    Map<int, int> quantities,
    String method,
    int? bookingId,
    String key,
  ) async {
    expect((await store.load())!.key, key);
    expect((await store.load())!.method, method);
    expect((await store.load())!.bookingId, bookingId);
    return super.create(quantities, method, bookingId, key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('reopening restores and retries the original persisted sale', () async {
    final tokens = InMemoryTokenStorage(tokensFor(100));
    final firstStore = SecurePosSaleStore(tokens);
    final remote = CheckingPos(firstStore)..error = const NetworkFailure();
    final first = PosCubit(remote, journal: firstStore);
    await first.load();
    first.quantity(product, 1);
    await first.sell('BOOKING', 42);
    final key = remote.keys.single;
    await first.close();

    final secondStore = SecurePosSaleStore(tokens);
    final second = PosCubit(remote, journal: secondStore);
    await second.load();
    expect(second.state.uncertain, isTrue);
    expect(second.pendingMethod, 'BOOKING');
    expect(second.pendingBooking, 42);
    second.quantity(product, 2);
    expect(second.count(1), 1);
    remote.error = null;
    await second.sell('CASH', null);
    expect(remote.keys, [key, key]);
    expect(remote.payloads[0], remote.payloads[1]);
    expect(await secondStore.load(), isNull);
    expect(second.state.receipt, isNotNull);
    await second.close();
  });

  test('account switch cannot read, overwrite or clear another sale', () async {
    final tokens = InMemoryTokenStorage(tokensFor(100));
    final first = SecurePosSaleStore(tokens);
    await first.save(sale('a'));
    await tokens.save(tokensFor(200));
    await expectLater(first.load(), throwsA(isA<UnauthorizedFailure>()));
    await expectLater(first.clear('a'), throwsA(isA<UnauthorizedFailure>()));
    final second = SecurePosSaleStore(tokens);
    expect(await second.load(), isNull);
    await second.save(sale('b'));
    await tokens.save(tokensFor(100));
    expect((await first.load())!.key, 'a');
    await first.clear('a');
    await tokens.save(tokensFor(200));
    expect((await second.load())!.key, 'b');
  });

  test('concurrent screens cannot overwrite an unresolved command', () async {
    final tokens = InMemoryTokenStorage(tokensFor(100));
    Future<bool> attempt(String key) async {
      try {
        await SecurePosSaleStore(tokens).save(sale(key));
        return true;
      } on Failure {
        return false;
      }
    }

    final results = await Future.wait([attempt('a'), attempt('b')]);
    expect(results.where((success) => success), hasLength(1));
    expect((await SecurePosSaleStore(tokens).load())!.key, 'a');
  });

  test('corrupt journal fails closed and cannot be replaced', () async {
    FlutterSecureStorage.setMockInitialValues({
      'fcourt_pos_pending_100': 'invalid',
    });
    final store = SecurePosSaleStore(InMemoryTokenStorage(tokensFor(100)));
    final remote = FakePos();
    final cubit = PosCubit(remote, journal: store);
    await cubit.load();
    cubit.quantity(product, 1);
    await cubit.sell('CASH', null);
    expect(cubit.state.restoring, isTrue);
    expect(remote.keys, isEmpty);
    await expectLater(store.save(sale('new')), throwsA(isA<UnknownFailure>()));
    await cubit.close();
  });

  test('failed persistence never sends an unrecorded sale', () async {
    final store = BrokenStore()..failSave = true;
    final remote = FakePos();
    final cubit = PosCubit(remote, journal: store);
    await cubit.load();
    cubit.quantity(product, 1);
    await cubit.sell('CASH', null);
    expect(remote.keys, isEmpty);
    expect(cubit.state.uncertain, isTrue);
    store.failSave = false;
    await cubit.sell('BOOKING', 99);
    expect(remote.keys, hasLength(1));
    expect(cubit.state.receipt, isNotNull);
    await cubit.close();
  });

  test(
    'lost local cleanup retries the same successful server command',
    () async {
      final store = BrokenStore()..failClear = true;
      final remote = FakePos();
      final cubit = PosCubit(remote, journal: store);
      await cubit.load();
      cubit.quantity(product, 1);
      await cubit.sell('CASH', null);
      expect(cubit.state.uncertain, isTrue);
      store.failClear = false;
      await cubit.sell('CASH', null);
      expect(remote.keys[0], remote.keys[1]);
      expect(store.value, isNull);
      await cubit.close();
    },
  );

  test('definite server rejection clears pending sale', () async {
    final store = BrokenStore();
    final remote = FakePos()
      ..error = const ServerFailure('stock', statusCode: 409);
    final cubit = PosCubit(remote, journal: store);
    await cubit.load();
    cubit.quantity(product, 1);
    await cubit.sell('CASH', null);
    expect(store.value, isNull);
    expect(cubit.state.uncertain, isFalse);
    await cubit.close();
  });

  testWidgets('restored phone cart shows original method and reconciles once', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final tokens = InMemoryTokenStorage(tokensFor(100));
    await SecurePosSaleStore(tokens).save(sale('old-command'));
    final remote = FakePos()..status = 'ON_BOOKING';
    await tester.pumpWidget(
      MaterialApp(
        home: PosPage(repository: remote, journal: SecurePosSaleStore(tokens)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.shopping_cart_outlined));
    await tester.pumpAndSettle();
    expect(find.text('ID đơn đặt sân: 42'), findsOneWidget);
    expect(find.textContaining('Có lệnh bán chưa rõ kết quả'), findsOneWidget);
    await tester.ensureVisible(find.text('Thử lại lệnh bán cũ'));
    await tester.tap(find.text('Thử lại lệnh bán cũ'));
    await tester.pumpAndSettle();
    expect(remote.keys, ['old-command']);
    expect(find.text('POS-7'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
