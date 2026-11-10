# Persistent tabs, discovery and account — 2026-11-10

The previous per-screen bottom bars were replaced by one authenticated `ShellRoute` and `AppShell`. Tab changes use `go` instead of stacking root screens. The bar stays present in discovery, profile, settings, booking history, transactions and subsequent authenticated destinations. Retapping Account from its history returns to the account root. Login, password reset and offline staff recovery remain outside the signed-in tab UI.

Home now loads the actual discovery API immediately through `VenueFeed`. “Tất cả” sends no sport constraint and renders venue cards inline. Choosing a sport refreshes that same feed in place; returning to All restores the complete result set. Loading, empty, retry and pagination states are explicit. Discovery now opens the searchable venue catalog directly, with sport and advanced filters, instead of a second static landing page. Search submission trims whitespace.

Account now groups booking history and transaction history ahead of editable profile information, password change and logout. Its routes use the existing authenticated repositories; no mock financial data was added. Redundant Back buttons were removed from Home, discovery/list, Account, Settings and customer history screens.

The visual pass introduces mint/sky/lavender page gradients, teal-to-blue hero gradients, rounded readable content cards and iOS icons. Glass is confined to the floating navigation layer. The selected tab has a persistent luminous capsule rim around its icon and label, a blurred resting lens, and refractive spring feedback during interaction. The rim slides to the active route, including returning to Account from history, and honors reduced motion. The Material ancestor on the glass shell supplies proper text styles rather than Flutter's fallback underline styling.

## Skill and dependency

Used [liquid-glass-widgets skill](https://github.com/sdegenaar/liquid_glass_widgets/blob/main/skills/liquid-glass-widgets/SKILL.md), installed at `~/.codex/skills/liquid-glass-widgets/SKILL.md`, and `liquid_glass_widgets` 1.17.0. Shaders initialize in `main`, `LiquidGlassWidgets.wrap` bridges Material brightness and system accessibility, and `GlassScaffold` owns `GlassTabBar.bottom`. No private package imports or nested refractive content cards are used.

The distinction between navigation material and readable content follows [Apple's Liquid Glass guidance](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass).

## Validation

- Full Flutter suite: **1,022 tests passed**.
- After the final navigation typography/history adjustments: **20 targeted tests passed**, including persistent tab switching, Account history, Home filtering and customer history repositories/widgets.
- A route-driven indicator test checks that the glass rim actually surrounds the selected tab label after each tab switch.
- Final Home layout/account checks: **47 tests passed**; final active-rim navigation/filter tests: **2 passed**.
- `flutter analyze`: no issues.
- `flutter build web --no-wasm-dry-run --dart-define-from-file=../.fcourt-local/flutter-web.json`: passed.
- Live browser at 412×915 against the local backend: signed-in customer Home loaded real branches including “Sân Cầu Lông Ba Đình”; Explore retained tabs and loaded its catalog; Account showed the current name/email/phone and linked to booking/transaction histories; selecting Account from history returned to Account; Settings switched the application to dark mode while navigation remained visible. Both histories returned their actual empty states, not errors.

Preview: http://127.0.0.1:18100

The previous session's native Android environment requirements remain: missing `android/app/google-services.json`, no connected Android device/emulator. Native camera, FCM and offline behavior are not newly claimed here.

Final browser screenshot: `../.jira-audit/glass-tabs-2026-11-10/home-active-ring-final.png` in the SportCourt workspace. Home displays a venue name in the initial phone viewport, and its active capsule has a visible luminous glass rim.
