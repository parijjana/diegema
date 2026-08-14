# Design tokens

Design system for the LibriVox audiobook player. Direction: **teal + warm paper** —
a reading room, not a console. Retained and refined from the current build; the earlier
neon-cyberpunk pass is rejected and not reintroduced anywhere.

Audience assumption that drives every decision below: **older readers, including blind and
low-vision users.** Legibility and screen-reader behaviour are product requirements. Every
foreground/background pair used for text in the system is measured and stated.

Canonical implementation: [`tokens.css`](tokens.css). Every preview file in this directory is
styled only from it.

---

## 1. Colour

### 1.1 Primitive ramps

The four hardcoded values in `lib/app.dart` become the anchor step of four ramps.

**Teal — primary.** Anchor `teal-500 = #2E6D7D` (unchanged).

| Step | Hex | Role |
| :--- | :--- | :--- |
| `teal-50`  | `#EEF5F7` | light accent wash |
| `teal-100` | `#D7E7EB` | |
| `teal-200` | `#AECFD7` | light wash border; dark accent-strong |
| `teal-300` | `#7FB2BF` | **dark-mode accent** (text, icons, fills) |
| `teal-400` | `#4F8F9F` | dark pressed |
| `teal-500` | `#2E6D7D` | **light-mode fill** — existing value |
| `teal-600` | `#265A68` | **light-mode accent text**, focus ring, hover fill |
| `teal-700` | `#1E4753` | light pressed; dark wash border |
| `teal-800` | `#17353E` | |
| `teal-900` | `#102429` | dark accent surface |

**Rust — secondary / call to action.** Anchor `rust-500 = #CC4D22` (unchanged).

| Step | Hex | Role |
| :--- | :--- | :--- |
| `rust-50` … `rust-200` | `#FCF0EB` `#F8DCD1` `#F0B9A3` | light wash |
| `rust-300` | `#E5906F` | **dark-mode CTA** |
| `rust-400` | `#D96B44` | |
| `rust-500` | `#CC4D22` | existing value — decorative only, see §1.4 |
| `rust-600` | `#A93E1B` | **light-mode CTA fill** |
| `rust-700` | `#863116` | light CTA text / hover |
| `rust-800`, `rust-900` | `#632410` `#41180B` | |

**Paper — light neutrals (warm).** Anchors `paper-100 = #F8F8F5` (scaffold),
`paper-300 = #E0DED6` (outline).

`paper-0 #FFFFFF` · `paper-50 #FBFAF7` · `paper-100 #F8F8F5` · `paper-200 #EFEEE8` ·
`paper-300 #E0DED6` · `paper-400 #C4C1B6` · `paper-500 #9A968B` · `paper-600 #767268` ·
`paper-700 #55534C` · `paper-800 #3A382F` · `paper-900 #22201C`

**Ink — dark surfaces (cool).** Anchors `ink-900 = #101417`, `ink-800 = #181C20`.

`ink-900 #101417` · `ink-850 #14181C` · `ink-800 #181C20` · `ink-700 #22272C` ·
`ink-600 #2E353B` · `ink-500 #414951` · `ink-400 #666F77` · `ink-300 #8A939B`

**Bone — dark-mode text (warm, keeps the paper feel).** Anchor `bone-200 = #E6E4DF`.

`bone-100 #F2F0EA` · `bone-200 #E6E4DF` · `bone-300 #C7C4BC` · `bone-400 #B4B0A6` ·
`bone-500 #928D83`

**Status.** `green-600 #1F6B4A` / `green-300 #6ECF9F` · `amber-700 #8A5A00` /
`amber-300 #E3B341` · `red-600 #B3261E`, `red-700 #8C1D18` / `red-300 #F2857A`

### 1.2 Semantic tokens

