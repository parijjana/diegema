# Aulos Audiobook Player (Unnamed Audiobook Player)

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/Platform-macOS%20%7C%20Windows%20%7C%20Linux%20%7C%20Android%20%7C%20iOS-brightgreen)](#)
[![Tests](https://img.shields.io/badge/TDD%20Tests-14%2F14%20Passing-success)](#)

A modern, 100% free, open-source, ad-free audiobook player dedicated to public domain literature from **LibriVox** and the **Internet Archive**.

Built with Flutter, SQLite (`drift`), and the Aulos pitch-dark design system (`#0A0C0E` + `#00F0FF`).

---

## ✨ Key Features

- 🎧 **LibriVox Catalog & Internet Archive Integration**: Direct streaming and full ZIP downloads of public domain audiobooks.
- 🎨 **Hybrid Artwork Engine**: Fetches high-resolution cover art from the Internet Archive with automatic fallback to an Aulos procedural cover art generator.
- 📖 **Wikipedia Insights**: Enriches audiobook titles with real-time Wikipedia author bios and historical book summaries cached in SQLite.
- ⏱️ **Aulos Audiobook Control Suite**:
  - Variable speed selector ($0.5\times, 0.8\times, 1.0\times, 1.25\times, 1.5\times, 2.0\times$).
  - Replay / Skip 15 seconds ($\pm15$s).
  - Skip previous and next chapter controls.
  - Sleep timer ($15\text{m}, 30\text{m}, 45\text{m}, 60\text{m}$).
  - Audio clip & timestamp bookmark notes manager.
- 📁 **Local Audiobook Importer**: Pick directories or individual local audio files (`.mp3`, `.m4a`, `.flac`, `.wav`) to import into your library.
- 🎙️ **LibriVox Community Give-Back**: Integrated volunteer recruitment links to support LibriVox voice readers and proof-listeners.
- 🛡️ **Rate-Limited Resilient Network Layer**: Custom `RateLimitDispatcher` prevents HTTP 429 rate limit errors.
- 🧪 **TDD & Quality Assured**: 100% test pass rate with automated Git pre-commit verification hooks.

---

## 🛠️ Project Structure

```text
unamedaudiobookplayer/
├── lib/
│   ├── core/network/        # RateLimitDispatcher
│   ├── database/            # Drift SQLite database (AppDatabase)
│   ├── domain/models/       # UnifiedAudiobook & LibriVoxBook models
│   ├── services/            # LibriVox, Wikipedia, Downloader, & AudioPlayback services
│   └── widgets/             # GlassCard, NowPlayingScreen, LibraryView, BookmarksDrawer
├── test/                    # Unit, database, service, and widget TDD test suites
├── scripts/                 # Pre-commit hook installer (install_hooks.sh)
└── docs/                    # Progress logs and strategic collaboration plan
```

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://flutter.dev) (v3.0+)
- macOS / Windows / Linux desktop environment or Android/iOS device

### Installation & Run

```bash
# 1. Clone repository
git clone https://github.com/parijjana/unamedaudiobookplayer.git
cd unamedaudiobookplayer

# 2. Install dependencies
flutter pub get

# 3. Run local TDD test suite
flutter test

# 4. Install local CI pre-commit hook
./scripts/install_hooks.sh

# 5. Launch application on macOS
flutter run -d macos
```

---

## 🤝 Supporting LibriVox

This project is dedicated to supporting the public domain audio community. If you enjoy listening to audiobooks, consider donating your voice or proof-listening to record new public domain literature at [LibriVox Volunteer Page](https://librivox.org/pages/volunteer-for-librivox/).

---

## 📜 License

This project is licensed under the [MIT License](LICENSE).
