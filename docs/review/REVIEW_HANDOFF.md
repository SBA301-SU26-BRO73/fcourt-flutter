# Flutter support: review handoff

## Delivered and verified

Staff PR #29, booking #30, IAM #31, hold #41 and facility #42 supply the missing
owning-service APIs. Existing POS branch supplies retail operations. Flutter PRs
#20–27 remain one task per PR, stacked in order, with scoped small commits.

2026-11-01: 77 integrated Flutter tests pass and analyze is clean. Added regression
coverage for repeated 401 (no interceptor deadlock), shared refresh across service
clients, logout/account replacement and no background token rotation. Checkout
requires expected surcharge AND total; 409 requires a fresh preview and command.

Backend Maven verify: staff 121, booking 29, auth 25, facility 8, hold 14, POS 42
(all pass). Real PostgreSQL and Redis test atomic replay/slot contention. Staff
and POS coverage gates pass. Six-service smoke passes actual IAM/staff/booking/
facility/hold/POS APIs, including staff CRUD/reactivation, day/week schedule,
read-only preview, manual/QR mutual exclusion, signed offline replay, online hold
versus walk-in, contact persistence, overtime and POS settlement exactly once.
Discovery and JWT issuance/JWKS are controlled fixtures in that smoke.

## Overtime and payment behavior

The owner confirmed each started extra 30 minutes uses the corresponding slot
price. Rates come from facility authority, not client amounts or availability
cache. Missing rates or >24 hours overtime require manual reconciliation; no
invented rate. Checkout displays overtime plus attached POS amount to collect,
without collecting already-paid court fees again. Server rejects changed totals.
POS settlement uses a durable outbox and independent retry after booking commits.

## Review order and configuration

Review backend support with its existing parent branches, then Flutter #20 through
#27. Booking #30 includes the existing cancellation branch and uses migrations
V4/V5/V6 to avoid its V3 collision; no support schema was deployed to production.
Do not merge a child into dev before its parent, or merge parents into a child.
Retarget children after parent merge while preserving per-task diff.

Server-only keys: STAFF_OFFLINE_SIGNING_KEY (and retained previous keys),
STAFF_BOOKING_SERVICE_TOKEN, BOOKING_HOLD_SERVICE_TOKEN,
POS_BOOKING_SERVICE_TOKEN and POS_SETTLEMENT_SERVICE_TOKEN. Configure service URLs.
Enable counter.grpc.enabled on hold/booking (ports 9087/9088); loopback permits
local plaintext, non-loopback requires TLS certificate/private key and staff
transport configured accordingly. No secrets belong in Flutter env JSON.

## UI evidence and release acceptance

Screenshots in `screenshots/` are rendered from current widgets at 430×932 with
fixture data and a readable Windows review font. They demonstrate layout, not
Android camera or native typography. Existing narrow/tablet/large-text tests pass.

Android release smoke now builds in each Flutter PR CI and uploads a seven-day
APK artifact; it uses existing debug signing and dev configuration. This is build
verification, not a store distribution artifact. Production signing and endpoint
acceptance remain release-owner responsibilities.

No physical Android device was supplied. Camera/flash/haptic, airplane mode,
process kill/reboot and OS background timing remain documented release acceptance.
Review readiness does not assert these hardware checks passed. No automatic merge,
review request to another person, Jira state update or production deployment.
