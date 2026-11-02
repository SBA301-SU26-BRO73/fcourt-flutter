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

## Cancellation — SCRUM-56

Booking detail loads the server cancellation quote and shows the cancel action only
when allowed. The dialog displays cutoff, Vietnam play/deadline times and server
refund entitlement before confirmation. Reason is required (max 500 characters).
POST is guarded against duplicate taps/dismissal; success updates the badge and
shows a SnackBar, and history refreshes when returning from detail. On server failure
the dialog refreshes its quote so an expired deadline disables another attempt.
Refund entitlement is not a transfer; refund request screens follow in SCRUM-95.
Backend checks identity/state/time again; the mobile quote is never authoritative.

API: GET `/api/bookings/{id}/cancellation-policy`, POST `/api/bookings/{id}/cancel`
with `{reason}`. Validate whole nonnegative VND/refund rate, quote timestamps and
matching CANCELLED response. Backend: SCRUM-55. Task adds three commits on top of
SCRUM-54, PR targets dev with inherited dependency commits until those merge.

`flutter analyze --no-pub` passes; all 52 tests pass. Four added tests cover quote
and POST contracts/identity, required reason and duplicate prevention, deadline
failure refresh and the cancelled detail state. APK build and live acceptance are
reported separately in the PR.
