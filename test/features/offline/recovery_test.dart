import 'dart:async';

import 'package:fcourt/features/offline/data/offline_recovery.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'foreground starts with drain then refresh and polls every two seconds',
    (tester) async {
      final events = <String>[];
      final recovery = OfflineRecovery(
        flush: () async {
          events.add('drain');
        },
        shiftSync: () async {
          events.add('snapshot');
          return true;
        },
      );
      recovery.resume();
      await tester.pump();
      expect(events, ['drain', 'snapshot']);
      await tester.pump(const Duration(seconds: 2));
      expect(events, ['drain', 'snapshot', 'drain']);
      recovery.pause();
      await tester.pump(const Duration(minutes: 10));
      expect(events, hasLength(3));
      recovery.resume();
      await tester.pump();
      expect(events.sublist(3), ['drain', 'snapshot']);
      recovery.dispose();
    },
  );

  testWidgets(
    'failed initial snapshot retries automatically and refreshes periodically',
    (tester) async {
      var snapshots = 0;
      var online = false;
      final recovery = OfflineRecovery(
        flush: () async {},
        shiftSync: () async {
          snapshots++;
          return online;
        },
      );
      recovery.resume();
      await tester.pump();
      expect(snapshots, 1);
      online = true;
      await tester.pump(const Duration(seconds: 30));
      expect(snapshots, 2);
      await tester.pump(const Duration(minutes: 5));
      expect(snapshots, 3);
      recovery.dispose();
    },
  );

  testWidgets(
    'reconnect events coalesce while recovering and stop after dispose',
    (tester) async {
      var count = 0;
      final request = Completer<bool>();
      final recovery = OfflineRecovery(
        flush: () async {},
        shiftSync: () {
          count++;
          return request.future;
        },
      );
      recovery.resume();
      await tester.pump();
      await recovery.recover();
      expect(count, 1);
      recovery.dispose();
      request.complete(false);
      await tester.pump(const Duration(minutes: 10));
      await recovery.recover();
      expect(count, 1);
    },
  );

  testWidgets('unexpected snapshot errors schedule a retry without crashing', (
    tester,
  ) async {
    var calls = 0;
    final recovery = OfflineRecovery(
      flush: () async {},
      shiftSync: () async {
        calls++;
        throw StateError('storage');
      },
    );
    recovery.resume();
    await tester.pump();
    await tester.pump(const Duration(seconds: 30));
    expect(calls, 2);
    recovery.dispose();
  });
}
