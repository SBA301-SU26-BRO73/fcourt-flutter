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
