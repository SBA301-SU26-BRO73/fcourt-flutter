# Mobile role experience and validation — 2026-11-10

## Source and implementation

- Flutter base: `origin/dev` at `6979192`; working branch `fix/mobile-role-ui-ux`.
- Backend: pulled `dev` from `5108fa4` to `1158611`, rebuilt and restarted changed auth/booking/payment services. Other local services remain running.
- Preserved the existing local web/Firebase changes in `lib/main.dart` and `lib/app/app_dependencies.dart`.
- Used the current web CSS tokens (`fcourt-web/frontend/src/index.css`): emerald primary, pale green background, bordered white cards, dark green surfaces, rounded controls. Flutter uses Material 3 controls, readable spacing, large tap targets, responsive cards, and scrolling content.
- Home now has a primary action and described shortcuts for each role. Customer Home includes search, sport filters, booking history and transactions. ADMIN has booking/facility/analytics/staff/subscription/voucher shortcuts. STAFF has schedule/check-in and POS. SUPER_ADMIN has platform statistics, owner approval and catalog.
- Navigation exposes Home, the role's main task, account, and settings. Opening a task preserves a back path; Home resets navigation.
- Settings supports system/light/dark, applies the selection throughout the app and saves it in device storage. Queued writes preserve the last selection; a late startup read cannot override a new choice. Storage write failure is shown to the user.
- Sign-in and account screens share the theme; discovery search is placed before decorative artwork. Technical health checks remain available at `/health` without occupying customer-facing discovery actions.
- Available slot cells now expose a semantic tap action; booked slots do not. This fixes selection through assistive technology.
- Customer booking routes are restricted to CUSTOMER in the client; server authorization remains authoritative.

## Booking integration fixed

Previously `/courts/:courtId/slots` omitted `onContinue`, so selection stopped at a temporary estimate sheet. The real dependency configuration now connects:

`slots → /booking/summary → hold → /booking/confirm → POST /api/bookings → /payments/checkout`.

The adapter validates adjacent available half-hour slots and converts minor units to whole VND without silent rounding. The server receives IDs, date and hold token; client prices are not sent as payment authority. Booking creation uses the UUID hold token as a stable `Idempotency-Key`. Explicit retries after an uncertain response keep the same request, and users can inspect booking history. Checkout receives the returned booking ID, hold token and promotion code.

The standalone slot-picker fallback remains available when booking creation dependencies are absent, for isolated feature tests.

## Design references

- [Playo booking flow](https://playo.freshdesk.com/support/solutions/articles/1070000107618-how-do-i-book-a-venue-): venue search → sport/time/duration/court → payment. Applied as clear sequential booking steps and a prominent primary action.
- [ClassPass reservations](https://help.classpass.com/hc/en-us/articles/204335689-How-do-I-make-a-reservation): booking access across website and app. Applied as consistent terminology and feature grouping across the existing web and Flutter app.

## Validation scope

Commands run from the Flutter repository:

```sh
flutter analyze
flutter test --reporter expanded
flutter build web --no-wasm-dry-run --dart-define-from-file=../.fcourt-local/flutter-web.json
JAVA_HOME=/Users/minhss/Library/Java/JavaVirtualMachines/ms-21.0.12.1/Contents/Home flutter build apk --debug --dart-define=API_BASE_URL=http://10.0.2.2:18080
```

**Full Flutter suite: 1,019 tests passed** before the final accessibility correction. **50 final targeted tests also passed**, including that correction and customer Home search. `flutter analyze` and the web build pass.

Additional tests cover saved themes, slow restore, ordered writes, storage errors, disposal, four roles at 320px with 1.6x text in light/dark, route authorization, booking handoff, exact currency conversion, malformed booking responses, creation retry, and the real router from slot selection to checkout.

Backend `mvn verify` passed for auth (198 tests), facility (138), POS (54), booking (172), hold (35), payment (86), and staff operations (132): **815 tests**, zero failures/errors/skips.

Live read-only API smoke exercises all four local demo roles, public discovery, bookings/history, transactions, branches/courts, subscription, staff, POS, vouchers, reporting, payment review, owner approval/catalog and access rejection. **36/36 checks passed** through the mobile development proxy and **36/36 through the real Spring gateway**. All 13 runtime health endpoints are UP. The gateway deliberately returns 403 for internal paths; the proxy hides those paths with 404.

Browser evidence uses Chrome at 412×915 with actual local services, not repository mocks. Screenshots and response statuses are in the workspace's `.jira-audit/mobile-ux-2026-11-10/`. **35/35 screens** loaded without HTTP failures or runtime exceptions (see `browser-smoke-summary.json`). Route smoke coverage:

| Role | Screens |
|---|---|
| CUSTOMER | Home, Settings, discovery, branches, branch details, slots, bookings, transactions, profile |
| ADMIN | Home, Settings, profile, branches, courts, slot templates, pricing, court calendar, staff, subscription, bookings, vouchers, dashboard, analytics, payment review, refunds, transactions |
| STAFF | Home, Settings, schedule, POS |
| SUPER_ADMIN | Home, Settings, owner approval, catalog, platform overview |

Live customer booking additionally passed through the browser against the running backend: slot `7657` → hold HTTP 201 → booking `2` HTTP 201 → checkout info HTTP 200 → rendered VietQR, with no JavaScript runtime exceptions. The resulting unpaid demo booking was cancelled through the real gateway; status is CANCELLED and the slot returned to AVAILABLE. No bank transfer or receipt submission occurred. Evidence: `booking-live.json`, `booking-live-checkout.png`, `booking-live-cleanup.json`.

Screen loading checks are distinct from completing every business action. Transactional widget/repository tests use fixtures; they do not prove real provider settlement or native Android behavior.

## Remaining environment requirements

APK compilation reaches Gradle and fails at `:app:processDebugGoogleServices`: `android/app/google-services.json` is absent. The repository README requires downloading this file for the configured FCourt Android Firebase application. No substitute Firebase project or dummy credentials were introduced.

No Android emulator/system image or connected Android device is available. Android QR camera, gallery permissions, offline SQLite/background recovery, native FCM and real provider payment/receipt flows remain unverified in this session. Existing APKs in build outputs predate this change and are not validation evidence.

The installed SDK is Flutter 3.47.6 / Dart 3.13.5; the repository README pins Flutter 3.47.7. No machine-wide SDK upgrade or dependency upgrade was made.
