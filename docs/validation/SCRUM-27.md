# SCRUM-27 validation

2026-11-01, Flutter 3.47.7 / Dart 3.13.5.

- `flutter analyze --no-pub`: no issues.
- `flutter test --no-pub --coverage`: 25 passed, no skipped tests.
- New staff feature line coverage: 298/329 (90.58%).
- HTTP adapter tests verify branch filtering, page offsets, exact create/update
  payloads, immutable credentials on edit, lifecycle endpoints and error mapping.
- Widget tests cover create/save feedback, edit, disable confirmation, recovery,
  no-branch/empty list and unchanged UUID/locked payload after uncertain failure.
- Layout tests: 320/1000 logical pixels with 2x text scaling, no exceptions.
- Render inspected in Chrome at desktop and 390x844 with existing dark Material 3
  theme using a temporary preview app and fixture repository outside the repo.
  Fixture display names had an encoding defect in that temporary preview; actual
  feature labels are UTF-8 and render correctly. This is visual QA, not real API.
- Backend reactivation support: full staff Maven verify with PostgreSQL/Kafka
  passes; IAM reactivation remains an explicitly proposed downstream boundary.

Not verified: live login, IAM/facility/gateway integration, Android APK/device.
Machine has no Android SDK. Production endpoint remains a placeholder.
These limits prevent claiming full end-to-end or production acceptance.
