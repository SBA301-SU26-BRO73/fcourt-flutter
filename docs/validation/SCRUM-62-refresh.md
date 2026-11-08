# SCRUM-62: refresh slot availability

2026-11-06, Flutter 3.47.7 / Dart 3.13.5, Windows.

Availability reloads when the court, date, repository or schedule refresh changes.
Pending reloads hide old selectable slots; late responses cannot replace the
current day. Manual refresh, polling and resume all use the schedule refresh
version. Server booking authority still validates the final reservation.

Validation: `flutter analyze --no-pub` clean; all 593 tests pass, including
16 availability/counter tests. New widget tests cover date rollover, late old
responses, same-day held-slot changes and the schedule refresh button.

SDK, Pub cache, temporary files and logs are under `D:/fcourt-tools`. No
machine-specific paths or environment changes are committed. No layout changes.
