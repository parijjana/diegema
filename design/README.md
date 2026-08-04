# `design/` — component library

A browsable, self-contained HTML specification of this app's design system. It exists so the
visual direction can be reviewed and argued about **before** anyone refactors Dart.

**Nothing here is executable app code.** No file in `design/` is imported by `lib/`, and no
file in `lib/`, `test/`, `pubspec.yaml` or any platform directory was touched to create it.

---

## Reading it

Open any `.html` file directly in a browser — `file://` works, there are no network requests,
no CDN links and no external fonts. Every page links the shared `tokens.css`, so keep the files
together in this directory.

Each page starts with a marker comment on line 1 that the Design System pane indexes:

```html
<!-- @dsCard group="Foundations" -->
```

| File | Group | Covers |
| :--- | :--- | :--- |
| `00-foundations.html` | Foundations | colour ramps, semantic tokens, measured contrast, type scale, spacing, radii, elevation, motion |
| `01-buttons.html` | Components | primary / CTA / secondary / ghost / neutral / danger, three sizes, all states, icon buttons, chips |
| `02-book-items.html` | Components | library list row, shelf tile, search grid, **preview-only** variants |
| `03-book-detail.html` | Components | book detail pane, phone full screen and desktop two-pane split |
| `04-banners.html` | Components | LibriVox volunteer banner, auto-resume banner, demo-mode notice |
| `05-navigation.html` | Navigation | app header, search, category chips, phone bottom bar |
| `06-player-bar.html` | Player | persistent player bar — playing, buffering, error |
| `07-now-playing.html` | Player | full transport cluster, speed 0.5×–2×, sleep timer, bookmarks |
| `08-states.html` | States | empty, loading (skeletons), error, inline error |

`tokens.md` is the written specification with all measured contrast ratios. `tokens.css` is the
canonical token set.

### The frames

Every component appears in **light and dark** and, where the layout differs, at **390px
(phone)** and **1280px (desktop)** side by side. Two mechanics make that work on one page:

- Dark mode is scoped per subtree via `[data-theme="dark"]`, not a global toggle, so both
  themes render simultaneously.
- Responsive rules are **container queries** on the frame body, not viewport media queries, so
  a 390px frame really behaves like a 390px device inside a wide window. This maps directly to
  Flutter `LayoutBuilder` constraints, which is the correct pattern for a widget that can also
  sit inside a narrow pane on a wide screen — the existing
  `MediaQuery.of(context).size.width >= 768` check in `storefront_navigation.dart` gets this
  wrong for the two-pane case.
- The slider in the top toolbar scales the 1280px frames so both widths fit on screen.

Icons in the previews are Unicode stand-ins (▶ ⏸ ⏮ ⏭ ↺ ↻ ⚑ ☾). The Flutter build keeps
Material Symbols; the glyphs are placeholders for size and placement only.

---

## Mapping to `lib/`

