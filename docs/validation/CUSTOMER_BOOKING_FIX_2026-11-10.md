# Customer venue selection and floating navigation — 2026-11-10

The customer could see venue cards but could not select their courts. The public courts endpoint returned valid courts with `defaultPricePerHour: null`; these courts use prices from their individual slots. Flutter incorrectly rejected the entire response as malformed.

## Changes

- Accept absent hourly prices while continuing to reject invalid supplied prices. Court choices show “Giá theo khung giờ · Chọn sân để xem lịch”; the slot API remains the source of actual payable prices.
- Place court choices immediately below branch name/address, before optional location and amenities.
- Restore branch metadata from `/api/public/branches/{id}` when a direct link/reload has no route extras. Loading, retry and failure states remain explicit. Back returns to discovery when no previous route exists.
- Extend the Customer page behind the rounded glass navigation. Remove the reserved opaque footer area, retain the active glass rim, and give scrollable content trailing clearance. Move the discovery scroll hint above the navigation.
- Detail, booking and checkout screens retain their own back/action controls without an overlapping tab bar. Operational roles keep reserved navigation space so their existing action buttons remain accessible.

## Live verification

Tested Flutter web at 412×915 against the local backend using the demo Customer account:

1. Opened Sân Cầu Lông Ba Đình from discovery; both Sân số 1 and Sân số 2 appeared despite their null hourly prices.
2. Selected court 21, 11/11/2026, 06:00–06:30 at 20,000 VND; continued through the populated booking summary.
3. Created booking **3 / FC43141924**, status `PENDING_PAYMENT`, and opened the VietQR checkout with correct branch, court, date and amount.
4. Cancelled only that test booking without making a payment; verified slot 1614 returned to `AVAILABLE`.
5. Opened `/branches/1` directly without extras; metadata and both court choices loaded.
6. Visually checked that cards remain visible beneath and around the floating navigation and that the scroll prompt is above it.

Screenshots: workspace `.jira-audit/bookable-2026-11-10/floating-tabs.png` and `customer-checkout.png`. Preview: http://127.0.0.1:18100.

Regression coverage includes null-price decoding, malformed provided prices, branch lookup identity/HTTP failures, direct-link recovery, navigation back fallback, court-to-slot routing, booking-to-checkout routing, extended body layout, scroll-hint clearance, and existing operational-role actions.

Final checks: **1,027 Flutter tests passed**; `flutter analyze` reported no issues; Flutter web build passed. The direct-link/back regression also passed separately after the last navigation adjustment.
