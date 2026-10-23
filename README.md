# Diegema

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.44-02569B?logo=flutter)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20macOS%20%7C%20Windows-brightgreen)](#platform-support)

A free, open-source, ad-free audiobook player for public domain recordings from
**LibriVox**, hosted on the **Internet Archive**, and for audiobooks you already
own.

*Diegema* is Greek *διήγημα*, "a narrative" — the root of *diegesis*.

Diegema is an independent project. It is **not affiliated with or endorsed by
LibriVox** or the Internet Archive.

---

## Features

- **LibriVox catalogue browsing** over the Internet Archive, with downloads for
  offline listening.
- **Library folders** — point Diegema at one or more folders and your own audio
  (`.mp3`, `.m4a`, `.flac`, `.wav`) is scanned into the library alongside the
  catalogue.
- **Downloads manager** — queued, resumable downloads that survive the app being
  backgrounded or killed, with progress, pause and retry.
- **M4B import with chapters** — import `.m4b` audiobooks and get their embedded
  chapter list.
- **Background playback** with lock-screen and notification controls.
- **Ambience** — optional looping background sounds (rain, fire and more) to
  play under the narration.
- **Linked-device sync** — keep progress and library state in step between your
  own devices over your local network, or move it by hand with a sync file. No
  account, no cloud.
- **Hide books** you do not want to see, and bring them back later.
- **Sleep timer** (15/30/45/60 minutes) and **playback speeds** from 0.5x to 2.0x,
  plus a configurable skip interval (10/15/30/60s) and previous/next chapter.
- **Progress that persists** per book, with a "continue listening" surface and
  pinning.
- **Cover art** from the Internet Archive, with a generated fallback cover.
- **Light, dark or follow-the-system themes** from a documented token system
  (see `design/`) measured against WCAG contrast floors.

### Platform support

| Platform | Status |
| --- | --- |
| Android | Supported (API 24+) |
| iOS | Supported |
| macOS | Supported |
| Windows | Supported |
| Web | **Demo only** — a canned catalogue, not a usable player |

---

## Project structure

```text
├── lib/
│   ├── core/             # Settings, network rate limiting, demo switch
│   ├── database/         # Drift (SQLite) — AppDatabase, migrations
│   ├── domain/models/    # UnifiedAudiobook, LibriVoxBook
│   ├── screens/          # Now Playing, Library, Discover, Downloads, Settings
│   ├── services/         # LibriVox, downloads, playback, import, sync
│   ├── theme/            # Colour ramps, semantic tokens, type scale, metrics
│   └── widgets/          # Player transport, covers, shelves, state views
├── design/               # Design tokens, contrast ratios, app icon source
├── test/                 # Unit, database, service, widget and golden tests
├── tool/                 # Icon generator, ambience builder, sync helpers
├── scripts/              # Pre-commit hook installer, demo asset fetchers
└── assets/demo/          # Demo-only catalogue and covers (not in store builds)
```

---

## Building

Prerequisites: [Flutter](https://flutter.dev) 3.44 (stable), plus the toolchain
for each target below.

```bash
git clone https://github.com/parijjana/diegema.git
cd diegema
flutter pub get

# Optional: local pre-commit hook (runs analyze + the full test suite)
./scripts/install_hooks.sh

flutter test
```

### Android

Needs the Android SDK (platform 36) and JDK 17.

```bash
flutter run -d <device>
flutter build apk --release        # or: flutter build appbundle --release
```

The release build is signed with the debug key unless you configure your own
signing config in `android/app/build.gradle.kts`.

### iOS

Needs macOS with Xcode. Set your own development team in Xcode first.

```bash
flutter run -d <iphone>
flutter build ipa --release
```

### macOS

```bash
flutter run -d macos
flutter build macos --release
```

### Windows

Needs Windows with Visual Studio (Desktop development with C++).

```powershell
flutter run -d windows
flutter build windows --release
```

### Web demo (demo only)

The web build is a demo with a canned 18-book catalogue and bundled cover art. It
needs the demo assets, which are left out of normal builds, so go through the
wrapper script that adds them for one command:

```bash
tool/with_demo_assets.sh flutter build web --release --dart-define=DEMO_MODE=true --pwa-strategy=none
```

`--pwa-strategy=none` matters: a stale service worker will otherwise serve cached
HTML against new CSS, and the app renders as a grey box. See
`assets/demo/covers/CREDITS.md` for the source and rights of every bundled cover.
See [CONTRIBUTING.md](CONTRIBUTING.md) for how demo assets are kept out of store
builds and how to run the store-screenshot harness.

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
