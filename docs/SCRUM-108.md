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

Redis Pub/Sub is not durable, so a safety resync remains: every 15 seconds while
the socket is down or not configured, every 60 seconds (15s x 4) while it is
connected and subscribed. It is not the task's 500ms latency acceptance. Existing slot colors reflect the authoritative API statuses; there is
no invented status or private payment state inferred from the socket message.
Android latency/network measurements remain open.

## Typed events and notices (SCRUM-245)

Payload `{courtId,date,type[,lockType]}` with `type` in SLOT_CHANGED, HOLD_CREATED,
HOLD_RELEASED, HOLD_EXPIRED, LOCK_CREATED, LOCK_REMOVED and `lockType` OUT_OF_SERVICE or
PRIVATE_EVENT (Full Court Lock). Unknown values degrade to SLOT_CHANGED, so an older
backend still works. Every event only triggers a re-read; after a background resync the
screen compares old and new statuses and shows a SnackBar, for example "Khung giờ 18:00
vừa có người giữ chỗ", "... vừa được chủ sân Bao sân" or "... vừa trống lại". The schedule API
(discovery) already returns `restriction.type` additively on OUT_OF_SERVICE slots, and the grid
(SCRUM-113) shows a Bao sân slot as `OUT_OF_SERVICE` with `restriction.isPrivateEvent`, using the
existing `SlotRestriction` model. The alert wording comes from the slot's own new status and restriction, not
from the event hint, so it stays accurate when events are lost or coalesced. A restriction never upgrades a
non-locked state.

## Configuration

`--dart-define=SLOT_WEBSOCKET_URL=wss://HOST/ws-fcourt` (Android emulator against a local
backend: `ws://10.0.2.2:8088/ws-fcourt`). Without it the screen polls every 15 seconds.

## Manual acceptance (needs a human, two Android devices)

Prerequisites: backend PR for SCRUM-245 deployed with the `realtime` profile on booking-service,
`FACILITY_REALTIME_ENABLED=true` on facility-service, one shared Redis, app built with
`SLOT_WEBSOCKET_URL`.
1. Devices A and B open the same court and date. Turn B's polling out of the picture by
   noting the time; the slot must change on B without pull-to-refresh.
2. A holds slot 18:00 (booking flow): B turns yellow and shows the SnackBar, record seconds.
3. A releases/cancels: B turns green. Repeat with a successful payment: B turns red.
4. Owner creates a Full Court Lock covering 18:00: B turns purple and shows the SnackBar.
   Owner removes it: B turns green.
5. Let a hold expire (5 min): B turns green within ~1-2s of the TTL.
6. Put B in airplane mode for 20s during a change on A, then restore: B must reconnect
   and show the latest state without manual refresh.
Measure each step with a screen recording at 60fps (frames between A's tap and B's change).
Pass criterion from the task: under 500ms for steps 2-4. Record device models and network.

Validation: `flutter analyze` clean; all 15 customer slot tests passed, including
reconnect resync, event burst coalescing, selection updates during an HTTP request,
and ignoring stale data after a date change.

Library: [stomp_dart_client](https://pub.dev/packages/stomp_dart_client).
