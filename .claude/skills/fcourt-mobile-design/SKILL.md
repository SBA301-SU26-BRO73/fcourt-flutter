---
name: fcourt-mobile-design
description: "FCOURT mobile design system and mobile UI rules (liquid glass, aurora wallpaper, frosted cards, Be Vietnam Pro). Trigger whenever creating, restyling or reviewing any Flutter screen, widget, sheet or dialog in this app."
---

# FCOURT mobile design

Rules collected from Apple's Liquid Glass adoption guidance, the
`liquid_glass_widgets` skill (see `../liquid-glass-widgets/SKILL.md`), and
community mobile-design skills (Refactoring-UI based), adapted to this codebase.
Read the tokens in `lib/app/theme/tokens.dart` and the shared widgets in
`lib/app/widgets/fc_widgets.dart` before styling anything.

## 1. Three layers, never mixed

| Layer | What | How |
| :-- | :-- | :-- |
| Wallpaper | Soft aurora gradient behind every page | `AppBackdrop` — added automatically to every route by the theme's page transition, and by `AppShell`. Scaffolds are transparent. Never paint a full-screen opaque colour. |
| Content | Cards, lists, forms, text | Frosted surfaces: `FrostedCard`, themed `Card`, themed inputs. Translucent fill + hairline highlight border + soft shadow. **No blur, no shader** — cheap enough for long lists. |
| Chrome | Tab bar, floating buttons, sheets, dialogs | Real refractive glass from `liquid_glass_widgets` (`GlassTabBar`, `GlassIconButton`, …). |

- Glass is for the topmost navigation/control layer only. Use it sparingly.
- Never nest refractive glass inside refractive glass.
- Never put real glass on list items; use `FrostedCard`.
- Don't give navigation chrome a custom opaque background.

## 2. Tokens (do not hard-code)

- **Colour**: `Theme.of(context).colorScheme` roles, plus `context.fc`
  (`FcTokens` theme extension) for brand gradient, frosted fills, hairlines,
  shadows, and semantic `success / warning / danger / info`.
  No `Colors.blue`, no bare `Color(0x…)` in screens.
- **Spacing**: 4-pt grid — `Gap.xs 4 · sm 8 · md 12 · lg 16 · xl 24 · xxl 32`.
  Screen margin 20 on phones. Space between groups must be clearly larger than
  space inside a group.
- **Radius** (concentric: inner = outer − padding): `Radii.sm 12 · md 16 ·
  lg 22 · xl 28 · pill 999`. Cards 24, inputs 18, buttons pill, sheets 32.
- **Type**: Be Vietnam Pro via `Theme.of(context).textTheme` roles. Never
  below 11sp. Create hierarchy with weight and colour before size. Display and
  headline are 800 weight with tight tracking; body is 400/500.
- **Shadow**: only `context.fc.shadow` (soft, tinted, large blur). No black
  hard shadows.

## 3. Screen recipe

1. `Scaffold` (transparent by theme) with a transparent `AppBar`.
2. Lead with one hero: `HeroPanel` (brand-gradient panel) or a large title.
3. One primary action per screen (`FilledButton`; a white pill button on top
   of a `HeroPanel`) placed in the thumb zone.
4. Group content in `FrostedCard`s with a `SectionHeader` above each group.
5. Bottom padding must clear the floating tab pill (`floatingNavClearance`).

## 4. Interaction and states

- Touch targets ≥ 48dp. Visible press feedback on everything tappable
  (`PressableScale` or ink).
- Every async view has loading (shimmer/progress), empty (`EmptyState` with
  icon + message + action) and error (message + retry) states.
- Never convey status by colour alone: pair with icon or text (`StatusPill`).
- Motion: 150–250ms for small state changes, 300–400ms for layout,
  `Curves.easeOutCubic`. Honour `MediaQuery.disableAnimationsOf`.
- **No perpetual animations** (they hang `pumpAndSettle` in the test suite and
  drain battery). Entrance animations must end.

## 5. Accessibility and product rules

- Vietnamese labels. Light and dark both designed; test both.
- Text over the brand gradient is white or `fc.onBrandMuted`; never grey.
- Frosted fill alpha stays ≥ .62 so body text holds contrast on the wallpaper.
- Keep existing `ValueKey`s, tooltips and visible strings: widget tests and
  screen readers depend on them.
- Staff/owner operational screens favour density and clarity over decoration:
  frosted cards yes, decorative heroes no.

## 6. Look at what you built

`flutter test tool/preview/preview_test.dart --update-goldens` renders key
screens (light and dark, real fonts and shadows) to `tool/preview/out/*.png`.
Add the screen you changed to that file and read the PNG before calling it done.

Routes use `FcRoute` (`lib/app/fc_route.dart`), never a bare `GoRoute`: it
gives each page its wallpaper and transition.

## 7. Checklist before finishing a screen

- [ ] No hard-coded colours/radii/font sizes that a token covers.
- [ ] Works on the wallpaper in light **and** dark.
- [ ] No glass-in-glass; no glass in scrolling lists.
- [ ] Loading / empty / error states present.
- [ ] `flutter analyze` clean and `flutter test` green.
