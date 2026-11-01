# Booking summary — SCRUM-25

`BookingSummaryScreen` receives an immutable `BookingSelection` from the slot
picker (SCRUM-23), optional profile name/phone, and `onHeld(BookingCheckout)`
from the payment flow (SCRUM-33). Guests fill in their own contact. The form
validates Vietnamese mobile numbers, shows each 30-minute slot and sums integer
VND prices. Displayed prices are estimates; payment must load authoritative
checkout amounts from the server.

Open `/booking/summary` with `BookingSummaryArguments` via GoRouter `extra`, or
embed the screen directly with an injected `BookingRepository`. The caller
provides `onHeld` to open VietQR checkout with the hold token, server expiration,
contact and original selection. The token stays in memory, not in the URL.
A direct link without a selection asks the user to select a court first.

The API client sends `POST /api/bookings/hold-slots`:

```json
{"courtId":1,"date":"2030-01-01","slotIds":[1,2],"guestPhone":"0912345678"}
```

It expects `holdToken` and ISO `expiresAt` from SCRUM-24 (backend PR #2).
Invalid or already expired responses never advance checkout. The public hold
endpoint does not require auth storage, and the supplied profile is used only
to prefill editable contact fields. The display name travels in the in-memory
checkout handoff; the current hold API stores only the phone.

Use the shared Dio client and gateway `API_BASE_URL`. Until a gateway exists,
point a development run at `http://10.0.2.2:8087` on an Android emulator to reach
the slot hold service directly. Errors 400/404/409 and network failures are
translated into Vietnamese messages. A failed submission keeps contact fields
and allows retry; submitting or successful holds disable further submissions.

## Integration still required

`dev` currently contains the health scaffold only. SCRUM-23 has not supplied a
slot picker or entry navigation; SCRUM-33 has not supplied the VietQR screen.
This PR supplies the summary route and typed callback boundary for those tasks;
it does not add fake production slots or a placeholder payment flow. Validate
the complete picker → summary → VietQR flow when these dependencies are merged.

## Checks

```sh
flutter pub get
flutter analyze
flutter test
```

Booking tests cover phone prefixes, integer pricing, immutable selection, the
hold request contract, expired/malformed responses, 409 handling, duplicate
submission suppression, safe disposal, profile prefill, guest validation and
successful payment handoff. They use a fake HTTP adapter/repository; full API
integration and an Android device run remain separate acceptance checks.
