# Contributing to Diegema

Thank you for your interest in contributing to **Diegema**, a free audiobook
player for Android, iOS, macOS and Windows (the web build is a demo only). Bug
fixes, documentation, UI polish and features are all welcome.

---

## Development workflow

1. **Fork and clone** the repository.
2. **Install Flutter** 3.44 (stable) and the toolchain for the platform you are
   working on (see "Building" in the [README](README.md)).
3. **Install the local pre-commit hook**:
   ```bash
   ./scripts/install_hooks.sh
   ```
   It runs `flutter analyze` and `flutter test` before every commit.
4. **Verify before you push**:
   ```bash
   flutter analyze
   flutter test
   ```
5. **Code quality rules**:
   - Write unit or widget tests for new behaviour.
   - Keep `flutter analyze` at zero errors and zero warnings.
   - Follow the Flutter lints and preserve existing docstrings and contracts.
   - Golden tests are not regenerated casually: if one fails because of your
     change, explain why in the pull request.
6. **Fonts**: only self-hosted fonts under SIL OFL (without a Reserved Font
   Name), Apache 2.0, MIT or CC0. No Google Fonts or other font CDNs.

---

## Demo assets and screenshots

`assets/demo/**` (a canned catalogue and cover art) is used only by the
store-screenshot harness (`lib/screenshot_main.dart`, built with `DEMO_MODE`). It
is deliberately **not** listed in `pubspec.yaml`, so Android, iOS, macOS and
Windows release builds do not ship it.

To build or run something that needs it, wrap the command in
`tool/with_demo_assets.sh`. It adds the demo assets to `pubspec.yaml` for the
duration of the command and always restores the file afterwards:

```bash
# Store-screenshot harness (debug, so overflow detection is on)
tool/with_demo_assets.sh flutter run -d macos \
  -t lib/screenshot_main.dart --dart-define=DEMO_MODE=true
```

If you add a new asset that only the screenshots need, put it under `assets/demo/` and
extend the two lines in the script; do not list it in `pubspec.yaml`.

---

## Regenerating app icons

The icon source is in `design/icon/` (see its README). To rebuild the Android,
iOS, macOS and web icon files from it:

```bash
python3 tool/icons/make_icons.py
```

(requires Pillow). The Android notification and monochrome icons are vector
drawables in `android/app/src/main/res/drawable/`.

---

## Project values

This project is a 100% free, non-commercial, ad-free player for public domain
recordings. Contributions must respect user privacy and maintain zero telemetry
in open-source builds.

Diegema is an independent project, not affiliated with or endorsed by LibriVox or
the Internet Archive. We strongly support LibriVox and its mission; keep project
text factual about where recordings come from, and never imply a partnership or
endorsement.

Questions: overengineeredhobbies@gmail.com
