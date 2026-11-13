import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fcourt/core/error/failure.dart';
import 'package:fcourt/features/vouchers/domain/voucher_usage.dart';
import 'package:fcourt/features/vouchers/domain/voucher_usage_repository.dart';
import 'package:fcourt/features/vouchers/presentation/voucher_usage_cubit.dart';
import 'package:fcourt/features/vouchers/presentation/voucher_usage_history_dialog.dart';

class HistoryRepository implements VoucherUsageRepository {
  final calls = <String>[];
  Future<VoucherUsagePage> Function(int, String)? handler;
  @override
  Future<VoucherUsagePage> list(
    int id, {
    int page = 0,
    String search = '',
  }) async {
    calls.add('$page:$search');
    if (handler != null) return handler!(page, search);
    return VoucherUsagePage(
      List.generate(
        20,
        (i) => VoucherUsage(
          id: '${page * 20 + i}',
          voucherId: id,
          bookingId: page * 20 + i + 1,
          userId: i + 1,
          discountMinor: 10000,
          usedAt: DateTime.utc(2026, 11, 5),
          timeSource: VoucherUsageTimeSource.recordedAt,
        ),
      ),
      page,
      200,
      2000000,
    );
  }
}

void main() {
  test('stale responses cannot overwrite a newer query', () async {
    final old = Completer<VoucherUsagePage>();
    final repo = HistoryRepository()
      ..handler = (page, query) => query.isEmpty
          ? old.future
          : Future.value(VoucherUsagePage(const [], 0, 0, 2000000));
    final cubit = VoucherUsageCubit(repo, 1);
    final first = cubit.refresh();
    cubit.search('090');
    await cubit.refresh();
    old.complete(const VoucherUsagePage([], 0, 100, 1));
    await first;
    expect(cubit.state.query, '090');
    expect(cubit.state.total, 0);
    expect(cubit.state.totalDiscountMinor, 2000000);
    await cubit.close();
  });
  test('pagination retries the failed page and clears private rows on revoked access', () async {
    final repo = HistoryRepository();
    final cubit = VoucherUsageCubit(repo, 1);
    await cubit.refresh();
    repo.handler = (_, _) =>
        Future.error(const ServerFailure('Unavailable', statusCode: 503));
    await cubit.loadMore();
    expect(cubit.state.items.length, 20);
    expect(cubit.state.failedPage, 1);
    repo.handler = null;
    await cubit.retry();
    expect(cubit.state.items.length, 40);
    expect(repo.calls.last, '1:');
    repo.handler = (_, _) =>
        Future.error(const ServerFailure('Forbidden', statusCode: 403));
    await cubit.refresh();
    expect(cubit.state.items, isEmpty);
    expect(cubit.state.totalDiscountMinor, isNull);
    await cubit.close();
  });
  testWidgets('modal renders legacy fallback and loads pages on demand', (
    tester,
  ) async {
    final repo = HistoryRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: VoucherUsageHistoryDialog(
          repository: repo,
          voucherId: 1,
          code: 'SAVE',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Lượt dùng SAVE'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('usage-phone')))
          .enabled,
      isNot(false),
    );
    expect(find.text('SĐT chưa được cung cấp'), findsWidgets);
    expect(find.textContaining('Ghi nhận lúc:'), findsWidgets);
    expect(repo.calls, ['0:']);
    expect(find.byType(Card).evaluate().length, lessThan(20));
    await tester.scrollUntilVisible(
      find.text('Xem thêm'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Xem thêm'));
    await tester.pumpAndSettle();
    expect(repo.calls, ['0:', '1:']);
  });
  testWidgets(
    'phone search is enabled, debounced and shows snapshot fields with fallbacks',
    (tester) async {
      final repo = HistoryRepository()
        ..handler = (page, query) => Future.value(
          VoucherUsagePage(
            [
              VoucherUsage(
                id: 'a',
                voucherId: 1,
                bookingId: 5,
                userId: 9,
                discountMinor: 10000,
                usedAt: DateTime.utc(2026, 11, 5),
                timeSource: VoucherUsageTimeSource.paymentConfirmed,
                customerName: 'Nguyen Van A',
                customerPhone: '0912345678',
                bookingCode: 'FC00000005',
              ),
              if (query.isEmpty)
                VoucherUsage(
                  id: 'b',
                  voucherId: 1,
                  bookingId: 6,
                  userId: 10,
                  discountMinor: 10000,
                  usedAt: DateTime.utc(2026, 11, 5),
                  timeSource: VoucherUsageTimeSource.recordedAt,
                ),
            ],
            0,
            query.isEmpty ? 2 : 1,
            20000,
          ),
        );
      await tester.pumpWidget(
        MaterialApp(
          home: VoucherUsageHistoryDialog(
            repository: repo,
            voucherId: 1,
            code: 'SAVE',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('usage-phone')))
            .enabled,
        isNot(false),
      );
      expect(find.text('Nguyen Van A'), findsOneWidget);
      expect(find.text('0912345678'), findsOneWidget);
      expect(find.text('FC00000005'), findsOneWidget);
      expect(find.text('Khách hàng #10'), findsOneWidget);
      expect(find.text('SĐT chưa được cung cấp'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('usage-phone')), '0912');
      await tester.pump(const Duration(milliseconds: 100));
      expect(repo.calls, ['0:']);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(repo.calls, ['0:', '0:0912']);
      expect(find.text('1 lượt dùng'), findsOneWidget);
      expect(find.text('Khách hàng #10'), findsNothing);
    },
  );
}
