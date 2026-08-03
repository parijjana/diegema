# Contributing to Aulos Audiobook Player

Thank you for your interest in contributing to the **Aulos Audiobook Player**! We welcome bug fixes, documentation improvements, UI enhancements, and new feature contributions.

---

## 🛠️ Development Workflow

1. **Fork & Clone**: Fork the repository and clone it to your local machine.
2. **Setup Local Pre-Commit Hook**:
   ```bash
   ./scripts/install_hooks.sh
   ```
   This ensures that `flutter analyze` and `flutter test` run automatically before every commit.
3. **Run Code Verification**:
   ```bash
   flutter analyze
   flutter test
   ```
4. **Code Quality Rules**:
   - Write unit/widget tests for new features.
   - Maintain 0 static analysis errors and 0 warnings.
   - Follow Flutter style lints and preserve existing docstrings/contracts.

---

## 🎙️ LibriVox Community Alignment

This project is a 100% free, non-commercial, ad-free public domain initiative. Contributions must respect user privacy, maintain zero telemetry in open-source builds, and honor the CC0 / Public Domain mission of LibriVox.
