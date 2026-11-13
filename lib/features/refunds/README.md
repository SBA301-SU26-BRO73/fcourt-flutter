# Customer refunds — SCRUM-95

`/bookings/:id/refund` is available from cancelled, paid booking detail. The API loads
server eligibility/amount and any existing request. The form provides a domestic bank
dropdown, account/name/reason validation and a duplicate-submit guard. It sends no client
amount. Banking form values remain in memory and controllers are disposed on exit.

The timeline displays request → reception → transfer → completion; REJECTED shows the
admin note. Completed transfer proofs load only from trusted HTTPS Cloudinary, without
API credentials. Refresh updates the status. Backend ownership/eligibility remain the
authority; missing/unavailable policy is an error, never an assumed refund amount.

39 supported domestic 970xxx bank options were snapshotted from VietQR's public directory
https://api.vietqr.io/v2/banks on 2026-11-01 (transferSupported=1). This is routing metadata,
not account ownership verification; users confirm their beneficiary details.

Contracts: GET `/api/refunds/booking/{id}` and POST `/api/refunds/request`, SCRUM-94 /
backend #26. Admin decisions/proof follow SCRUM-96. This task adds three commits on
SCRUM-73, targets dev with inherited unmerged dependencies.

Analyze and all 67 tests pass, including no client-supplied amount, malformed amount /
unsafe proof rejection and form-to-timeline flow. Actual Android/account/cancellation /
bank transfer acceptance remains pending; the app does not initiate transfers.

## Admin settlement — SCRUM-97

`/admin/branches/:branchId/refunds` lists pending/approved requests with pagination and
refresh. A guarded modal presents beneficiary details and an exact VietQR refund URI
(including leading-zero account numbers, integer amount and refund reference). Admin
accepts the request, transfers manually, chooses/captures proof and submits multipart
completion. Rejection requires an explanation. Busy state blocks duplicate actions /
dismissal; after closing, the list reloads. QR failures leave readable account details.

Proof selection reuses ReceiptPicker/compression; no API credential is forwarded to the
VietQR image host. The backend verifies role/branch and actual image bytes. The client
never calls a bank transfer API. Real Android camera/gallery and bank transfer acceptance
remain device/integration work. Pending notification email is owned by notification-service.

Analyze, all 70 tests and debug APK build pass. Tests check exact reverse-QR routing and
amount, branch query/multipart transport, and accept+proof gating before completion.
This adds three commits after SCRUM-95; backend SCRUM-96 / backend #27.