| Token | Light | Dark |
| :--- | :--- | :--- |
| `bg` | `paper-100` | `ink-900` |
| `surface` | `paper-0` | `ink-800` |
| `surface-sunken` | `paper-200` | `ink-850` |
| `surface-raised` | `paper-0` | `ink-700` |
| `surface-accent` | `teal-50` | `teal-900` |
| `text` | `paper-900` | `bone-200` |
| `text-secondary` | `paper-700` | `bone-400` |
| `text-muted` | `#6E6B62` | `bone-500` |
| `text-disabled` | `#8C8880` | `#6E7780` |
| `accent` | `teal-500` | `teal-300` |
| `accent-text` | `teal-600` | `teal-300` |
| `accent-fill` | `teal-500` | `teal-300` |
| `text-on-accent` | `paper-0` | `ink-900` |
| `accent-wash` | `teal-50` | `#16303A` |
| `cta` | `rust-600` | `rust-300` |
| `border` (decorative) | `paper-300` | `ink-600` |
| `border-contrast` (meaningful) | `paper-600` | `ink-400` |
| `focus-ring` | `teal-600` | `teal-300` |
| `danger` | `red-600` | `red-300` |
| `warning` | `amber-700` | `amber-300` |
| `success` | `green-600` | `green-300` |

### 1.3 Contrast — measured

WCAG 2.1 AA: **4.5:1** for body text, **3:1** for large text (≥18.66px bold / ≥24px) and for
non-text UI (borders that convey state, focus indicators, icons carrying meaning).

#### Light theme

| Pair | Ratio | Verdict |
| :--- | ---: | :--- |
| `text` #22201C on `surface` #FFFFFF | **16.26:1** | PASS AA + AAA |
| `text` #22201C on `bg` #F8F8F5 | **15.28:1** | PASS AA + AAA |
| `text-secondary` #55534C on #FFFFFF | **7.70:1** | PASS AA + AAA |
| `text-secondary` #55534C on #EFEEE8 | **6.62:1** | PASS AA + AAA |
| `text-muted` #6E6B62 on #FFFFFF | **5.33:1** | PASS AA |
| `accent-text` teal-600 on #FFFFFF | **7.65:1** | PASS AA + AAA |
| teal-500 on #FFFFFF | **5.83:1** | PASS AA |
| white on teal-500 (primary button) | **5.83:1** | PASS AA |
| white on teal-600 (hover) | **7.65:1** | PASS AA + AAA |
| white on rust-600 (CTA button) | **6.19:1** | PASS AA |
| rust-600 on #FFFFFF | **6.19:1** | PASS AA |
| `border-contrast` paper-600 on #FFFFFF | **4.80:1** | PASS non-text (3:1) |
| `focus-ring` teal-600 on #FFFFFF | **7.65:1** | PASS non-text |
| `focus-ring` teal-600 on #F8F8F5 | **7.19:1** | PASS non-text |
| error red-600 on #FFFFFF | **6.54:1** | PASS AA |
| white on error red-600 | **6.54:1** | PASS AA |
| error red-700 on `danger-wash` #FDECEA | **7.97:1** | PASS AA + AAA |
| warning amber-700 on #FFFFFF | **5.93:1** | PASS AA |
| success green-600 on #FFFFFF | **6.44:1** | PASS AA |
| teal-700 on `surface-accent` #EEF5F7 | **9.15:1** | PASS AA + AAA |
| `text` on `surface-accent` #EEF5F7 | **14.74:1** | PASS AA + AAA |
| `text-disabled` #8C8880 on `surface-sunken` | **3.04:1** | Exempt (disabled), still ≥3:1 |
| **rust-500 #CC4D22 on #FFFFFF** | **4.51:1** | Technically passes with 0.01 to spare — **not used for text.** Decorative accent only. |

**Deliberate sub-3:1 values, light.** `border` `paper-300` on white is **1.35:1**; `paper-400`
is **1.80:1**; `paper-500` is **2.95:1**. These are card hairlines only. Wherever a border
carries meaning — selection, focus, a state boundary, an input outline — use
`border-contrast` `paper-600` (**4.80:1**). Selection is additionally signalled by fill and by
a badge, never by an outline alone.