| Preview component | Widget today | What has to change |
| :--- | :--- | :--- |
| Token set | `lib/app.dart` — two inline `ThemeData` blocks with six literals | Extract to `lib/theme/` : `app_colors.dart` (ramps), `app_theme.dart` (light + dark `ColorScheme` built from the ramps), `app_typography.dart` (`TextTheme` from the scale), `app_spacing.dart`, `app_radii.dart`, `app_motion.dart`. **Dark mode must use `teal-300`, not `teal-500`** — the shared accent currently fails contrast on the dark surface. |
| `.card` | `widgets/glass_card.dart` | Retire the `BackdropFilter`. Replace with an opaque `Card`/`Container` at `surface` + hairline `border` + `shadow-1`. Drop the `title.toUpperCase()` eyebrow in favour of a real `title-sm` heading. This is the single highest-leverage change: `GlassCard` is used by the player bar, the library rows, the detail pane, the banners and both layout containers. |
| `.btn` variants | `ElevatedButton` / `OutlinedButton` / `FilledButton` styled ad hoc at ~8 call sites | One `ButtonTheme` set in `app_theme.dart`. Remove per-call-site `styleFrom`. Kill `letterSpacing` and `toUpperCase`. Enforce `minimumSize: Size(0, 44)`. |
| `.icon-btn` | bare `IconButton` / `InkWell` | 44px minimum, mandatory `tooltip` + `Semantics(label:)`. |
| `.chip` | `ChoiceChip` in `storefront_navigation.dart:CategorySubBar` | 11px label → 15px; 36px height → 44px; selected state gains an outline and a weight change, not just a fill tint. |
| `.book-row` | `library_view.dart` — inline `ListTile` inside `GlassCard` | Extract to its own `BookRow` widget. Show the real cover instead of `Icons.book_rounded`, show resume progress (already persisted, currently unused), 14px title → 17px, 12px α0.6 subtitle → 16px `text-secondary`. Add the `preview` variant. |
| `.book-tile` | `widgets/librivox_book_item.dart` | 110px → 148px wide. Title 10px → 16px, author 9px α0.5 → 13px `text-secondary`. Remove the neon accent strip, the glossy sheen and the hue-tinted glow shadow; keep the spine crease and the serif letter emblem. Selection becomes a 2px accent outline. Add the `preview` variant. |
| `.detail` | `widgets/book_detail_pane.dart` | Cover 110×110 square → 3:4. **Streaming becomes the primary action; download becomes secondary** — today the rust download button is the only affordance. Description 13px → 17px at a 68ch measure. Chapter rows: 12px title → 17px, 10px duration → 16px tabular, and never render `0.0 mins` — show `—` when the duration is unknown (see rework plan item 14). |
| `.player-bar` | `widgets/persistent_player_bar.dart` | Opaque surface. Scrub track 3px → 6px, thumb radius 6 → 20. Timecodes 10px α0.6 → 13px tabular `text-secondary`. Replace the `FittedBox(scaleDown)` with a `LayoutBuilder` that *drops* secondary controls below 560px instead of shrinking everything below a usable size. Move the bookmark button out of the leading slot and put the cover there. Add a playback-error state — there is none today. |
| `.transport`, `.selector`, `.speed-scale` | `widgets/now_playing_controls.dart` | Remove the outer `FittedBox`; wrap instead. **Fix the icon/behaviour mismatch**: the buttons draw `Icons.replay_10_rounded` / `Icons.forward_10_rounded` but call `skipBackward(seconds: 15)` / `skipForward(seconds: 15)`. Render the interval from the same value that drives the seek. Speed list currently `[0.5, 0.8, 1.0, 1.25, 1.5, 2.0]` in Now Playing but `[0.75, 1.0, 1.25, 1.5, 2.0]` in the player bar — unify on `0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0`. Give both `PopupMenuButton`s an accessible name and a visible current value. Drop the play button's coloured bloom shadow. |
| `.app-header`, `.search`, `.bottom-nav` | `widgets/app_header.dart` | The header is an unwrapped `Row` and will overflow on a phone — add a `LayoutBuilder` breakpoint at 700px that moves primary nav to a bottom bar. Nav pills 11px w900 uppercase ls 1.0 → 15px sentence case at 44px. Stop collapsing search behind an icon; make it persistent. Wordmark to the serif face. Replace the custom 56×28 sliding theme switch with a labelled toggle carrying `Semantics(toggled:)`. |
| `.banner` | `widgets/librivox_volunteer_banner.dart`, `widgets/auto_resume_banner.dart` | One shared banner widget with a colour role. Volunteer title 12px uppercase ls 1.0 → 18px sentence case; body 11px α0.6 → 16px `text-secondary`; the `JOIN →` button at 10px → a 44px button with a real verb. Render it **once** per screen — `library_view.dart` currently shows it in both the empty state and above the list. Add the demo-mode notice the canned web build needs. |
| `.state` (empty/loading/error) | scattered | One `AppStateView` widget with `.empty()`, `.loading()`, `.error()` constructors. Replace the three bare `CircularProgressIndicator`s with layout-matching skeletons. Add the error states — network failures currently vanish into `debugPrint` or a `SnackBar` carrying a raw exception string. |
| `.skeleton` | does not exist | New. |
| `.badge` | does not exist | New — downloaded / finished / now playing / preview-only. |

### Preview-only variant

The rework plan requires the canned web demo to mark unplayable entries so nobody believes
they were shown a working app that isn't one. Both `.book-row` and `.book-tile` carry an
`is-preview` variant: dashed `border-contrast` outline, desaturated cover, an amber
"Preview only" badge, and a disabled play control. The badge text is part of the accessible
label, not just a visual treatment.

---

## Suggested implementation order

The design system is a later, separate task. When it starts, this order minimises churn:

1. `lib/theme/` — ramps, `ColorScheme`s, `TextTheme`, spacing/radii/motion constants. Nothing
   else changes; the app just gets bigger, higher-contrast type for free.
2. Retire `GlassCard` → `AppCard`. Touches the most call sites and unblocks contrast guarantees.
3. Buttons, icon buttons, chips — centralised themes, all `styleFrom` call sites deleted.
4. `AppStateView` + skeletons + the missing error states.
5. `BookRow` and `BookTile` extracted, with the preview variant.
6. Player bar and the Now Playing transport cluster, including the 15s/10s icon fix.
7. App header responsive breakpoint + bottom navigation.
8. `Semantics` pass across everything, then golden tests at 390px and 1280px in both themes.

Steps 1–4 also serve rework-plan Phase 2 item 17 (the accessibility pass), and steps 5–6 are
what the community will actually be critiquing in the web demo.

---

## Deliberate departures from the current design

Recorded here so they are choices, not drift.

1. **Dark mode gets a different accent step** (`teal-300`) from light (`teal-500`/`teal-600`).
   The shared `#2E6D7D` measures 2.94:1 on the dark surface and fails both AA and the 3:1
   non-text floor. The hue is unchanged.
2. **All-caps + letter-spaced labels removed everywhere.** Rationale in `tokens.md` §2.1.
3. **`GlassCard`'s backdrop blur removed.** Cost and unprovable contrast.
4. **Coloured glow shadows removed** — the per-book hue bloom on selected covers, the neon
   accent strip on the procedural cover, and the play button's 24px teal bloom. These are the
   residue of the rejected neon-cyberpunk pass.
5. **Search is persistent, not collapsed behind an animated icon.**
6. **Streaming outranks downloading** in the detail pane.
7. **Primary navigation moves to a bottom bar on phone.** The current header is a single
   unwrapped `Row` that cannot fit 390px at all.
8. **Responsive rules become container-based**, so a widget behaves correctly inside a narrow
   pane on a wide window.
9. **Minimum type size 13px, default 17px.** The current 9–12px is the single largest
   accessibility problem in the app.
10. **The wordmark moves to a serif face.** A public-domain library, not a console.

Not changed, deliberately: the teal + warm-paper palette, the two-pane 5fr/4fr desktop split,
the book-spine cover treatment, the serif letter emblem on procedural covers, the 200ms
default animation duration, and light-as-default.
