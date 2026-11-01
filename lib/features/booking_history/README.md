# Booking history — SCRUM-54

`/bookings` shows upcoming/completed/cancelled tabs with explicit pagination,
pull-to-refresh, empty/error/retry states and Vietnamese VND formatting. Upcoming
cards show time remaining using the booking's Vietnam timezone and refresh once per
minute/on resume. `/bookings/:id` displays details, payment status, branch address,
map directions and validated contact phone. Confirmed tickets open the existing
SCRUM-39 ticket screen in a full-screen modal; QR bytes still load only from the
fixed authorized payment endpoint. Ticket success now links to history.

Domain (`Booking`, `BookingRepository`) has no Dio/UI dependency. Data parsing rejects
mismatched identity, unsupported statuses, impossible dates, malformed times and
fractional/negative VND. Missing legacy branch/contact snapshots have clear fallbacks.
History keeps a generation counter so late results from another tab cannot replace
the active list. Failures cross layers as domain Failure. Maps/telephone launch via
url_launcher and do not receive API credentials. There is no unauthenticated
customer-history fallback; API requires the signed-in user's JWT.

Backend: SCRUM-53 / backend PR #21. Uses GET `/api/bookings/my` with status/page/size
and GET `/api/bookings/{id}`. Cancellation is added separately by SCRUM-56.
Task builds on Flutter PR #5 (unmerged); delta has three commits.

Validation: `flutter analyze --no-pub`, `flutter test --no-pub` (48 tests).
Six new tests cover real Dio contract/validation/auth failures, tabs/pagination,
empty state, error retry/disposal and detail-to-ticket callback. Live Android
maps/phone/gallery, account navigation from its owner and booking-creation acceptance
remain integration/device checks. A debug APK build is recorded in the PR separately.