#### Dark theme

| Pair | Ratio | Verdict |
| :--- | ---: | :--- |
| `text` bone-200 on `surface` ink-800 | **13.48:1** | PASS AA + AAA |
| `text` bone-200 on `bg` ink-900 | **14.57:1** | PASS AA + AAA |
| `text` bone-200 on `surface-raised` ink-700 | **11.85:1** | PASS AA + AAA |
| `text-secondary` bone-400 on ink-800 | **7.91:1** | PASS AA + AAA |
| `text-secondary` bone-400 on ink-900 | **8.55:1** | PASS AA + AAA |
| `text-muted` bone-500 on ink-800 | **5.19:1** | PASS AA |
| `accent` teal-300 on ink-800 | **7.36:1** | PASS AA + AAA |
| `accent` teal-300 on ink-900 | **7.95:1** | PASS AA + AAA |
| ink-900 on teal-300 (primary button) | **7.95:1** | PASS AA + AAA |
| `cta` rust-300 on ink-800 | **6.98:1** | PASS AA |
| ink-900 on rust-300 (CTA button) | **7.54:1** | PASS AA + AAA |
| `border-contrast` ink-400 on ink-800 | **3.35:1** | PASS non-text (3:1) |
| `focus-ring` teal-300 on ink-800 | **7.36:1** | PASS non-text |
| teal-200 on `surface-accent` teal-900 | **9.73:1** | PASS AA + AAA |
| error red-300 on ink-800 | **6.86:1** | PASS AA |
| warning amber-300 on ink-800 | **8.80:1** | PASS AA + AAA |
| success green-300 on ink-800 | **9.05:1** | PASS AA + AAA |
| `text-disabled` #6E7780 on ink-700 | **3.31:1** | Exempt (disabled), still ≥3:1 |

**Deliberate sub-3:1 values, dark.** `border` `ink-600` on ink-800 is **1.38:1**, `ink-500`
is **1.87:1**. Same rule as light: decorative hairlines only.

### 1.4 What the audit found in the current build

| Current usage | Measured | Verdict |
| :--- | ---: | :--- |
| `onSurface.withValues(alpha: 0.6)` over white → `#7A7A7A` | **4.29:1** | **FAILS AA.** Used for nearly all secondary text in light mode: `librivox_book_item` author line, `persistent_player_bar` timecodes and chapter line, `book_detail_pane` narrator line, `library_view` subtitle, `app_header` tagline and search hint, `librivox_volunteer_banner` body. |
| `onSurface.withValues(alpha: 0.5)` over white → `#919191` | **2.94:1** | **FAILS AA badly.** Shelf-tile author line at 9px. |
| `onSurface.withValues(alpha: 0.4)` over white → `#A8A8A8` | **2.18:1** | **FAILS.** `GlassCard` title eyebrow. |
| `primary #2E6D7D` on dark surface `#181C20` | **2.94:1** | **FAILS AA and fails the 3:1 non-text floor.** Used in dark mode for accent text, icons, the speed chip, the play button's border, the `outline` colour and the dark `ColorScheme.outline`. |
| `onSurface.withValues(alpha: 0.6)` over `#181C20` → `#949493` | 5.64:1 | Passes, but replaced by an opaque token for predictability. |
| `onSurface.withValues(alpha: 0.15)` borders | ~1.2–1.4:1 | Below the non-text floor. These borders are the only cue on several controls (`t-btn`, sleep-timer chip, search box). |

The alpha-over-unknown-background pattern is the root cause: `GlassCard` blurs whatever is
behind it, so the effective background — and therefore the ratio — is not knowable at build
time. The system replaces alpha compositing with opaque semantic tokens.

---

## 2. Type

Font: **Inter** (already bundled). Previews approximate it with the system sans stack.
Serif accent: `Iowan Old Style / Palatino / Georgia`, used for the wordmark and book titles.

