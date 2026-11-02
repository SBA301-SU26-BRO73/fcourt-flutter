import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fcourt/features/payment/presentation/pages/booking_success_screen.dart';
import 'package:fcourt/features/payment/presentation/pages/ticket_brightness_scope.dart';

import 'ticket_test.dart' show Tickets, Saver, args;

class Brightness implements TicketBrightness {
  final calls = <String>[];
  @override
  Future<void> acquire() async {
    calls.add('max');
  }

  @override
  Future<void> release() async {
    calls.add('restore');
  }
}

void main() {
  testWidgets('copy preserves every ticket digit and reports completion', (
    tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    final brightness = Brightness();
    await tester.pumpWidget(
      MaterialApp(
        home: BookingSuccessScreen(
          repository: Tickets(),
          saver: Saver(),
          arguments: args,
          brightness: brightness,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Sao chép mã vé'), 200, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sao chép mã vé'));
    await tester.pumpAndSettle();
    expect(copied, '12345678901234567890123456789012');
    expect(find.text('Đã sao chép mã vé'), findsOneWidget);
    expect(brightness.calls, ['max']);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(brightness.calls, ['max', 'restore']);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
  });
  testWidgets(
    'brightness restores on background, resumes once, and restores on disposal',
    (tester) async {
      final brightness = Brightness();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(
        MaterialApp(
          home: TicketBrightnessScope(
            controller: brightness,
            child: const Text('QR'),
          ),
        ),
      );
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(brightness.calls, ['max', 'restore', 'max']);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(brightness.calls.last, 'restore');
    },
  );
}
