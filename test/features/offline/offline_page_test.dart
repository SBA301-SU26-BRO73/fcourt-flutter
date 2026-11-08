import 'package:fcourt/features/offline/presentation/offline_check_in_page.dart';
import 'package:fcourt/features/operations/domain/schedule.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../operations/operations_test.dart' show FakeOperations;

class CachedOperations extends FakeOperations {
  @override
  Future<TicketPreview> preview(String code) async => const TicketPreview(
    bookingId: 42,
    branchId: 7,
    courtName: 'Sân 1',
    date: '2026-11-01',
    start: '09:00',
    end: '10:00',
    name: 'Khoa',
    offline: true,
  );
}

void main() {
  for (final width in [390.0, 1000.0]) {
    testWidgets('offline entry supports large text at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: OfflineCheckInPage(
              repository: CachedOperations(),
              syncPanel: const Text('Đang chờ: 0'),
              onReconnect: () {},
              onLogin: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Kết nối lại để xác thực online'),
        200,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('offline page supports manual admission and reconnect actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = CachedOperations();
    var reconnects = 0, logins = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: OfflineCheckInPage(
          repository: repository,
          syncPanel: const Text('Đang chờ: 0'),
          onReconnect: () => reconnects++,
          onLogin: () => logins++,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nhập mã vé'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField),
      '12345678901234567890123456789012',
    );
    await tester.tap(find.text('Kiểm tra & Check-in'));
    await tester.pumpAndSettle();
    expect(repository.writes, 0);
    await tester.tap(find.widgetWithText(FilledButton, 'Xác nhận nhận sân'));
    await tester.pumpAndSettle();
    expect(find.text('HỢP LỆ (OFFLINE)'), findsOneWidget);
    await tester.tap(find.text('Hoàn tất nhận sân'));
    await tester.pumpAndSettle();
    expect(repository.writes, 1);
    await tester.tap(find.text('Kết nối lại để xác thực online'));
    await tester.tap(find.text('Về màn hình đăng nhập'));
    expect(reconnects, 1);
    expect(logins, 1);
    expect(tester.takeException(), isNull);
  });
}
