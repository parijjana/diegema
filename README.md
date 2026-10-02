# Diegema

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/Platform-macOS%20%7C%20Web-brightgreen)](#platform-support)

A free, open-source, ad-free audiobook player for public domain recordings from
**LibriVox**, hosted on the **Internet Archive**.

> **Status: work in progress.** The player works and is under active
> development, but it has not been released. Treat anything here as subject to
> change.
>
> **"Diegema" is a working title.** Greek *διήγημα*, "a narrative" — the root of
> *diegesis*.

Diegema is an independent project. It is **not affiliated with or endorsed by
LibriVox** or the Internet Archive.

---

## Features

- **LibriVox catalogue browsing** over the Internet Archive, with streaming
  playback and downloads for offline listening.
- **Local library import** — pick a directory or individual files (`.mp3`,
  `.m4a`, `.flac`, `.wav`) and play your own audio alongside the catalogue.
- **Playback controls** built for long-form listening: variable speed
  (0.5×–2.0×), a configurable skip interval (10/15/30/60s), previous/next
  chapter, and a sleep timer (15/30/45/60 minutes).
- **Progress that persists** — position is saved per book so you can pick up
  where you left off, with a "continue listening" surface and pinning.
- **An "Up next" queue** — for an audiobook, the queue is the chapter list.
- **Cover art** fetched from the Internet Archive, with a generated fallback
  cover when a recording has none.
- **Light, dark or follow-the-system themes**, from a documented token system
  (see `design/`) measured against WCAG contrast floors rather than eyeballed.
- **A settings panel** for appearance, playback and About.
- **Rate-limited network layer** (`RateLimitDispatcher`) so catalogue browsing
  does not trip HTTP 429s.

### Platform support

Only **macOS** and **web** are scaffolded and exercised today. The codebase is
Flutter and separates platform-specific work behind conditional imports, so other
targets are plausible — but Windows, Linux, Android and iOS have **not** been set
up or tested, and are not claimed to work.

---

## Project structure

```text
├── lib/
│   ├── core/network/     # RateLimitDispatcher
│   ├── database/         # Drift (SQLite) — AppDatabase, migrations
│   ├── domain/models/    # UnifiedAudiobook, LibriVoxBook
│   ├── screens/          # NowPlaying, Library, Discover, AppShell
│   ├── services/         # LibriVox, downloader, artwork, playback, local import
│   ├── theme/            # Colour ramps, semantic tokens, type scale, metrics
│   └── widgets/          # Player transport, covers, shelves, state views
├── design/               # Design tokens and their recorded contrast ratios
├── test/                 # Unit, database, service, widget and golden tests
├── scripts/              # Pre-commit hook installer, demo asset fetchers
└── assets/demo/          # Canned catalogue + covers for the web demo
```

---

## Getting started

### Prerequisites

- [Flutter SDK](https://flutter.dev) 3.x
- macOS, for the desktop target

### Run it

```bash
flutter pub get

# Optional: install the local pre-commit hook (runs analyze + the full suite)
./scripts/install_hooks.sh

flutter test
flutter run -d macos
```

```bash
git clone https://github.com/parijjana/diegema.git
```

### Building the web demo

```bash
flutter build web --release --dart-define=DEMO_MODE=true --pwa-strategy=none
```

`--pwa-strategy=none` matters: a stale service worker will otherwise serve cached
HTML against new CSS, and the app renders as a grey box.

The demo uses a canned 18-book catalogue and bundled cover art so it works with
no network. See `assets/demo/covers/CREDITS.md` for the per-file source and
rights of every bundled cover.

---

## Credit and support for LibriVox

The recordings Diegema plays come from [LibriVox](https://librivox.org/), read and
produced by volunteers. LibriVox recordings are in the public domain. LibriVox
describes its objective as:

> To make all books in the public domain available, narrated by real people and
> distributed for free, in audio format on the internet.

We strongly support LibriVox and its mission. If you enjoy these recordings,
consider [volunteering to read or proof-listen](https://librivox.org/pages/volunteer-for-librivox/).

Diegema is not affiliated with or endorsed by LibriVox or the Internet Archive.

---

## License

[MIT](LICENSE). The bundled demo cover art is public domain — see
`assets/demo/covers/CREDITS.md`.
