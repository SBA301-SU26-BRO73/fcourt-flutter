import 'package:dio/dio.dart';
import 'package:fcourt/core/error/failure.dart';
import 'package:fcourt/features/pos/domain/pos.dart';
import 'package:fcourt/features/pos/data/http_pos_repository.dart';
import 'package:fcourt/features/pos/presentation/pos_cubit.dart';
import 'package:fcourt/features/pos/presentation/pos_page.dart';
import 'package:fcourt/features/pos/presentation/order_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_adapter.dart';
import '../../helpers/wp3b_shots.dart';

const product = PosProduct(
  id: 1,
  name: 'Nước khoáng',
  category: 'Đồ uống',
  price: 1000000,
  stock: 2,
);

class FakePos implements PosRepository {
  Failure? error;
  final keys = <String>[];
  final payloads = <Map<int, int>>[];
  int reads = 0;
  String status = 'PAID';
  @override
  Future<List<PosProduct>> products({
    String query = '',
    String category = '',
    int offset = 0,
  }) async => [
    product,
    const PosProduct(
      id: 2,
      name: 'Hết hàng',
      category: 'Khác',
      price: 2000000,
      stock: 0,
    ),
  ];
  @override
  Future<PosOrder> create(
    Map<int, int> quantities,
    String method,
    int? bookingId,
    String key,
  ) async {
    keys.add(key);
    payloads.add(Map.of(quantities));
    if (error != null) throw error!;
    return PosOrder(7, 'POS-7', status, 1000000, [
      const PosLine(1, 'Nước khoáng', 1, 1000000),
    ]);
  }

  @override
  Future<PosOrder> order(int id) async {
    reads++;
    return const PosOrder(7, 'POS-7', 'ON_BOOKING', 1000000, [
      PosLine(1, 'Nước khoáng', 1, 1000000),
    ]);
  }

  @override
  Future<List<PosOrder>> history({int offset = 0}) async => [];
}

Map<String, dynamic> invoice({String status = 'PAID'}) => {
  'id': 7,
  'orderCode': 'POS-7',
  'status': status,
  'paymentMethod': status == 'PAID' ? 'CASH' : 'BOOKING',
  'bookingId': 42,
  'totalAmount': 10000,
  'items': [
    {
      'productId': 1,
      'productName': 'Water',
      'quantity': 1,
      'priceAtOrder': 10000,
      'lineTotal': 10000,
    },
  ],
};

