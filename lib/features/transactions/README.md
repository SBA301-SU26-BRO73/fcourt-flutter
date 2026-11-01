# Customer transactions — SCRUM-69

`/payments/history` shows paginated personal transfer receipts with branch/court,
payment/booking codes, VND, Vietnam submission time and status badge. Supports refresh,
error/retry/empty states and receipt bottom sheet with zoom and image-load feedback.
Only HTTPS res.cloudinary.com receipt URLs without userinfo/custom ports are accepted;
images load without Dio/Bearer credentials. A shortcut is available in booking history.
The auth/profile owner can navigate to this route after integrating SCRUM-7.

Domain repository/entities do not depend on Dio or widgets. The data layer uses the
shared authenticated Dio, checks pagination/identity, whole nonnegative VND, status,
timestamps and receipt origin. Async generations prevent stale refresh/disposal writes.
The parent auth flow must dispose account routes when a session is replaced.

Backend: SCRUM-68 / backend PR #23. GET `/api/payments/my-transactions?page=&size=20`
returns `{items,page,size,total}`. First read can return 503 until booking ownership
reconciliation is available; never substitute an empty list for that failure.
Task adds three commits on SCRUM-67, targeting dev with inherited dependency commits.

Validation: analyze and 58 Flutter tests pass, including request contract, invalid
money/origins/status/time, pagination/receipt sheet and auth failure/retry checks.
Live profile/Android/network acceptance remains pending with the upstream owners.

## Admin branch ledger — SCRUM-71

`/admin/branches/:branchId/transactions` shows totals over the complete filtered result
(received/pending/rejected count), date range, status chips, debounced name/phone/code
search, pagination and receipt review. The pending-receipt screen links to the ledger.
A branch change clears filters/data. Generation checks prevent late search/page replies
from replacing a newer filter; totals clear while a new filter loads. Error responses
never become fake zero totals. Summaries must be nonnegative whole VND.

Backend: SCRUM-70 / backend #24. UI uses the shared authenticated Dio; backend remains
the role/ownership authority. This adds three commits after SCRUM-69. Net refund/cash
reporting follows in SCRUM-99. Analyze and all 61 tests pass, including bound branch/date
query fields, all-result summaries across pagination and stale debounced response/dispose.
Live Android/admin/account and backend acceptance remains pending.

## Net cash flow and export — SCRUM-99

Admin history now requests unified `transactionType` (ALL/BOOKING_PAYMENT/REFUND/
WALK_IN_CASH). Filter chips distinguish incoming payments, completed refunds and cash.
Summary shows received/refunded/net; signed row amounts use green inflows and red
refunds. Row identity is the server's P:/R:/C: key, so local IDs cannot drop another
transaction type during pagination. Missing type/key or unified financial totals fail
closed; the new screen requires backend SCRUM-98 rather than assuming zero refunds
from an older receipt-only response. Customer receipt history keeps its original API.

Export fetches every page matching a query captured at click time (up to 200,000 rows),
checks count/financial summary consistency and duplicate keys, and shares a UTF-8 BOM
CSV with summary and signed integer VND. Text cells neutralize spreadsheet formula
prefixes; numeric amounts stay numeric. No beneficiary bank fields are exported. Live
changes detected across pages abort instead of silently sharing a partial report.
This is a filtered operational report, not a server-side immutable accounting snapshot;
strict audit exports need a dedicated versioned export API. Android sharing/saving uses
share_plus; cancellation/availability of destination apps requires device acceptance.

Analyze, all 73 tests and debug APK build pass. New checks cover negative refund validation,
colliding IDs, complete multi-page CSV, formula-safe text and export drift rejection.
Three task commits after SCRUM-97, backend SCRUM-98 / backend #28. Actual Android sharing,
Kafka ingestion and live financial reconciliation remain integration acceptance checks.
