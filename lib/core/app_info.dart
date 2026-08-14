/// Identity shown in the About section of the settings panel.
///
/// ⚠️ **The name is not settled.** The repository is still
/// `unamedaudiobookplayer` (typo and all) and picking a real name is an open
/// decision, so this is deliberately descriptive rather than a brand. When
/// the name lands, this constant and `MaterialApp.title` in `app.dart` are
/// the two places that carry it.
const String kAppName = 'Audiobook player';

/// ⚠️ Must be kept in step with `version:` in `pubspec.yaml` by hand.
///
/// Reading the real thing needs `package_info_plus`, which is a platform
/// channel and an extra dependency for one string on one rarely-opened
/// screen — not worth it while the app has two scaffolded platforms. Revisit
/// when there is a release process that could let these drift unnoticed.
const String kAppVersion = '1.0.0';