void main() {
  test(
    'catalog and invoice reads preserve filters and payment state',
    () async {
      final adapter = FakeAdapter(
        (r) => jsonResponse(
          200,
          r.path.endsWith('products')
              ? [
                  {
                    'id': 1,
                    'name': 'Water',
                    'category': 'Drinks',
                    'price': 10000,
                    'active': true,
                    'stockQuantity': 2,
                    'imageUrl': null,
                  },
                ]
              : r.path.endsWith('/7')
              ? invoice(status: 'ON_BOOKING')
              : [invoice(status: 'ON_BOOKING')],
        ),
      );
      final dio = Dio(BaseOptions(baseUrl: 'http://test'))
        ..httpClientAdapter = adapter;
      final repo = HttpPosRepository(dio);
      expect(
        (await repo.products(
          query: 'wat',
          category: 'Drinks',
          offset: 50,
        )).single.stock,
        2,
      );
      expect(adapter.requests.last.queryParameters, {
        'query': 'wat',
        'category': 'Drinks',
        'limit': 50,
        'offset': 50,
      });
      expect((await repo.history()).single.mayHandOver, isTrue);
      expect((await repo.order(7)).status, 'ON_BOOKING');
      await expectLater(repo.order(8), throwsA(isA<UnknownFailure>()));
    },
  );
  testWidgets(
    'phone cart completes cash sale and displays authoritative receipt',
    (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(home: PosPage(repository: FakePos())),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Thêm Nước khoáng'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Giỏ hàng (1)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xác nhận xuất hóa đơn'));
      await tester.pumpAndSettle();
      expect(find.text('POS-7'), findsOneWidget);
      expect(find.text('Đã thanh toán'), findsOneWidget);
      await tester.tap(find.text('Đóng'));
      await tester.pumpAndSettle();
      expect(find.text('Chọn sản phẩm để bắt đầu bán hàng.'), findsOneWidget);
    },
  );
  testWidgets('history has useful empty state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: OrderHistory(repository: FakePos())),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Chưa có hóa đơn.'), findsOneWidget);
  });
  test('cart guards stock and immutable uncertain sale retries', () async {
    final fake = FakePos()..error = const NetworkFailure();
    final cubit = PosCubit(fake);
    await cubit.load();
    cubit.quantity(product, 3);
    expect(cubit.state.cart, isEmpty);
    cubit.quantity(product, 1);
    await cubit.sell('CASH', null);
    expect(cubit.state.uncertain, isTrue);
    cubit.quantity(product, 2);
    expect(cubit.count(1), 1);
    await cubit.sell('BOOKING', 99);
    expect(fake.keys[0], fake.keys[1]);
    expect(fake.payloads[0], fake.payloads[1]);
    fake.error = null;
    await cubit.sell('CASH', null);
    expect(cubit.state.receipt!.mayHandOver, isTrue);
    expect(cubit.state.cart, isEmpty);
    await cubit.close();
  });
  test(
    'definitive rejection allows cart correction and booking needs id',
    () async {
      final fake = FakePos()
        ..error = const ServerFailure('out of stock', statusCode: 409);
      final cubit = PosCubit(fake);
      cubit.quantity(product, 1);
      await cubit.sell('BOOKING', null);
      expect(fake.keys, isEmpty);
      await cubit.sell('CASH', null);
      expect(cubit.state.uncertain, isFalse);
      cubit.quantity(product, 0);
      expect(cubit.state.cart, isEmpty);
      await cubit.close();
    },
  );
  test('pos http sends only canonical product quantities and method', () async {
    final adapter = FakeAdapter((r) => jsonResponse(201, invoice()));
    final dio = Dio(BaseOptions(baseUrl: 'http://test'))
      ..httpClientAdapter = adapter;
    final result = await HttpPosRepository(dio)
        .create({1: 1}, 'CASH', null, 'same');
    expect(result.total, 1000000);
    expect(adapter.requests.single.data, {
      'paymentMethod': 'CASH',
      'items': [
        {'productId': 1, 'quantity': 1},
      ],
    });
    expect(adapter.requests.single.headers['Idempotency-Key'], 'same');
  });
  test('unbalanced invoice fails closed', () async {
    final adapter = FakeAdapter(
      (r) => jsonResponse(201, {...invoice(), 'totalAmount': 20000}),
    );
    final dio = Dio(BaseOptions(baseUrl: 'http://test'))
      ..httpClientAdapter = adapter;
    await expectLater(
      HttpPosRepository(dio).create({1: 1}, 'CASH', null, 'same'),
      throwsA(isA<UnknownFailure>()),
    );
  });
  testWidgets('pending invoice forbids handover then polls attachment', (
    tester,
  ) async {
    final fake = FakePos();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OrderDialog(
            repository: fake,
            order: PosOrder(7, 'POS-7', 'PENDING_CHARGE', 1000000, [
              const PosLine(1, 'Water', 1, 1000000),
            ]),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('CHƯA GIAO HÀNG'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(fake.reads, 1);
    expect(find.text('Đã gộp vào booking'), findsOneWidget);
    expect(find.textContaining('Có thể giao hàng'), findsOneWidget);
  });
  for (final width in [390.0, 1000.0]) {
    testWidgets('pos layout and out-of-stock control at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(home: PosPage(repository: FakePos())),
      );
      await tester.pumpAndSettle();
      expect(find.text('Nước khoáng'), findsOneWidget);
      final button = find
          .widgetWithIcon(IconButton, Icons.add_shopping_cart)
          .last;
      expect(tester.widget<IconButton>(button).onPressed, isNull);
      expect(tester.takeException(), isNull);
    });
  }
  for (final b in Brightness.values) {
    testWidgets('pos matches the WP3b look (${b.name})', (tester) async {
      await pumpShot(
        tester,
        b,
        PosPage(repository: FakePos()),
        name: 'pos',
      );
      expect(find.text('Quầy dịch vụ'), findsOneWidget);
    });
  }
}
