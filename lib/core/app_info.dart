/// Identity shown in the About section of the settings panel.
///
/// ⚠️ **Diegema is a WORKING title, not the settled name.** The intent
/// (owner, 2026-08-14) is to let the LibriVox community choose the real one
/// if they are receptive to the project — so this will very likely change,
/// and changing it should stay a one-line edit here plus `MaterialApp.title`
/// in `app.dart`.
///
/// Greek *διήγημα*, "a narrative" — the root of *diegesis*. Chosen partly
/// because it was clear across the App Store, Play, GitHub, npm and the
/// obvious domains on 2026-08-14, which the previous candidate (Fabulae)
/// was not: *Fabula* and *Fabuly* are both existing audiobook apps.
const String kAppName = 'Diegema';

/// ⚠️ Must be kept in step with `version:` in `pubspec.yaml` by hand.
///
/// Reading the real thing needs `package_info_plus`, which is a platform
/// channel and an extra dependency for one string on one rarely-opened
/// screen — not worth it while the app has two scaffolded platforms. Revisit
/// when there is a release process that could let these drift unnoticed.
const String kAppVersion = '1.0.0';
