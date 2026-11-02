# SCRUM-106 Flutter POS

`/staff/pos`, STAFF session, POS_BASE_URL when separate from gateway (8091).
Search/category catalog, stock-limited quick cart, phone sheet/tablet side panel,
cash or positive booking ID, immutable server invoice and paginated history.

All money uses integer minor units. Requests contain only product ID/quantity and
payment choice; prices/branch/cashier are server-owned. Validate invoice identity,
method, selected quantities, line snapshots and totals before showing success.
Unknown results lock the original cart/key; definitive 4xx allows correction.
PENDING_CHARGE explicitly forbids goods handoff. Only PAID/ON_BOOKING permits it;
bounded one-second polling stops after 30 attempts and pauses in background.

2026-11-01: full Flutter suite 57 tests passes, analyze clean. POS domain/HTTP
adapter coverage 100%, cart cubit 91.2%; widget coverage includes narrow/tablet
layout, stock-disabled control, cash receipt, history empty state and pending-to-
attached transition. HTTP tests verify payload, filters, pagination and malformed
invoice rejection. Browser render inspected at desktop and 390x844 (fixture data).

Not verified: live POS/booking settlement, physical cash/handoff, <10s Android
workflow or real concurrent stock changes. Backend's real stock/settlement logic
already belongs to its existing POS PR; this task changes only Flutter.
