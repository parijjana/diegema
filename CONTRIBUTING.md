# Contributing to Diegema

Thank you for your interest in contributing to **Diegema**! We welcome bug fixes, documentation improvements, UI enhancements, and new feature contributions.

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

## 🎙️ Project values

This project is a 100% free, non-commercial, ad-free player for public domain recordings. Contributions must respect user privacy and maintain zero telemetry in open-source builds.

Diegema is an independent project, not affiliated with or endorsed by LibriVox or the Internet Archive. We strongly support LibriVox and its mission; keep project text factual about where recordings come from, and never imply a partnership or endorsement.
