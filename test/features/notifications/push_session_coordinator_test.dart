import 'package:fcourt/features/notifications/domain/push_session_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'registers once per authenticated session and unregisters on logout',
    () async {
      var registrations = 0;
      var unregistrations = 0;
      final coordinator = PushSessionCoordinator(
        register: () async => registrations++,
        unregister: () async => unregistrations++,
      );

      coordinator.onAuthenticationChanged(false);
      coordinator.onAuthenticationChanged(true);
      coordinator.onAuthenticationChanged(true);
      await coordinator.settled;
      expect(registrations, 1);
      expect(unregistrations, 0);

      coordinator.onAuthenticationChanged(false);
      await coordinator.settled;
      expect(unregistrations, 1);
      expect(coordinator.isLoggedIn, isFalse);
    },
  );

  test('re-registers on token refresh only while authenticated', () async {
    var registrations = 0;
    final coordinator = PushSessionCoordinator(
      register: () async => registrations++,
      unregister: () async {},
    );

    coordinator.onTokenRefresh();
    coordinator.onAuthenticationChanged(true);
    coordinator.onTokenRefresh();
    await coordinator.settled;
    expect(registrations, 2);
  });

  test(
    'swallows API failures so push does not block auth transitions',
    () async {
      final coordinator = PushSessionCoordinator(
        register: () async => throw StateError('network error'),
        unregister: () async => throw StateError('network error'),
      );

      coordinator.onAuthenticationChanged(true);
      await coordinator.settled;
      coordinator.onAuthenticationChanged(false);
      await coordinator.settled;
      expect(coordinator.isLoggedIn, isFalse);
    },
  );
}
