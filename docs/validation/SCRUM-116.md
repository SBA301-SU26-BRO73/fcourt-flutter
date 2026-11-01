# SCRUM-116 offline admission

Android caches a signed, branch/user/day scoped shift snapshot in SQLite. QR
values are SHA-256 hashes; tokens remain in secure storage. A local admission
atomically consumes the ticket and creates a durable UUID-keyed outbox entry.
Snapshot replacement preserves consumed tickets and pending commands. Cache must
be less than 12 hours old and the ticket inside its permitted admission window.

Network failures may use cached preview; authorization failures cannot. Offline
success is explicitly provisional. Reconnect/resume drains the queue; definitive
server conflicts remain visible for reconciliation. Same-device concurrent scans
are serialized. Two disconnected devices can still produce a server conflict.
Pending records survive process restart and are never removed by expiry cleanup.

2026-11-01: Flutter analyze clean; 68 tests pass before the separate SCRUM-62
review fixes. Tests use real SQLite files, reopen persistence, concurrent consume,
cache scope/window/freshness, immutable replay, network recovery, signed snapshot
HTTP contracts, account/logout isolation and visible conflicts. Coordinator line
coverage 94.1%; native worker scheduling requires device acceptance.

Backend verification: staff 121 tests plus coverage gate, auth 22 tests, booking
11 tests; PostgreSQL/Kafka containers where applicable. The three-service smoke
runs real auth/staff/booking jars with separate PostgreSQL databases, fixture
facility/JWKS, and verifies reactivation, read-only preview, signed hash snapshot,
once-only offline replay, tamper rejection and manual/QR duplicate rejection.

## Configuration and remaining acceptance

Backend-only STAFF_OFFLINE_SIGNING_KEY must have at least 32 bytes. Keep previous
keys in STAFF_OFFLINE_PREVIOUS_SIGNING_KEYS during pending permit reconciliation.
STAFF_BOOKING_SERVICE_TOKEN must match the booking service configuration and stay
server-side. Never put these values in Flutter dart-defines or committed files.

Android build attempted but blocked by absent Android SDK. Physical camera,
airplane mode, app kill/reboot, OS background execution and reconnect latency
remain unmeasured. Workmanager is a best-effort backstop; foreground reconnect
also flushes. A three-second background guarantee is not established. Real gateway,
accounts, deployed migrations and signing-key operations still need acceptance.
Walk-in creation/contact persistence and checkout fee authority remain upstream
integration dependencies; their staff adapters alone do not prove settlement.
