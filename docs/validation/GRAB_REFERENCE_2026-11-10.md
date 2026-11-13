# Customer navigation and Grab-style reference pass — 2026-11-10

This supersedes the earlier customer Home/Profile/Settings tab arrangement. The reference screenshots supplied in the conversation guide spacing and hierarchy; SportCourt retains its own features and data.

## Result

- Customer tabs: **Khám phá / Đã đặt / Hoạt động / Thông báo**. The active tab retains the moving Liquid Glass capsule/rim. Account and Settings are corner actions rather than tabs.
- Exploration: pinned green search header; one-line greeting; Tennis, Cầu lông, Bóng đá and Pickleball shortcuts; responsive two-column venue grid on phones; image, name, address, rating/new marker, court count and price. Football uses the backend catalog ID 2. Selecting an active sport again or using All clears that sport restriction.
- Venue photography and review metadata come from discovery's `imageUrl`, `averageRating`, `reviewCount`. Missing images use a court illustration; zero-review venues show “Mới” instead of invented ratings.
- A floating “Kéo để xem thêm” prompt disappears after the first scroll or press. Existing paginated results keep the load-more action.
- Booked: purple summary header, All/upcoming/completed/cancelled filters, bookings grouped by play date descending (within loaded pages), current date labelled Today, and clear time/code/status/amount rows. Detail uses grouped date/time/price/payment information and existing directions/contact/cancel/refund/review/ticket actions. Ticket, review and cancellation actions remain reachable at the bottom of the detail view.
- Activity is the requested empty state. Notifications has three static editorial channels: Thông báo, Siêu ưu đãi and Mới trên SportCourt, each with a readable article. No fake unread counts, delivered push messages or claims of available discounts were introduced.
- Account is a compact hub with avatar/name/email, Hồ sơ, existing booking/payment history, settings, password change and logout. Editing name/phone moved to `/profile/edit`, retaining its existing validation and save API.
- Account, editable profile, Settings and notification articles have explicit Back controls and no tab bar. Direct links fall back to the main screen when there is no navigation stack. No unsupported saved-place/payment-method/language/rewards features were added.
- Other roles retain their operational home/routes, with account/settings in corner actions.

## Verification

**Full Flutter suite: 1,023 tests passed.** `flutter analyze` reports no issues and the Flutter web build passed. Regression tests exercise all four customer tabs and the selected glass rim, the disappearing scroll prompt, sport reset, account/edit/back behavior, notification article opening, booking date grouping and existing booking/review/cancellation actions.

Live browser at 412×915 against the running local backend verified:

- real venue results and the four sport actions on exploration;
- scroll prompt disappearance;
- All booking history API returning two cancelled demo bookings, displayed in date order 11/11/2026 then 07/11/2026;
- detail for booking 2 showing court, date, time, status, amount, payment state and existing contact controls;
- Activity empty state and notification channel/article navigation.

Screenshots/logs: workspace `.jira-audit/grab-2026-11-10/`. Preview: http://127.0.0.1:18100.

This is a Flutter UI/contract pass; no backend schema, credentials, payment transfer, live notification delivery or new external service integration was changed. Native Android environment limits from the prior report still apply.