| Token | Size / line-height | Weight | Use |
| :--- | :--- | :--- | :--- |
| `display` | 34 / 40 | 700 | Full-screen state headings, Now Playing on desktop |
| `title-lg` | 28 / 34 | 700 | Screen titles |
| `title-md` | 22 / 28 | 650 | Book title in the detail pane, state headings |
| `title-sm` | 18 / 24 | 650 | Section headings, banner titles, card titles |
| `body-lg` | 17 / 26 | 400 | **Default.** Descriptions, list-row titles, inputs |
| `body` | 16 / 24 | 400 | Dense metadata, secondary lines |
| `label` | 15 / 20 | 600 | Buttons, chips, nav items, selectors |
| `caption` | 13 / 18 | 500 | **Floor.** Timecodes, badges, tile author lines |

**Rules**

- **13px is the absolute floor**, and 13px is permitted only for information that also appears
  elsewhere or is non-essential. Nothing at 9, 10, 11 or 12px.
- Letter-spacing is **0** everywhere. The only exception is `+0.01em` on tabular numerals.
- Timecodes, durations, counts and percentages use `font-variant-numeric: tabular-nums`
  (`FontFeature.tabularFigures()` in Flutter) so digits do not jitter as they tick.
- Titles truncate with an ellipsis at one or two lines and never shrink to fit.
- Type must scale with the OS text-size setting up to at least 200%. Nothing may be a fixed
  `SizedBox` height that clips at large text.

### 2.1 Casing — the all-caps decision

**All-caps labels are retired.** Currently in use: `YOUR LIBRARY IS EMPTY` (16px/w900/ls 2.0),
`IMPORT LOCAL BOOK` and `DISCOVER` (11px/bold/ls 1.0), `LIBRARY`/`DISCOVER` nav pills
(11px/w900/ls 1.0), `NOW PLAYING` (10px/ls 1.0), `IMPORT BOOK` (10px/ls 1.0),
`YOUR LIBRARY (n)` (11px/ls 1.5), `SEARCH RESULTS (n)` (10px/ls 1.5),
`VOLUNTEER FOR LIBRIVOX` (12px/ls 1.0), `JOIN →` (10px/ls 1.0), `DIEGEMA` (16px/w900/ls 2.0),
and every `GlassCard` title (`title.toUpperCase()`, 10px/ls 1.5).

Why it goes:

1. Uppercase removes word shape, which is what fluent readers actually pattern-match on. The
   cost lands hardest on exactly the audience this app is for.
2. Some screen readers spell short uppercase strings letter by letter.
3. Wide letter-spacing on small caps is the strongest single "sci-fi HUD" signal in the current
   UI, and it is at odds with a public-domain literature app.
4. It forces small sizes — every uppercase label in the app is 10–12px, because uppercase at
   16px looks aggressive. Removing the caps is what makes the size increase possible.

Replacement: sentence case, hierarchy carried by size and weight. `YOUR LIBRARY (3)` becomes
"Your library (3 books)" at `title-sm`.

---

## 3. Spacing

4px base: `0, 4, 8, 12, 16, 20, 24, 32, 40, 48, 64` (`--sp-0`…`--sp-16`).

The odd values in the current build (3, 6, 10, 14, 18) are dropped. Defaults: card padding 16,
gap between list items 12, gap between sections 32, screen gutter 16 on phone / 20 on desktop.

---

## 4. Radii

| Token | Value | Use |
| :--- | :--- | :--- |
| `r-xs` | 4px | badges, skeleton bars |
| `r-sm` | 8px | buttons, inputs, chapter rows |
| `r-md` | 12px | cards, list rows, banners |
| `r-lg` | 16px | player bar top corners, sheets |
| `r-xl` | 24px | modal sheets |
| `r-pill` | 999px | icon buttons, chips, progress tracks |
| `r-cover` | `2px 10px 10px 2px` | book covers (spine on the left) |

The cover radius keeps the book-spine idea from `librivox_book_item.dart` but at a subtler
`3px/8px` → `2px/10px`, and it is now a single token rather than four repeated
`BorderRadius.only(...)` literals.

