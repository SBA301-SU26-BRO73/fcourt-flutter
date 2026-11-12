import 'package:fcourt/core/error/failure.dart';
import 'package:fcourt/features/operations/domain/manual_code.dart';
import 'package:fcourt/features/operations/presentation/manual_check_in.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'operations_test.dart' show FakeOperations;

class ManualOps extends FakeOperations {
  String? submitted;
  bool? channel;
  @override
  Future<int> checkIn(String code, String key, {bool manual = false}) {
    submitted = code;
    channel = manual;
    return super.checkIn(code, key, manual: manual);
  }
}

void main() {
  test('manual codes uppercase without arbitrary opaque grouping', () {
    expect(normalizeManualCode(' fc89234 '), 'FC-89234');
    expect(normalizeManualCode('fc-89234'), 'FC-89234');
    expect(
      normalizeManualCode('01234567890123456789012345678901'),
      '01234567890123456789012345678901',
    );
    expect(validateManualCode(' '), isNotNull);
    expect(validateManualCode('x' * 129), isNotNull);
    expect(validateManualCode('FC-89234'), isNull);
    expect(validateManualCode('FC\n42'), isNotNull);
    final formatter = ManualCodeFormatter();
    expect(
      formatter
          .formatEditUpdate(
            TextEditingValue.empty,
            const TextEditingValue(
              text: 'fc89234',
              selection: TextSelection.collapsed(offset: 7),
            ),
          )
          .text,
      'FC-89234',
    );
  });
  testWidgets(
    'dialog focuses keyboard and admits only through manual command',
    (tester) async {
      final fake = ManualOps();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<bool>(
                  context: context,
                  builder: (_) => ManualCheckIn(repository: fake),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(tester.testTextInput.isVisible, isTrue);
      await tester.enterText(find.byType(TextFormField), 'fc89234');
      await tester.tap(find.text('Kiểm tra & Check-in'));
      await tester.pumpAndSettle();
      expect(fake.writes, 0);
      await tester.tap(find.widgetWithText(FilledButton, 'Xác nhận nhận sân'));
      await tester.pumpAndSettle();
      expect(fake.channel, isTrue);
      expect(fake.submitted, 'FC-89234');
      expect(find.textContaining('Nhận sân thành công'), findsOneWidget);
      expect(find.text('Hoàn tất nhận sân'), findsNothing);
      expect(find.byType(ManualCheckIn), findsNothing);
    },
  );
  testWidgets('unknown ticket shows rejection without admission', (
    tester,
  ) async {
    final fake = ManualOps()
      ..error = const ServerFailure('Không tìm thấy vé', statusCode: 404);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ManualCheckIn(repository: fake)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'FC-99999');
    await tester.tap(find.text('Kiểm tra & Check-in'));
    await tester.pumpAndSettle();
    expect(find.text('Không tìm thấy vé'), findsOneWidget);
    expect(fake.writes, 0);
  });
}
