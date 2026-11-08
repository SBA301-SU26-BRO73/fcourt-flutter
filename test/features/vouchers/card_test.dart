import 'package:fcourt/core/config/app_config.dart';
import 'package:fcourt/features/vouchers/data/voucher_model.dart';
import 'package:fcourt/features/vouchers/presentation/voucher_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'repository_test.dart' show voucherJson;

void main() {
  testWidgets('cards distinguish active expired and switched-off vouchers', (
    tester,
  ) async {
    final rows = [
      voucherJson(),
      {
        ...voucherJson(id: 2),
        'startDate': '2019-01-01T00:00:00Z',
        'endDate': '2020-01-01T00:00:00Z',
      },
      voucherJson(id: 3, status: 'EXPIRED'),
    ];
    bool? changed;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              for (final row in rows)
                VoucherCard(
                  voucher: VoucherModel.parse(row, 1),
                  now: DateTime.utc(2099, 11, 7),
                  busy: false,
                  onEdit: () {},
                  onEnabled: (value) => changed = value,
                ),
            ],
          ),
        ),
      ),
    );
    expect(find.text('Còn hiệu lực'), findsOneWidget);
    expect(find.text('Hết hạn'), findsOneWidget);
    final expired = find.byWidgetPredicate(
      (widget) => widget is VoucherCard && widget.voucher.id == 2,
    );
    expect(
      tester
          .widget<Switch>(
            find.descendant(of: expired, matching: find.byType(Switch)),
          )
          .onChanged,
      isNull,
    );
    await tester.tap(find.byType(Switch).first);
    expect(changed, isFalse);
    await tester.scrollUntilVisible(find.text('Đã tắt'), 200);
    expect(find.text('Đã tắt'), findsOneWidget);
  });
  test('voucher base URL is configurable with gateway fallback', () {
    expect(
      const AppConfig(env: AppEnv.dev, apiBaseUrl: 'http://gateway').voucherUrl,
      'http://gateway',
    );
    expect(
      const AppConfig(
        env: AppEnv.dev,
        apiBaseUrl: 'http://gateway',
        voucherBaseUrl: 'http://voucher:8086',
      ).voucherUrl,
      'http://voucher:8086',
    );
  });
}
