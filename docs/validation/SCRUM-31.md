# SCRUM-31 counter booking

Route: /staff/schedule, per-court “Đặt tại quầy”; tap a CHECKED_IN session or its
“Trả sân” action for checkout. Configure DISCOVERY_BASE_URL if availability is
not routed through API_BASE_URL. Public discovery client carries no staff token.

Contiguous canonical available slots only, bounded to 48. Name/phone are validated;
only identity/contact/slot IDs are submitted, never client price/branch/cashier.
Display price is an estimate; authoritative invoice has base/fee/total snapshots.
Checkout reads the server fee estimate before confirmation. A quote does not
reserve availability or freeze charges until the booking authority commits.
Unknown write results preserve payload/key and do not report cash/admission success.

2026-11-01: analyze passes, full Flutter suite 37 tests passes. Tests cover exact
decimal arithmetic, bad/duplicate availability, contiguous/busy selections, exact
HTTP bodies, invoice mismatch, business-day UTC+7 rollover, checkout fee display,
and immutable retry keys for create/checkout. Backend full verify: 119 tests,
real PostgreSQL/Kafka, no failures/skips and service coverage gate passes.

Support API additions: optional guestName on walk-in, GET checkout-preview. The
booking authority must persist/echo guestName in original command identity and
provide the fee projection; staff adapter alone does not implement that authority.
Real Android speed (<20 seconds), cash procedure, live authority integration and
physical device acceptance remain unverified; no real environment was supplied.
