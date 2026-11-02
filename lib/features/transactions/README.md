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
