# SCRUM-108 — realtime availability

Build with `--dart-define=SLOT_WEBSOCKET_URL=wss://YOUR_GATEWAY/ws-fcourt` after the
backend realtime profile and Redis are configured. The URL is optional; omission
keeps HTTP reconciliation and manual refresh. Native STOMP connects without user
credentials because the stream only contains public schedule invalidations.

Each open court subscribes once. Connect/reconnect triggers a snapshot; matching
date events coalesce into one active HTTP request plus a trailing refresh. The
server remains authoritative. A changed slot drops from the selection; selections
made during a background request are preserved when still available. HTTP date
changes supersede stale responses. Timers/subscriptions close with the screen.

A 15-second snapshot fallback handles Redis message loss, hold TTL expiry and
facility updates that have no producer yet. It is not the task's 500ms latency
acceptance. Existing slot colors reflect the authoritative API statuses; there is
no invented status or private payment state inferred from the socket message.
Backend facility-lock push and Android latency/network measurements remain open.

Validation: `flutter analyze` clean; all 15 customer slot tests passed, including
reconnect resync, event burst coalescing, selection updates during an HTTP request,
and ignoring stale data after a date change.

Library: [stomp_dart_client](https://pub.dev/packages/stomp_dart_client).