---

## 5. Elevation

| Token | Light | Dark | Use |
| :--- | :--- | :--- | :--- |
| `shadow-0` | none | none | flat surfaces inside a card |
| `shadow-1` | `0 1px 2px rgba(34,32,28,.06), 0 1px 1px rgba(34,32,28,.04)` | `0 1px 2px rgba(0,0,0,.4)` | cards, list rows |
| `shadow-2` | `0 2px 6px …/.08` | `0 2px 8px rgba(0,0,0,.5)` | menus, the Now Playing play button |
| `shadow-3` | `0 8px 24px …/.12` | `0 10px 28px rgba(0,0,0,.6)` | player bar, sheets |
| `shadow-cover` | `0 2px 6px …/.18` | `0 2px 8px rgba(0,0,0,.55)` | book covers |

**`GlassCard` is retired.** It applies `ImageFilter.blur(20, 20)` plus an `onSurface` alpha
wash to nearly every surface — including full-height layout containers. Two problems: it
composites a full-screen blur on every frame, and it makes text contrast a function of
whatever happens to be scrolling underneath. Opaque surface + hairline border + a shadow token
replaces it. Coloured glow shadows (`primary.withValues(alpha: .35), blurRadius: 24` on the
play button; the per-book hue bloom on selected covers) are removed — they are the residue of
the rejected neon pass.

---

## 6. Motion

| Token | Value | Use |
| :--- | :--- | :--- |
| `dur-instant` | 0ms | playhead text, anything that must not lag |
| `dur-fast` | 120ms | hover, press, focus |
| `dur-base` | 200ms | default; matches the existing `AnimatedContainer`/`AnimatedAlign` |
| `dur-slow` | 320ms | sheets, drawer, detail-pane swap |
| `dur-skeleton` | 1600ms | skeleton shimmer cycle |
| `ease-standard` | `cubic-bezier(.2,0,0,1)` | default |
| `ease-decel` | `cubic-bezier(0,0,0,1)` | entering |
| `ease-accel` | `cubic-bezier(.3,0,1,1)` | leaving |

All animation respects `MediaQuery.disableAnimations` / `prefers-reduced-motion`. The skeleton
shimmer and the spinner are the only looping animations; both stop under reduced motion.

---

## 7. Sizing and touch targets

| Token | Value | Applies to |
| :--- | :--- | :--- |
| `tap-min` | **44px** | every interactive element, no exceptions |
| `tap-comfy` | 56px | player transport secondary controls |
| `tap-primary` | 76px | Now Playing play/pause |
| `icon-sm/md/lg/xl` | 20 / 24 / 28 / 36px | icons |
| `focus-width` | 3px | focus ring |
| `focus-offset` | 2px | focus ring |
| scrub track | 6px | progress/seek track (currently 3px) |
| scrub thumb | 20px | seek thumb (currently 6px radius) |

The minimum is enforced by the component, not by the caller's padding, and it survives
`FittedBox`-free layout: when a control cluster does not fit, it **wraps**, it does not shrink.

---

## 8. Accessibility contract

Applies to every component in this system.

1. Every interactive element has an accessible name. Icon-only controls carry a
   `Semantics(label:)`. There is currently **no `Semantics` widget anywhere in `lib/`**.
2. Minimum target 44×44 logical px.
3. Focus is always visible, with the same 3px ring everywhere, and is never suppressed.
4. State is never signalled by colour alone — selection combines outline + fill + a text badge.
5. Every asynchronous surface declares loading, empty, error and content. A screen missing an
   error state is not finished.
6. Loading regions set `aria-busy` / announce through a polite live region. Playback position
   is **not** a live region.
7. Text scales to at least 200% without clipping or overlap.
8. Body text meets 4.5:1; meaningful non-text meets 3:1. Both are measured, not assumed.
9. Play/pause is one toggle whose label changes, not two swapped icons.
10. Nothing is hover-only.
