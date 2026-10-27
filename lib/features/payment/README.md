# VietQR checkout — SCRUM-33

`PaymentCheckoutScreen` loads authoritative amounts and bank information from
SCRUM-32, renders VietQR, copies payment fields and saves a PNG to the Android
photo gallery. It uses the `data / domain / presentation` structure and injected
`PaymentRepository` / `QrSaver` interfaces for testability.

Open `/payments/checkout` with `CheckoutArguments(bookingId: ..., holdToken: ...)`
in GoRouter `extra`. Guests pass the hold token; signed-in users use the shared
Dio client's JWT interceptor. The hold token stays out of URLs and third-party
image requests. Deep links without arguments ask the user to select a booking.

`PaymentRepositoryImpl` consumes
`GET /api/payments/checkout-info/{bookingId}` as documented in backend PR #3:
`bookingId`, `bookingCode`, `branchName`, `courtName`, `date`, positive whole-VND
`amount`, `bankName`, six-digit `bankBin`, string `bankAccountNumber`,
`bankAccountName`, `transferContent`, and UTC ISO `expiresAt`.

The UI copies the exact unformatted VND amount, preserves leading-zero bank
accounts and shows feedback for all copy/save actions. It translates 401/403,
404, 409, 410, malformed responses and network errors into user-facing messages.

## QR image and PNG export

Quick-link format follows [VietQR's documentation](https://www.vietqr.io/qr-dong):
`https://img.vietqr.io/image/{bankBin}-{accountNumber}-compact2.svg` with `amount`,
`addInfo`, and `accountName` query parameters. Bank details and transfer content
are necessarily sent to VietQR to generate the image; guest/auth tokens are not.
The provider currently serves SVG even for a `.png` URL, so the app explicitly
requests SVG and renders it through `flutter_svg`.

The saver uses a separate Dio instance without API credentials, rasterizes the
SVG with the same vector renderer, exports real PNG bytes and writes them using
[Gal](https://pub.dev/packages/gal). Android storage permission is declared only
through API 29 as required by Gal; permission denial and storage failures show
feedback. Saving to a custom album is not used. Android is the target platform;
web gallery export is not supported by Gal.

## Countdown

`CountdownTimerWidget` calculates remaining time from absolute server expiry on
every tick and on app resume. It never starts a fresh five minutes on rebuild or
resume, warns below 60 seconds and calls `onExpired` once at zero. It stays alive
while scrolled off-screen. Expiry removes the QR and displays the expired-session
page; an API 410 displays the same expiry message. The device clock must be
synchronized with UTC for an accurate display; the server independently rejects
expired sessions.

## Verification

```sh
flutter analyze
flutter test
```

Payment tests cover the exact QR URL, header-only guest tokens, malformed money
and bank data, 410, SVG-to-PNG conversion, countdown/resume/off-screen expiry,
copy/save feedback, expired QR removal and retry. A separate temporary smoke
check fetched a real VietQR image for a demo bank account, rasterized it using
`rasterizeQr`, decoded the resulting 540×640 PNG and checked bank BIN, account,
amount, transfer content and CRC16. A temporary web harness previews the actual
screen with demo data; it is outside the repository.

## Integration pending

SCRUM-25 summary and SCRUM-32 checkout are still unmerged PRs, and there is no
booking-creation implementation on `dev`. This change provides the route and
arguments without importing unmerged booking types. The caller must create or
resolve the real booking ID before opening checkout and pass its current hold
token. Wire the summary callback to this route when that creation contract lands.
Actual API integration, Android gallery acceptance and a Mobile Banking app scan
remain to be verified on a device. Receipt upload and waiting/polling belong to
SCRUM-35 and are not part of this screen.

## Receipt upload / waiting — SCRUM-35

Checkout now opens `/payments/receipt` with `CheckoutArguments` in router `extra`; credentials never appear in URLs. `ReceiptRepository` creates a cancellable session per booking. The camera/gallery picker compresses to JPEG (quality 82, 1600 target dimensions), bounds original input at 30 MiB and final upload at 5 MiB. Android lost-picker recovery is handled. The screen previews the photo, displays progress and allows retry without replacing an already submitted bill.

`POST /api/payments/{bookingId}/upload-receipt` uses multipart `file`; `GET /api/payments/{bookingId}/status` returns `id`, `bookingId`, `status`, optional `rejectionReason`. Guest credentials remain in `X-Hold-Token`; signed-in requests use the existing authenticated Dio. A missing receipt (404) shows the picker. Polling runs every 4 seconds after the previous request finishes, pauses in the background, refreshes on resume, stops for terminal decisions, and cancels network requests on dispose/session replacement. The waiting ripple animates while awaiting approval. Confirmation calls `onConfirmed` exactly once; SCRUM-39 supplies the ticket route. No five-minute cancellation runs once a receipt is awaiting review.

Validation: `flutter analyze --no-pub` and `flutter test --no-pub` (31 tests) cover header-only credentials, malformed/mismatched status, image size, upload, nonoverlapping polling, pause/resume, terminal navigation and disposal. Android camera/gallery/compression and real API acceptance still require a device and integrated backend. This task builds on Flutter PR #2; its delta has three commits. Backend contract: SCRUM-34 / backend PR #5.

## Admin receipt review — SCRUM-37

`/admin/branches/:branchId/payments` opens `AdminPaymentApprovalScreen` using the authenticated shared Dio. The backend enforces admin role and ownership. The list shows customer (or guest fallback), booking code, exact VND and submission time; supports pull-to-refresh, empty/error/retry and 50-item pagination. A modal allows pinch-to-zoom, receipt rotation, confirm, or reject with a required reason up to 500 characters. Actions disable while saving and the modal blocks dismissal during a request. Success removes the row, refreshes and shows a SnackBar; failed decisions retain the modal and display the server-facing error.

API contract: `GET /api/admin/payments/pending?branchId=&offset=`, `PUT /api/admin/payments/{id}/confirm`, `PUT /api/admin/payments/{id}/reject` with JSON reason. Data is validated for matching branch, pending status, integer amount, timestamp and HTTPS Cloudinary receipt URL. A decision counts as successful only if its returned ID and final status match. Depends on backend SCRUM-36 / PR #7 and Flutter PR #3; no pending PR needs to be merged to review this delta.

Validation: analyze has no issues; all 35 unit/widget tests pass, including duplicate-action blocking, zoom/rotation, reject validation, list refresh, malformed/foreign-branch payload and recovery from load failure. An Android debug APK built successfully with the new picker/compression plugins. Live account/branch integration and device acceptance remain pending.
