# Flutter execution plan

Scope: Khoa's SCRUM-27, 29, 31, 62, 64, 66, 106 (Flutter only), 116.
Read Jira descriptions and backend source on 2026-11-01. Never merge PRs or change
Jira state automatically. Existing AGENTS.md and PROJECT_CONTEXT.md remain local.

## Delivery and verification

Each task gets a branch and PR. Dependent PRs target the preceding task branch;
retarget after the parent merges. Small commits separate domain, adapters, state,
UI, tests and documentation, with scoped Conventional Commit subjects <=50 chars,
imperative lowercase wording and no coauthor trailers. Commit only after local
checks pass; push after checking the complete task diff. One task per PR takes
precedence over the reference's recommended 400-line PR size.

For each task: format/analyze, meaningful unit/BLoC and widget tests, regression
suite, coverage of new business logic (target >80%), HTTP contract tests,
narrow/tablet/large-text layout checks, release APK build where SDK permits.
Record evidence and limitations in docs/validation. No real gateway/accounts
exist yet (owner confirmed); fixture success is not live integration acceptance.
Camera latency, darkness, airplane mode and 3-second reconnect targets require
Android device acceptance. Do not claim 100% production readiness without it.

## Backend prerequisites (separate support branch/PR)

Extend staff API for safe reactivation, read-only ticket preview, walk-in guest
name, branch/day scoped offline ticket snapshot and idempotent offline replay.
Validate role, active branch, date/window and atomic booking ownership; never
write booking DB from staff. Add required booking/IAM adapters and contract tests.
If owning authority lacks an operation, document the integration dependency and
fail closed rather than implement an unchecked local substitute.

## SCRUM-27 — employee management

- Branch selector with owned facility branches; paginated employee list showing
  avatar initials, name, email, phone, branch and active state.
- Keyboard-safe create/edit sheet, email/phone/password validation, immutable
  branch/email on edit, retained shifts, duplicate-email errors and submit lock.
- Confirm disable/reactivate; refresh after success, stable UUID on retry.
- Tests: validation boundaries, paging, request fields, errors, successful create,
  edit and disable/reactivate, loading/empty/error and text scaling.

## SCRUM-29 — today's schedule and QR

- Assigned-branch schedule grouped by court/time, pull refresh and session errors.
- Native mobile_scanner, CAMERA manifest, flash, haptic, lifecycle stop/dispose,
  permission denial/retry and duplicate scan guard.
- Read-only preview then explicit confirmation; show customer/court/time and
  authoritative success/rejection; refresh schedule after confirmed admission.
- Tests: response parsing, preview has no write, confirm/retry UUID, double scans,
  already-used/foreign/expired tickets and permission/lifecycle UI boundaries.

## SCRUM-31 — counter walk-in and checkout

- Open sheet from available slot; contact and duration, estimated cash amount,
  server invoice after creation; never submit client prices.
- Checkout only checked-in bookings, confirmation and authoritative result,
  no false success on timeout; refresh after successful write.
- Tests: exact bodies, selection/contact validation, conflicts, double submit,
  retry identity and invoice/checkout state transitions.

## SCRUM-62 — contiguous multi-slot walk-in

- Prefill court/date/start from tapped slot; select contiguous available slots,
  prevent gaps/occupied selection and reconcile changes after conflicts.
- Session-scoped returning-contact suggestions; explicit cash collection action.
- Tests: gaps, duplicates, maximum length, stale availability, original retry
  identity, correct tapped slot and immediate refreshed occupied state.

## SCRUM-64 — weekly board

- Day/week switch, seven-day court matrix, two-axis scrolling, previous/next
  week, today/date picker, server-derived warning flags with reduced-motion path.
- Cancel/ignore stale responses and stop polling on background/disposal.
- Tests: week/month/year boundaries, empty courts/days, warnings, stale loads,
  scrolling, narrow/tablet layout and large schedule performance.

## SCRUM-66 — manual code fallback

- Autofocused keyboard dialog, uppercase/preserved opaque hyphenated code,
  validation, explicit confirm, server error and success feedback.
- Reuse check-in preview/command path and refresh schedule on success.
- Tests: formatting, empty/long/unknown/used/foreign codes, focus, retry and
  duplicate taps; never infer booking IDs or invent code grouping rules.

## SCRUM-106 — POS Flutter

- Branch catalog with category/search, image fallback, stock-aware quick cart,
  responsive phone/tablet layout and cash/booking payment choice.
- Server invoice, history/detail and bounded status refresh for pending charges.
  PENDING_CHARGE must forbid goods handoff; only PAID/ON_BOOKING permits it.
- Tests: stock/quantity limits, decimal amounts, changed price/stock, cart retry
  identity, atomic rejection, pending/cancelled/attached receipts and paging.

## SCRUM-116 — offline admission

- SQLite transactional branch/user/day ticket snapshot, freshness/window checks,
  atomic local consume and durable outbox with stable UUID; never cache tokens.
- Shift sync, reconnect/resume drain, per-result conflict state and retry only
  ambiguous failures. Retain pending entries through snapshot replacement.
- Clear expired sensitive snapshots; isolate account/branch switch and logout.
- Tests: persistent restart, duplicate/concurrent scans, expired/wrong-branch
  tickets, network recovery, conflict, pending preservation and offline replay.
- Device airplane-mode/reconnect acceptance remains explicit until measured.
